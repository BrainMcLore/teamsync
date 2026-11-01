import time
from sqlalchemy import update
from test_api import setup
from server.database import account_invites


def test_targeted_invites_accept_permissions_and_revocation(setup):
    app,c,(owner,player,stranger)=setup
    team=c.post('/api/v1/teams',headers=owner[1],json={'name':'Roster'}).json()['id']
    path=f'/api/v1/teams/{team}'
    assert c.patch(path+'/members/'+owner[0],headers=owner[1],json={'role':'owner','game_role':'IGL'}).status_code==200
    assert c.patch(path+'/members/'+owner[0],headers=owner[1],json={'role':'player'}).status_code==403
    assert c.get('/api/v1/users/lookup',params={'user_id':player[0]},headers=owner[1]).json()['name']=='Player'
    sent=c.post(path+'/account-invites',headers=owner[1],json={'user_id':player[0]})
    assert sent.status_code==201
    invitation=sent.json()['id']
    assert c.get('/api/v1/me/invitations',headers=stranger[1]).json()['items']==[]
    assert c.post(f'/api/v1/me/invitations/{invitation}/accept',headers=stranger[1]).status_code==404
    assert c.get(path+'/members',headers=player[1]).status_code==404
    assert c.post(f'/api/v1/me/invitations/{invitation}/accept',headers=player[1]).status_code==200
    assert c.post(f'/api/v1/me/invitations/{invitation}/accept',headers=player[1]).status_code==404
    assert c.post(path+'/account-invites',headers=player[1],json={'user_id':stranger[0]}).status_code==403
    assert c.patch(path+'/members/'+player[0],headers=player[1],json={'role':'captain'}).status_code==403
    assert c.patch(path+'/members/'+player[0],headers=owner[1],json={'role':'player','game_role':'AWPer','squad':'reserve'}).status_code==200
    roster=c.get(path+'/members',headers=player[1]).json()['items']
    row=next(r for r in roster if r['id']==player[0])
    assert row['game_role']=='AWPer' and row['squad']=='reserve'
    assert c.delete(path+'/members/'+player[0],headers=owner[1]).status_code==200
    assert c.get(path+'/members',headers=player[1]).status_code==404


def test_expiry_decline_revoke_and_sender_loses_permission(setup):
    app,c,(owner,player,stranger)=setup
    team=c.post('/api/v1/teams',headers=owner[1],json={'name':'Roster'}).json()['id']
    path=f'/api/v1/teams/{team}'
    def send(who=player,role='player',sender=owner):
        return c.post(path+'/account-invites',headers=sender[1],json={'user_id':who[0],'role':role})
    invitation=send().json()['id']
    assert send().status_code==409
    assert c.delete(f'/api/v1/me/invitations/{invitation}',headers=player[1]).status_code==200
    invitation=send().json()['id']
    assert c.delete(path+'/account-invites/'+invitation,headers=owner[1]).status_code==200
    assert c.post(f'/api/v1/me/invitations/{invitation}/accept',headers=player[1]).status_code==404
    invitation=send(role='captain').json()['id']
    with app.state.engine.begin() as conn:
        conn.execute(update(account_invites).where(account_invites.c.id==invitation).values(expires=time.time()-1))
    assert c.get('/api/v1/me/invitations',headers=player[1]).json()['items']==[]
    assert c.post(f'/api/v1/me/invitations/{invitation}/accept',headers=player[1]).status_code==404
    invitation=send(role='captain').json()['id']
    c.post(f'/api/v1/me/invitations/{invitation}/accept',headers=player[1])
    assert send(stranger,role='coach',sender=player).status_code==403
    invitation=send(stranger,sender=player).json()['id']
    c.patch(path+'/members/'+player[0],headers=owner[1],json={'role':'player'})
    assert c.post(f'/api/v1/me/invitations/{invitation}/accept',headers=stranger[1]).status_code==403
    assert c.post(path+'/leave',headers=owner[1]).json()['error']['code']=='transfer_ownership_first'
    assert c.post(path+'/leave',headers=player[1]).status_code==200


def test_profile_health_and_cancel_return_to_native(setup):
    _,c,(owner,_,_)=setup
    assert c.patch('/api/v1/me',headers=owner[1],json={'name':'Captain','language':'en'}).status_code==200
    assert c.get('/api/v1/me',headers=owner[1]).json()['name']=='Captain'
    assert c.patch('/api/v1/me',headers=owner[1],json={'name':' '}).status_code==422
    assert c.get('/api/v1/health').json()['providers']['steam'] is True
    import secrets
    from server.auth import challenge
    from urllib.parse import parse_qs,urlsplit
    start=c.post('/api/v1/auth/steam/start',json={'redirect':'teamsync://auth/callback','challenge':challenge(secrets.token_urlsafe(48))}).json()
    callback=parse_qs(urlsplit(start['url']).query)['openid.return_to'][0]
    cancelled=c.get(callback+'&openid.mode=cancel',follow_redirects=False)
    assert cancelled.status_code==303
    assert cancelled.headers['location']=='teamsync://auth/callback?error=provider_cancelled'

