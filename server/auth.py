import base64
import hashlib
import re
import secrets
import time
from urllib.parse import urlencode, urlsplit

import httpx
from fastapi import HTTPException
from sqlalchemy import select, delete
from .database import users, identities, auth_states, auth_codes, sessions, uid

def fail(code, status=400):
    raise HTTPException(status, detail={'code': code})

def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()

def challenge(verifier):
    return base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')

def validate_redirect(value):
    p = urlsplit(value)
    if p.username or p.password or p.query or p.fragment:
        fail('invalid_redirect')
    # Native mobile registered callback or Windows loopback callback with PKCE.
    if value == 'teamsync://auth/callback':
        return
    try:
        port = p.port
    except ValueError:
        fail('invalid_redirect')
    if p.scheme != 'http' or p.hostname != '127.0.0.1' or not port or p.path != '/callback':
        fail('invalid_redirect')

def start_auth(conn, provider, redirect, pkce, public_url, discord_id, link_user=None):
    validate_redirect(redirect)
    if not re.fullmatch(r'[A-Za-z0-9_-]{43}', pkce):
        fail('invalid_challenge')
    if provider not in ('steam','discord'):
        fail('invalid_provider')
    if provider == 'discord' and not discord_id:
        fail('provider_not_configured',503)
    state = secrets.token_urlsafe(32)
    conn.execute(auth_states.delete().where(auth_states.c.expires < time.time()))
    conn.execute(auth_codes.delete().where(auth_codes.c.expires < time.time()))
    conn.execute(auth_states.insert().values(state_hash=digest(state),provider=provider,challenge=pkce,redirect=redirect,link_user=link_user,expires=time.time()+300))
    callback = public_url + '/api/v1/auth/' + provider + '/callback'
    if provider == 'discord':
        url = 'https://discord.com/oauth2/authorize?' + urlencode({'client_id':discord_id,'redirect_uri':callback,'response_type':'code','scope':'identify','state':state,'prompt':'consent'})
    else:
        callback += '?' + urlencode({'state':state})
        url = 'https://steamcommunity.com/openid/login?' + urlencode({'openid.ns':'http://specs.openid.net/auth/2.0','openid.mode':'checkid_setup','openid.return_to':callback,'openid.realm':public_url+'/','openid.identity':'http://specs.openid.net/auth/2.0/identifier_select','openid.claimed_id':'http://specs.openid.net/auth/2.0/identifier_select'})
    return {'url':url,'expires_in':300}

async def verified_identity(provider, query, public_url, discord_id, discord_secret):
    async with httpx.AsyncClient(timeout=15, follow_redirects=False) as client:
        if provider == 'discord':
            if query.get('iss') not in (None,'https://discord.com'):
                fail('provider_verification_failed',401)
            if not discord_id or not discord_secret:
                fail('provider_not_configured',503)
            if not query.get('code') or query.get('error'):
                fail('provider_cancelled')
            response = await client.post('https://discord.com/api/oauth2/token',data={'client_id':discord_id,'client_secret':discord_secret,'grant_type':'authorization_code','code':query['code'],'redirect_uri':public_url+'/api/v1/auth/discord/callback'})
            if response.status_code != 200:
                fail('provider_verification_failed',401)
            token = response.json().get('access_token')
            if not token:
                fail('provider_verification_failed',401)
            profile = await client.get('https://discord.com/api/v10/users/@me',headers={'Authorization':'Bearer '+token})
            if profile.status_code != 200:
                fail('provider_verification_failed',401)
            value = profile.json()
            if not re.fullmatch(r'\d{1,32}',str(value.get('id',''))):
                fail('provider_verification_failed',401)
            return str(value['id']), str(value.get('global_name') or value.get('username') or value['id'])[:120]
        expected = public_url+'/api/v1/auth/steam/callback?'+urlencode({'state':query.get('state','')})
        claimed = query.get('openid.claimed_id','')
        signed = set(query.get('openid.signed','').split(','))
        if (query.get('openid.ns') != 'http://specs.openid.net/auth/2.0' or
            query.get('openid.mode') != 'id_res' or
            query.get('openid.op_endpoint') != 'https://steamcommunity.com/openid/login' or
            query.get('openid.return_to') != expected or query.get('openid.identity') != claimed or
            not {'op_endpoint','claimed_id','identity','return_to','response_nonce','assoc_handle'}.issubset(signed)):
            fail('provider_verification_failed',401)
        match = re.fullmatch(r'https://steamcommunity.com/openid/id/(\d{17})',claimed)
        if not match:
            fail('provider_verification_failed',401)
        from datetime import datetime, timezone
        try:
            nonce_time = datetime.strptime(query['openid.response_nonce'][:20],'%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc).timestamp()
            if abs(time.time()-nonce_time)>300:
                fail('expired_nonce',401)
        except (KeyError,ValueError):
            fail('invalid_nonce',401)
        data={k:v for k,v in query.items() if k.startswith('openid.')}
        data['openid.mode']='check_authentication'
        result=await client.post('https://steamcommunity.com/openid/login',data=data)
        if result.status_code!=200 or 'is_valid:true' not in result.text.splitlines():
            fail('provider_verification_failed',401)
        return match[1],match[1]

def finish_auth(conn, state, provider, subject, name):
    pending=conn.execute(select(auth_states).where(auth_states.c.state_hash==digest(state)).with_for_update()).mappings().first()
    if not pending or pending['provider']!=provider or pending['expires']<time.time():
        fail('expired_state',401)
    existing=conn.execute(select(identities).where(identities.c.provider==provider,identities.c.subject==subject)).mappings().first()
    target=pending['link_user']
    if target:
        if existing and existing['user_id']!=target:
            fail('identity_already_linked',409)
        same_provider=conn.execute(select(identities).where(identities.c.user_id==target,identities.c.provider==provider)).mappings().first()
        if same_provider and same_provider['subject']!=subject:
            fail('provider_already_linked',409)
    elif existing:
        target=existing['user_id']
    else:
        target=uid()
        conn.execute(users.insert().values(id=target,name=name,language='ru'))
    if not existing:
        conn.execute(identities.insert().values(id=uid(),user_id=target,provider=provider,subject=subject))
    code=secrets.token_urlsafe(32)
    conn.execute(auth_codes.insert().values(code_hash=digest(code),user_id=target,challenge=pending['challenge'],expires=time.time()+60))
    conn.execute(delete(auth_states).where(auth_states.c.state_hash==digest(state)))
    return pending['redirect']+'?'+urlencode({'code':code})

def exchange_code(conn, code, verifier, device):
    if not re.fullmatch(r'[A-Za-z0-9._~-]{43,128}',verifier):
        fail('invalid_verifier',401)
    row=conn.execute(select(auth_codes).where(auth_codes.c.code_hash==digest(code)).with_for_update()).mappings().first()
    if not row or row['expires']<time.time() or not secrets.compare_digest(row['challenge'],challenge(verifier)):
        fail('invalid_code',401)
    # Conditional delete also prevents replay on development SQLite (no row locks).
    removed=conn.execute(delete(auth_codes).where(auth_codes.c.code_hash==digest(code)))
    if removed.rowcount!=1:
        fail('invalid_code',401)
    token=secrets.token_urlsafe(48)
    conn.execute(sessions.insert().values(id=uid(),user_id=row['user_id'],token_hash=digest(token),device=device,expires=time.time()+30*86400,created=time.time()))
    return {'access_token':token,'token_type':'Bearer','expires_in':30*86400,'user_id':row['user_id']}
