import asyncio
import secrets
from datetime import datetime,timezone
import httpx
import pytest
from fastapi import HTTPException
import server.auth as auth


def test_real_steam_verification_protocol_rejects_invalid_assertion(monkeypatch):
    base='https://teamsync.example'
    query={'state':secrets.token_urlsafe(32),'openid.ns':'http://specs.openid.net/auth/2.0','openid.mode':'id_res','openid.op_endpoint':'https://steamcommunity.com/openid/login','openid.claimed_id':'https://steamcommunity.com/openid/id/76561198000000001','openid.response_nonce':datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')+'nonce','openid.assoc_handle':'fixture','openid.signed':'op_endpoint,claimed_id,identity,return_to,response_nonce,assoc_handle'}
    query['openid.identity']=query['openid.claimed_id']
    query['openid.return_to']=base+'/api/v1/auth/steam/callback?state='+query['state']
    real=httpx.AsyncClient
    def transport(request):
        assert str(request.url)=='https://steamcommunity.com/openid/login'
        assert b'check_authentication' in request.content
        return httpx.Response(200,text='ns:http://specs.openid.net/auth/2.0\nis_valid:true\n')
    monkeypatch.setattr(auth.httpx,'AsyncClient',lambda **kw:real(transport=httpx.MockTransport(transport),**kw))
    assert asyncio.run(auth.verified_identity('steam',query,base,'',''))[0]=='76561198000000001'
    for change in [{'openid.return_to':'https://evil.example'},{'openid.signed':'identity'},{'openid.identity':'https://steamcommunity.com/openid/id/76561198000000002'}]:
        with pytest.raises(HTTPException):asyncio.run(auth.verified_identity('steam',{**query,**change},base,'',''))


def test_discord_code_exchange_uses_server_secret_and_validated_issuer(monkeypatch):
    real=httpx.AsyncClient
    def transport(request):
        if request.url.path=='/api/oauth2/token':
            assert b'client_secret=server-only' in request.content
            return httpx.Response(200,json={'access_token':'provider-token'})
        assert request.headers['Authorization']=='Bearer provider-token'
        return httpx.Response(200,json={'id':'123456789012345678','global_name':'Entry'})
    monkeypatch.setattr(auth.httpx,'AsyncClient',lambda **kw:real(transport=httpx.MockTransport(transport),**kw))
    query={'code':'fixture','iss':'https://discord.com'}
    assert asyncio.run(auth.verified_identity('discord',query,'https://teamsync.example','client','server-only'))==('123456789012345678','Entry')
    with pytest.raises(HTTPException):asyncio.run(auth.verified_identity('discord',{**query,'iss':'https://evil.example'},'https://teamsync.example','client','server-only'))
