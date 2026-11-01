from datetime import datetime, timedelta, timezone
from sqlalchemy import select, update, func
from test_api import setup
from server.database import uid, memberships, schedule_events, schedule_history


def prepare(c, owner, player, past=False):
    team=c.post('/api/v1/teams',headers=owner[1],json={'name':'Schedule'}).json()['id']
    base=f'/api/v1/teams/{team}'
    code=c.post(base+'/invites',headers=owner[1],json={'role':'player'}).json()['code']
    c.post('/api/v1/invites/join',headers=player[1],json={'code':code})
    start=datetime.now(timezone.utc)+timedelta(days=-1 if past else 1)
    body={'operation_id':uid(),'expected_version':0,'title':'Practice','starts_at':start.isoformat(),
          'ends_at':(start+timedelta(hours=2)).isoformat()}
    event=uid()
    result=c.post(base+'/events/'+event,headers=owner[1],json=body)
    assert result.status_code==200,result.text
    return base,event,body,result.json()


def test_events_require_manager_timezone_and_versioned_retries(setup):
    app,c,(owner,player,stranger)=setup
    base,event,body,row=prepare(c,owner,player)
    path=base+'/events/'+event
    assert c.post(path,headers=owner[1],json=body).json()==row
    assert c.post(path,headers=owner[1],json={**body,'title':'Different'}).status_code==409
    assert c.post(path,headers=owner[1],json={**body,'operation_id':uid()}).status_code==409
    assert c.post(base+'/events/'+uid(),headers=player[1],json=body).status_code==403
    assert c.post(base+'/events/'+uid(),headers=stranger[1],json=body).status_code==404
    for fields in [{'starts_at':'2026-11-01T18:00:00'}, {'ends_at':body['starts_at']},
                   {'status':'cancelled','reason':''}]:
        assert c.post(path,headers=owner[1],json={**body,**fields,'expected_version':1,'operation_id':uid()}).status_code==422
    offset={**body,'operation_id':uid(),'expected_version':1,'starts_at':'2027-01-02T20:00:00+02:00','ends_at':'2027-01-02T22:00:00+02:00'}
    changed=c.post(path,headers=owner[1],json=offset).json()
    assert changed['starts_at']=='2027-01-02T18:00:00Z'
    listing=base+'/events?from_at=2027-01-01T00:00:00Z&until_at=2027-01-03T00:00:00Z'
    assert c.get(listing,headers=player[1]).json()['items'][0]['id']==event
    assert c.get(listing,headers=stranger[1]).status_code==404
    assert c.get(base+'/events?from_at=2027-01-01&until_at=2027-01-03',headers=owner[1]).status_code==422
    cancel={**offset,'expected_version':2,'operation_id':uid(),'status':'cancelled','reason':'Server unavailable'}
    assert c.post(path,headers=owner[1],json=cancel).status_code==200
    assert c.post(path+'/participation/'+player[0],headers=player[1],json={'operation_id':uid(),'expected_version':0,'rsvp':'going'}).status_code==409
    with app.state.engine.connect() as conn:
        assert conn.execute(select(func.count()).select_from(schedule_history)).scalar_one()==3


def test_rsvp_is_separate_from_coach_attendance_and_corrections_are_audited(setup):
    app,c,(owner,player,stranger)=setup
    base,event,body,_=prepare(c,owner,player,past=True)
    path=base+'/events/'+event
    target=path+'/participation/'+player[0]
    going={'operation_id':uid(),'expected_version':0,'rsvp':'going'}
    assert c.post(target,headers=player[1],json=going).json()['attendance']=='unmarked'
    assert c.post(target,headers=owner[1],json={**going,'operation_id':uid(),'expected_version':1}).status_code==403
    mark={'operation_id':uid(),'expected_version':1,'attendance':'present'}
    assert c.post(target,headers=player[1],json=mark).status_code==403
    present=c.post(target,headers=owner[1],json=mark)
    assert present.status_code==200,present.text
    assert present.json()['rsvp']=='going'
    assert c.post(target,headers=owner[1],json=mark).json()==present.json()
    correction={'operation_id':uid(),'expected_version':2,'attendance':'late'}
    assert c.post(target,headers=owner[1],json=correction).status_code==422
    correction['reason']='Joined ten minutes late'
    corrected=c.post(target,headers=owner[1],json=correction).json()
    assert corrected['recorded_by']==owner[0]
    no={'operation_id':uid(),'expected_version':3,'rsvp':'declined'}
    updated=c.post(target,headers=player[1],json=no).json()
    assert updated['attendance']=='late' and updated['reason']=='Joined ten minutes late'
    shift={**body,'operation_id':uid(),'expected_version':1,
           'starts_at':(datetime.now(timezone.utc)+timedelta(days=2)).isoformat(),
           'ends_at':(datetime.now(timezone.utc)+timedelta(days=2,hours=2)).isoformat()}
    assert c.post(path,headers=owner[1],json=shift).status_code==409
    people=c.get(path+'/participation',headers=owner[1])
    assert people.status_code==200,people.text
    row=next(r for r in people.json()['items'] if r['user_id']==player[0])
    assert row['recorded_by_name']=='Owner' and row['active']
    hist=c.get(path+'/history',headers=player[1]).json()['items']
    assert len(hist)==5 and hist[0]['target_name']=='Player'
    assert c.get(path+'/history',headers=stranger[1]).status_code==404
    c.delete(base+'/members/'+player[0],headers=owner[1])
    former=next(r for r in c.get(path+'/participation',headers=owner[1]).json()['items'] if r['user_id']==player[0])
    assert not former['active'] and former['attendance']=='late'
    assert c.get(path+'/participation',headers=player[1]).status_code==404
    assert c.post(target,headers=owner[1],json={**correction,'operation_id':uid(),'expected_version':4}).status_code==404


def test_future_attendance_and_viewer_permissions(setup):
    app,c,(owner,player,_)=setup
    base,event,_,_=prepare(c,owner,player)
    path=base+'/events/'+event+'/participation/'+player[0]
    assert c.post(path,headers=owner[1],json={'operation_id':uid(),'expected_version':0,'attendance':'present'}).status_code==409
    excused=c.post(path,headers=owner[1],json={'operation_id':uid(),'expected_version':0,'attendance':'excused','reason':'Travel'})
    assert excused.status_code==200
    with app.state.engine.begin() as conn:
        conn.execute(update(memberships).where(memberships.c.user_id==player[0]).values(role='viewer'))
    assert c.post(path,headers=player[1],json={'operation_id':uid(),'expected_version':1,'rsvp':'going'}).status_code==403
