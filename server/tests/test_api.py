import secrets
import time
from urllib.parse import parse_qs, urlsplit

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from server.app import create_app
from server.auth import digest, challenge, finish_auth
from server.database import users, sessions, identities, uid

@pytest.fixture
def setup(tmp_path):
    app=create_app('sqlite:///'+str(tmp_path/'server.sqlite'))
    client=TestClient(app)
    people=[]
    with app.state.engine.begin() as conn:
        for name in ['Owner','Player','Stranger']:
            user=uid();token=secrets.token_urlsafe(32)
            conn.execute(users.insert().values(id=user,name=name,language='ru'))
            conn.execute(sessions.insert().values(id=uid(),user_id=user,token_hash=digest(token),device='test fixture',expires=time.time()+3600,created=time.time()))
            people.append((user,{'Authorization':'Bearer '+token}))
    yield app,client,people
    client.close();app.state.engine.dispose()

def test_auth_required_validation_and_isolation(setup):
    app,c,people=setup
    owner,player,stranger=people
    assert c.get('/api/v1/teams').status_code==401
    assert c.post('/api/v1/teams',headers=owner[1],json={'name':' '}).status_code==422
    team=c.post('/api/v1/teams',headers=owner[1],json={'name':'Team'}).json()['id']
    assert c.get(f'/api/v1/teams/{team}/documents',headers=stranger[1]).status_code==404
    invite=c.post(f'/api/v1/teams/{team}/invites',headers=owner[1],json={'role':'player'}).json()
    assert c.post('/api/v1/invites/join',headers=player[1],json={'code':invite['code']}).status_code==200
    assert c.post('/api/v1/invites/join',headers=stranger[1],json={'code':invite['code']}).status_code==404
    body={'operation_id':uid(),'document_id':uid(),'expected_version':0,'kind':'map','payload':{'title':'Mirage'}}
    assert c.post(f'/api/v1/teams/{team}/documents',headers=player[1],json=body).status_code==403
    assert c.get(f'/api/v1/teams/{team}/documents',headers=player[1]).status_code==200
    assert c.delete(f'/api/v1/teams/{team}/members/{player[0]}',headers=owner[1]).status_code==200
    assert c.get(f'/api/v1/teams/{team}/documents',headers=player[1]).status_code==404

def test_idempotency_versions_history_and_foreign_links(setup):
    app,c,people=setup;owner,_,stranger=people
    team=c.post('/api/v1/teams',headers=owner[1],json={'name':'A'}).json()['id']
    other=c.post('/api/v1/teams',headers=stranger[1],json={'name':'B'}).json()['id']
    body={'operation_id':uid(),'document_id':uid(),'expected_version':0,'kind':'map','payload':{'title':'Mirage'}}
    first=c.post(f'/api/v1/teams/{team}/documents',headers=owner[1],json=body)
    assert first.status_code==200
    assert c.post(f'/api/v1/teams/{team}/documents',headers=owner[1],json=body).json()==first.json()
    changed={**body,'payload':{'title':'Changed'}}
    assert c.post(f'/api/v1/teams/{team}/documents',headers=owner[1],json=changed).status_code==409
    stale={**body,'operation_id':uid()}
    assert c.post(f'/api/v1/teams/{team}/documents',headers=owner[1],json=stale).status_code==409
    update={**changed,'operation_id':uid(),'expected_version':1}
    assert c.post(f'/api/v1/teams/{team}/documents',headers=owner[1],json=update).json()['version']==2
    history=c.get(f'/api/v1/teams/{team}/documents/{body["document_id"]}/versions',headers=owner[1]).json()['items']
    assert [v['version'] for v in history]==[2,1]
    foreign={'operation_id':uid(),'document_id':uid(),'expected_version':0,'kind':'strategy','payload':{'title':'A execute','side':'T','map_id':body['document_id']}}
    assert c.post(f'/api/v1/teams/{other}/documents',headers=stranger[1],json=foreign).status_code==422
    assert c.get(f'/api/v1/teams/{other}/documents/{body["document_id"]}/versions',headers=stranger[1]).status_code==404

def test_pkce_code_is_one_time_no_unverified_identity(setup):
    app,c,people=setup
    verifier=secrets.token_urlsafe(48)
    start=c.post('/api/v1/auth/steam/start',json={'redirect':'http://127.0.0.1:54321/callback','challenge':challenge(verifier)})
    assert start.status_code==200
    state=parse_qs(urlsplit(parse_qs(urlsplit(start.json()['url']).query)['openid.return_to'][0]).query)['state'][0]
    # Provider verification is outside this unit test. Simulate its trusted result internally.
    with app.state.engine.begin() as conn:
        redirect=finish_auth(conn,state,'steam','76561198000000001','Steam fixture')
    code=parse_qs(urlsplit(redirect).query)['code'][0]
    wrong=c.post('/api/v1/auth/exchange',json={'code':code,'verifier':secrets.token_urlsafe(48),'device':'PC'})
    assert wrong.status_code==401
    exchange={'code':code,'verifier':verifier,'device':'PC'}
    result=c.post('/api/v1/auth/exchange',json=exchange)
    assert result.status_code==200
    assert c.post('/api/v1/auth/exchange',json=exchange).status_code==401
    headers={'Authorization':'Bearer '+result.json()['access_token']}
    assert c.get('/api/v1/me',headers=headers).json()['identities'][0]['provider']=='steam'
    assert c.delete('/api/v1/me/identities/steam',headers=headers).json()['error']['code']=='last_identity'
    session=c.get('/api/v1/me/sessions',headers=headers).json()['items'][0]
    assert 'token_hash' not in session
    c.delete('/api/v1/me/sessions/'+session['id'],headers=headers)
    assert c.get('/api/v1/me',headers=headers).status_code==401

def test_redirect_validation_and_bad_callbacks(setup):
    _,c,_=setup;pkce=challenge(secrets.token_urlsafe(48))
    for redirect in ['https://attacker.example/callback','http://localhost:8000/callback','http://127.0.0.1:8000/callback?to=bad','teamsync://evil/callback']:
        assert c.post('/api/v1/auth/steam/start',json={'redirect':redirect,'challenge':pkce}).status_code==400
    assert c.get('/api/v1/auth/steam/callback?state=missing').status_code==401

def test_ownership_transfer(setup):
    _,c,people=setup;owner,player,_=people
    team=c.post('/api/v1/teams',headers=owner[1],json={'name':'A'}).json()['id']
    code=c.post(f'/api/v1/teams/{team}/invites',headers=owner[1],json={}).json()['code']
    c.post('/api/v1/invites/join',headers=player[1],json={'code':code})
    assert c.post(f'/api/v1/teams/{team}/ownership',headers=owner[1],json={'user_id':player[0]}).status_code==200
    assert c.post(f'/api/v1/teams/{team}/ownership',headers=owner[1],json={'user_id':player[0]}).status_code==403
    roster=c.get(f'/api/v1/teams/{team}/members',headers=player[1]).json()['items']
    assert {r['id']:r['role'] for r in roster}=={owner[0]:'captain',player[0]:'owner'}

def test_linking_keeps_internal_user_and_never_merges_by_name(setup):
    app,c,people=setup;owner,_,_=people
    verifier=secrets.token_urlsafe(48)
    start=c.post('/api/v1/me/identities/steam/start',headers=owner[1],json={'redirect':'teamsync://auth/callback','challenge':challenge(verifier)})
    state=parse_qs(urlsplit(parse_qs(urlsplit(start.json()['url']).query)['openid.return_to'][0]).query)['state'][0]
    with app.state.engine.begin() as conn:
        redirect=finish_auth(conn,state,'steam','76561198000000002','Different name')
    code=parse_qs(urlsplit(redirect).query)['code'][0]
    result=c.post('/api/v1/auth/exchange',json={'code':code,'verifier':verifier,'device':'test'}).json()
    assert result['user_id']==owner[0]
    with app.state.engine.connect() as conn:
        assert conn.execute(select(identities).where(identities.c.subject=='76561198000000002')).mappings().one()['user_id']==owner[0]
