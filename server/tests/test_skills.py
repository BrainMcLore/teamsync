from test_api import setup
from server.database import uid


def test_skill_confirmation_rechecks_and_history_are_account_bound(setup):
    _,c,(owner,player,stranger)=setup
    team=c.post('/api/v1/teams',headers=owner[1],json={'name':'Skills'}).json()['id']
    base=f'/api/v1/teams/{team}'
    code=c.post(base+'/invites',headers=owner[1],json={}).json()['code']
    c.post('/api/v1/invites/join',headers=player[1],json={'code':code})
    mapid=uid()
    c.post(base+'/documents',headers=owner[1],json={'operation_id':uid(),'document_id':mapid,'expected_version':0,'kind':'map','payload':{'title':'Mirage'}})
    utility={'operation_id':uid(),'document_id':uid(),'expected_version':0,'kind':'utility',
             'payload':{'title':'Window','map_id':mapid,'side':'T','utility':{'grenade':'smoke'}}}
    assert c.post(base+'/documents',headers=owner[1],json=utility).status_code==200
    endpoint=base+f'/utilities/{utility["document_id"]}/progress'
    ready={'operation_id':uid(),'revision':1,'expected_version':0,'status':'ready'}
    assert c.post(endpoint,headers=stranger[1],json=ready).status_code==404
    result=c.post(endpoint,headers=player[1],json=ready)
    assert result.status_code==200
    assert c.post(endpoint,headers=player[1],json=ready).json()==result.json()
    confirm={**ready,'operation_id':uid(),'expected_version':1,'status':'confirmed','target_user_id':player[0]}
    assert c.post(endpoint,headers=player[1],json=confirm).status_code==403
    confirmed=c.post(endpoint,headers=owner[1],json=confirm)
    assert confirmed.status_code==200
    assert confirmed.json()['reviewed_by']==owner[0]
    returned={**confirm,'operation_id':uid(),'expected_version':2,'status':'learning'}
    assert c.post(endpoint,headers=owner[1],json=returned).status_code==422
    assert c.post(endpoint,headers=owner[1],json={**returned,'reason':'Change the aiming point'}).status_code==200
    history=c.get(base+f'/utility-progress/{confirmed.json()["id"]}/versions',headers=player[1]).json()['items']
    assert [v['status'] for v in history]==['learning','confirmed','ready']
    changed={**utility,'operation_id':uid(),'expected_version':1,'payload':{
        **utility['payload'],'utility':{'grenade':'smoke','training_revision':2}}}
    assert c.post(base+'/documents',headers=owner[1],json=changed).status_code==422
    changed['payload']['utility']['review_reason']='Map geometry changed'
    assert c.post(base+'/documents',headers=owner[1],json=changed).status_code==200
    assert c.post(endpoint,headers=player[1],json={**ready,'operation_id':uid(),'expected_version':3}).status_code==409
    assert c.post(endpoint,headers=player[1],json={**ready,'operation_id':uid(),'revision':2,'status':'learning'}).status_code==200
    records=c.get(base+'/utility-progress',headers=owner[1]).json()['items']
    assert {r['revision'] for r in records}=={1,2}
    assert c.get(base+'/utility-progress',headers=stranger[1]).status_code==404
    # An older utility client may update text without resetting the recheck epoch.
    legacy={**utility,'operation_id':uid(),'expected_version':2,'payload':{**utility['payload'],'notes':'Typo fixed'}}
    assert c.post(base+'/documents',headers=owner[1],json=legacy).status_code==200
    material=next(r for r in c.get(base+'/documents',headers=player[1]).json()['items'] if r['kind']=='utility')
    assert material['payload']['utility']['training_revision']==2
    assert material['payload']['utility']['review_reason']=='Map geometry changed'
