import hashlib
import base64
import json
import os
import re
import secrets
import time
from collections import OrderedDict
from threading import Lock
from typing import Literal, Annotated

import httpx
from fastapi import FastAPI, Depends, Header, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, RedirectResponse, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator, StringConstraints
from sqlalchemy import select, delete, update, func
from sqlalchemy.exc import IntegrityError

from .database import (open_database, users, identities, sessions, auth_states, teams,
    memberships, invites, account_invites, roster_details, media, documents, document_versions, operations, audit, uid, record)
from .media_types import media_type
from .skills import attach_skill_routes
from .auth import (fail, digest, start_auth, verified_identity, finish_auth, exchange_code)

class StrictModel(BaseModel):
    model_config=ConfigDict(extra='forbid',str_strip_whitespace=True)

class AuthStart(StrictModel):
    redirect: str = Field(max_length=300)
    challenge: str = Field(min_length=43,max_length=43)

class Exchange(StrictModel):
    code: str = Field(min_length=20,max_length=100)
    verifier: str = Field(min_length=43,max_length=128)
    device: str = Field(min_length=1,max_length=120)

class TeamInput(StrictModel):
    name: str = Field(min_length=1,max_length=120)

class InviteInput(StrictModel):
    role: Literal['captain','coach','player','viewer']='player'
    expires_hours: int = Field(default=24,ge=1,le=168)

class JoinInput(StrictModel):
    code: str = Field(min_length=20,max_length=100)

class TransferInput(StrictModel):
    user_id: str = Field(min_length=36,max_length=36)

class LanguageInput(StrictModel):
    language: Literal['ru','en'] | None = None
    name: str | None = Field(default=None,min_length=1,max_length=120)

class AccountInviteInput(InviteInput):
    user_id: str = Field(min_length=36,max_length=36)

class MemberInput(StrictModel):
    role: Literal['owner','captain','coach','player','viewer']
    game_role: str = Field(default='',max_length=40)
    squad: Literal['main','reserve','staff']='main'

class TacticalObject(StrictModel):
    type: Literal['marker','t','ct','smoke','flash','molotov','arrow']
    x: float = Field(ge=0,le=1,allow_inf_nan=False)
    y: float = Field(ge=0,le=1,allow_inf_nan=False)
    x2: float | None = Field(default=None,ge=0,le=1,allow_inf_nan=False)
    y2: float | None = Field(default=None,ge=0,le=1,allow_inf_nan=False)

class UtilityDetails(StrictModel):
    strategy_ids: list[Annotated[str,StringConstraints(min_length=36,max_length=36)]] = Field(default_factory=list,max_length=50)
    grenade: Literal['smoke','flash','molotov','he','decoy']
    start: str = Field(default='',max_length=500)
    target: str = Field(default='',max_length=500)
    throw_type: str = Field(default='',max_length=120)
    author: str = Field(default='',max_length=120)
    source_url: str | None = Field(default=None,max_length=2000)
    verified_at: str = Field(default='',max_length=40)
    map_revision: str = Field(default='',max_length=120)
    image_ids: list[Annotated[str,StringConstraints(pattern=r'^[0-9a-f]{64}$')]] = Field(default_factory=list,max_length=10)
    video_id: str | None = Field(default=None,pattern=r'^[0-9a-f]{64}$')
    training_revision: int = Field(default=1,ge=1,le=1000000000)
    review_reason: str = Field(default='',max_length=500)

    @field_validator('source_url')
    @classmethod
    def supported_source(cls,value):
        if value is None:return value
        from urllib.parse import urlsplit
        parsed=urlsplit(value)
        if parsed.scheme!='https' or parsed.username or parsed.password or parsed.port or parsed.hostname not in (
            'youtube.com','www.youtube.com','m.youtube.com','youtu.be','cs2tricks.com','www.cs2tricks.com'):
            raise ValueError('unsupported_source')
        return value

class DocumentPayload(StrictModel):
    title: str = Field(min_length=1,max_length=120)
    utility: UtilityDetails | None = None
    notes: Annotated[str,StringConstraints(strip_whitespace=False)] = Field(default='',max_length=20000)
    map_id: str | None = Field(default=None,max_length=36)
    strategy_id: str | None = Field(default=None,max_length=36)
    assignee_user_id: str | None = Field(default=None,max_length=36)
    side: Literal['T','CT'] | None = None
    status: Literal['todo','in_progress','submitted','approved']='todo'
    task_review_reason: str = Field(default='',max_length=2000)
    objects: list[TacticalObject] = Field(default_factory=list,max_length=2000)
    catalog_id: str | None = Field(default=None,max_length=80)
    level: Literal['default','lower']='default'
    image_id: str | None = Field(default=None,pattern=r'^[0-9a-f]{64}$')
    lower_image_id: str | None = Field(default=None,pattern=r'^[0-9a-f]{64}$')

    @field_validator('objects')
    @classmethod
    def arrows_have_end(cls,value):
        if any(o.type=='arrow' and (o.x2 is None or o.y2 is None) for o in value):
            raise ValueError('arrow_requires_end')
        return value

class DocumentWrite(StrictModel):
    operation_id: str
    document_id: str
    expected_version: int = Field(ge=0)
    kind: Literal['map','strategy','task','utility']
    payload: DocumentPayload

    @field_validator('operation_id','document_id')
    @classmethod
    def uuid_value(cls,value):
        import uuid
        return str(uuid.UUID(value))

def create_app(database_url=None, public_url=None):
    app=FastAPI(title='TeamSync API',version='0.7.0',docs_url=None,redoc_url=None)
    engine=open_database(database_url or os.getenv('DATABASE_URL','sqlite:///./teamsync-server.sqlite'))
    app.state.engine=engine
    base=(public_url or os.getenv('PUBLIC_URL','http://127.0.0.1:8000')).rstrip('/')
    if not (base.startswith('https://') or re.fullmatch(r'http://127\.0\.0\.1:\d+',base)):
        raise ValueError('PUBLIC_URL must use HTTPS or local development loopback')
    discord_id=os.getenv('DISCORD_CLIENT_ID','')
    discord_secret=os.getenv('DISCORD_CLIENT_SECRET','')
    auth_attempts=OrderedDict()
    auth_lock=Lock()

    @app.exception_handler(HTTPException)
    async def api_error(request,exc):
        code=exc.detail.get('code','request_failed') if isinstance(exc.detail,dict) else 'request_failed'
        return JSONResponse({'error':{'code':code}},status_code=exc.status_code)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request,exc):
        return JSONResponse({'error':{'code':'validation_error','fields':[{'path':list(e['loc']),'type':e['type']} for e in exc.errors()]}},status_code=422)

    @app.exception_handler(IntegrityError)
    async def integrity_error(request,exc):
        return JSONResponse({'error':{'code':'write_conflict'}},status_code=409)

    @app.middleware('http')
    async def secure_responses(request,call_next):
        if request.url.path.startswith('/api/v1/auth/') and request.method=='POST':
            key=(request.client.host if request.client else 'unknown',int(time.time()//60))
            with auth_lock:
                count=auth_attempts.get(key,0)+1
                auth_attempts[key]=count
                auth_attempts.move_to_end(key)
                while len(auth_attempts)>10000: auth_attempts.popitem(last=False)
            if count>60:
                return JSONResponse({'error':{'code':'rate_limited'}},status_code=429,headers={'Retry-After':'60','Cache-Control':'no-store'})
        # Keep tokens and short-lived callback codes out of caches/referrers.
        try:
            length=int(request.headers.get('content-length','0'))
        except ValueError:
            return JSONResponse({'error':{'code':'invalid_length'}},status_code=400)
        body_limit=20*1024*1024 if request.url.path.startswith('/api/v1/teams/') and '/media/' in request.url.path and request.method=='PUT' else 1024*1024
        if length>body_limit:
            return JSONResponse({'error':{'code':'request_too_large'}},status_code=413)
        chunks=[]
        received=0
        async for chunk in request.stream():
            received+=len(chunk)
            if received>body_limit:
                return JSONResponse({'error':{'code':'request_too_large'}},status_code=413)
            chunks.append(chunk)
        request._body=b''.join(chunks)
        response=await call_next(request)
        response.headers['Cache-Control']='no-store'
        response.headers['Referrer-Policy']='no-referrer'
        response.headers['X-Content-Type-Options']='nosniff'
        return response

    def authenticated(authorization: str | None = Header(default=None)):
        if not authorization or not authorization.startswith('Bearer '):
            fail('unauthorized',401)
        with engine.connect() as conn:
            session=conn.execute(select(sessions).where(sessions.c.token_hash==digest(authorization[7:]),sessions.c.expires>time.time())).mappings().first()
            if not session:
                fail('unauthorized',401)
            return dict(session)

    def member(conn,team,user,write=False,owner=False):
        value=conn.execute(select(memberships).where(memberships.c.team_id==team,memberships.c.user_id==user)).mappings().first()
        if not value:
            fail('not_found',404)
        if owner and value['role']!='owner' or write and value['role'] not in ('owner','captain','coach'):
            fail('forbidden',403)
        return value

    attach_skill_routes(app,engine,authenticated,member)

    @app.get('/api/v1/health')
    def health():
        return {'status':'ok','version':'0.7.0','providers':{'steam':True,'discord':bool(discord_id and discord_secret)},'capabilities':['identity','teams','account_invites','roster','tactical_sync','training_sync','utilities','utility_skills','team_media','versioned_documents'],'native_client_required':True}

    @app.post('/api/v1/auth/{provider}/start')
    def auth_start(provider:str,body:AuthStart):
        with engine.begin() as conn:
            return start_auth(conn,provider,body.redirect,body.challenge,base,discord_id)

    @app.post('/api/v1/me/identities/{provider}/start')
    def link_start(provider:str,body:AuthStart,session=Depends(authenticated)):
        if session['created']<time.time()-300:
            fail('reauthentication_required',401)
        with engine.begin() as conn:
            return start_auth(conn,provider,body.redirect,body.challenge,base,discord_id,session['user_id'])

    @app.get('/api/v1/auth/{provider}/callback')
    async def auth_callback(provider:str,request:Request):
        query=dict(request.query_params)
        state=query.get('state','')
        with engine.connect() as conn:
            pending=conn.execute(select(auth_states).where(auth_states.c.state_hash==digest(state))).mappings().first()
            if not pending or pending['provider']!=provider or pending['expires']<time.time():
                fail('expired_state',401)
        try:
            if query.get('error') or query.get('openid.mode')=='cancel':
                with engine.begin() as conn:
                    conn.execute(delete(auth_states).where(auth_states.c.state_hash==digest(state)))
                return RedirectResponse(pending['redirect']+'?error=provider_cancelled',status_code=303)
            subject,name=await verified_identity(provider,query,base,discord_id,discord_secret)
        except (httpx.HTTPError,HTTPException) as error:
            code='provider_unavailable' if isinstance(error,httpx.HTTPError) else error.detail.get('code','provider_verification_failed')
            with engine.begin() as conn:
                conn.execute(delete(auth_states).where(auth_states.c.state_hash==digest(state)))
            return RedirectResponse(pending['redirect']+'?error='+code,status_code=303)
        with engine.begin() as conn:
            redirect=finish_auth(conn,state,provider,subject,name)
        return RedirectResponse(redirect,status_code=303)

    @app.post('/api/v1/auth/exchange')
    def exchange(body:Exchange):
        with engine.begin() as conn:
            return exchange_code(conn,body.code,body.verifier,body.device)

    @app.get('/api/v1/me')
    def me(session=Depends(authenticated)):
        with engine.connect() as conn:
            user=dict(conn.execute(select(users).where(users.c.id==session['user_id'])).mappings().one())
            user['identities']=[dict(row) for row in conn.execute(select(identities.c.provider,identities.c.subject).where(identities.c.user_id==user['id'])).mappings()]
            user['session_id']=session['id']
            return user

    @app.post('/api/v1/auth/logout')
    def logout(session=Depends(authenticated)):
        with engine.begin() as conn:
            conn.execute(delete(sessions).where(sessions.c.id==session['id']))
        return {'ok':True}

    @app.patch('/api/v1/me')
    def update_me(body:LanguageInput,session=Depends(authenticated)):
        with engine.begin() as conn:
            values=body.model_dump(exclude_none=True)
            if not values: fail('validation_error',422)
            conn.execute(update(users).where(users.c.id==session['user_id']).values(**values))
        return values

    @app.delete('/api/v1/me/identities/{provider}')
    def unlink(provider:str,session=Depends(authenticated)):
        if session['created']<time.time()-300:
            fail('reauthentication_required',401)
        with engine.begin() as conn:
            # Serialize unlink attempts on the user row in PostgreSQL.
            conn.execute(select(users).where(users.c.id==session['user_id']).with_for_update()).one()
            linked=conn.execute(select(identities).where(identities.c.user_id==session['user_id'])).mappings().all()
            if len(linked)<2:
                fail('last_identity',409)
            conn.execute(delete(identities).where(identities.c.user_id==session['user_id'],identities.c.provider==provider))
        return {'ok':True}

    @app.get('/api/v1/me/sessions')
    def list_sessions(session=Depends(authenticated)):
        with engine.connect() as conn:
            return {'items':[dict(row) for row in conn.execute(select(sessions.c.id,sessions.c.device,sessions.c.created,sessions.c.expires).where(sessions.c.user_id==session['user_id'],sessions.c.expires>time.time()).limit(100)).mappings()]}

    @app.delete('/api/v1/me/sessions/{session_id}')
    def revoke(session_id:str,session=Depends(authenticated)):
        with engine.begin() as conn:
            conn.execute(delete(sessions).where(sessions.c.id==session_id,sessions.c.user_id==session['user_id']))
        return {'ok':True}

    @app.get('/api/v1/teams')
    def list_teams(session=Depends(authenticated),offset:int=Query(0,ge=0),limit:int=Query(50,ge=1,le=100)):
        with engine.connect() as conn:
            query=select(teams,memberships.c.role).join(memberships,memberships.c.team_id==teams.c.id).where(memberships.c.user_id==session['user_id']).order_by(teams.c.created,teams.c.id).offset(offset).limit(limit)
            return {'items':[dict(row) for row in conn.execute(query).mappings()],'offset':offset,'limit':limit}

    @app.post('/api/v1/teams',status_code=201)
    def create_team(body:TeamInput,session=Depends(authenticated)):
        team=uid()
        with engine.begin() as conn:
            conn.execute(teams.insert().values(id=team,name=body.name,owner_id=session['user_id'],created=time.time()))
            conn.execute(memberships.insert().values(id=uid(),team_id=team,user_id=session['user_id'],role='owner'))
            record(conn,team,session['user_id'],'team.created',team)
        return {'id':team,'name':body.name,'role':'owner'}

    @app.get('/api/v1/teams/{team}/members')
    def roster(team:str,session=Depends(authenticated),offset:int=Query(0,ge=0),limit:int=Query(50,ge=1,le=100)):
        with engine.connect() as conn:
            member(conn,team,session['user_id'])
            query=select(users.c.id,users.c.name,memberships.c.role,roster_details.c.game_role,roster_details.c.squad).join(memberships,users.c.id==memberships.c.user_id).outerjoin(roster_details,roster_details.c.membership_id==memberships.c.id).where(memberships.c.team_id==team).order_by(users.c.id).offset(offset).limit(limit)
            return {'items':[dict(row) for row in conn.execute(query).mappings()]}

    @app.get('/api/v1/users/lookup')
    def lookup(user_id:str=Query(min_length=36,max_length=36),session=Depends(authenticated)):
        with engine.connect() as conn:
            row=conn.execute(select(users.c.id,users.c.name).where(users.c.id==user_id)).mappings().first()
            if not row: fail('account_not_found',404)
            return dict(row)

    @app.post('/api/v1/teams/{team}/account-invites',status_code=201)
    def account_invite(team:str,body:AccountInviteInput,session=Depends(authenticated)):
        with engine.begin() as conn:
            caller=member(conn,team,session['user_id'],write=True)
            if caller['role']!='owner' and body.role not in ('player','viewer'): fail('forbidden',403)
            if not conn.execute(select(users.c.id).where(users.c.id==body.user_id)).first(): fail('account_not_found',404)
            if conn.execute(select(memberships.c.id).where(memberships.c.team_id==team,memberships.c.user_id==body.user_id)).first(): fail('already_member',409)
            conn.execute(delete(account_invites).where(account_invites.c.team_id==team,account_invites.c.recipient_id==body.user_id,account_invites.c.expires<time.time()))
            invitation=uid();expires=time.time()+body.expires_hours*3600
            conn.execute(account_invites.insert().values(id=invitation,team_id=team,sender_id=session['user_id'],recipient_id=body.user_id,role=body.role,expires=expires,created=time.time()))
            record(conn,team,session['user_id'],'account_invite.created',invitation)
            return {'id':invitation,'expires':expires}

    @app.get('/api/v1/me/invitations')
    def inbox(session=Depends(authenticated)):
        with engine.connect() as conn:
            query=select(account_invites.c.id,account_invites.c.team_id,teams.c.name,account_invites.c.role,account_invites.c.expires).join(teams,teams.c.id==account_invites.c.team_id).where(account_invites.c.recipient_id==session['user_id'],account_invites.c.expires>time.time()).order_by(account_invites.c.created.desc()).limit(100)
            return {'items':[dict(r) for r in conn.execute(query).mappings()]}

    @app.get('/api/v1/teams/{team}/account-invites')
    def outgoing(team:str,session=Depends(authenticated)):
        with engine.connect() as conn:
            member(conn,team,session['user_id'],write=True)
            query=select(account_invites.c.id,account_invites.c.recipient_id,users.c.name,account_invites.c.role,account_invites.c.expires).join(users,users.c.id==account_invites.c.recipient_id).where(account_invites.c.team_id==team,account_invites.c.expires>time.time()).limit(100)
            return {'items':[dict(r) for r in conn.execute(query).mappings()]}

    @app.delete('/api/v1/teams/{team}/account-invites/{invitation}')
    def cancel_account_invite(team:str,invitation:str,session=Depends(authenticated)):
        with engine.begin() as conn:
            member(conn,team,session['user_id'],write=True)
            conn.execute(delete(account_invites).where(account_invites.c.team_id==team,account_invites.c.id==invitation))
            record(conn,team,session['user_id'],'account_invite.revoked',invitation)
        return {'ok':True}

    @app.post('/api/v1/me/invitations/{invitation}/accept')
    def accept_account_invite(invitation:str,session=Depends(authenticated)):
        with engine.begin() as conn:
            row=conn.execute(select(account_invites).where(account_invites.c.id==invitation,account_invites.c.recipient_id==session['user_id']).with_for_update()).mappings().first()
            if not row or row['expires']<time.time(): fail('invalid_invite',404)
            # A removed/demoted sender cannot grant access with a stale invitation.
            sender=member(conn,row['team_id'],row['sender_id'],write=True)
            if sender['role']!='owner' and row['role'] not in ('player','viewer'): fail('forbidden',403)
            if conn.execute(select(memberships.c.id).where(memberships.c.team_id==row['team_id'],memberships.c.user_id==session['user_id'])).first(): fail('already_member',409)
            removed=conn.execute(delete(account_invites).where(account_invites.c.id==invitation))
            if removed.rowcount!=1: fail('invalid_invite',404)
            conn.execute(memberships.insert().values(id=uid(),team_id=row['team_id'],user_id=session['user_id'],role=row['role']))
            record(conn,row['team_id'],session['user_id'],'member.joined',session['user_id'])
            return {'team_id':row['team_id']}

    @app.delete('/api/v1/me/invitations/{invitation}')
    def decline_account_invite(invitation:str,session=Depends(authenticated)):
        with engine.begin() as conn:
            conn.execute(delete(account_invites).where(account_invites.c.id==invitation,account_invites.c.recipient_id==session['user_id']))
        return {'ok':True}

    @app.patch('/api/v1/teams/{team}/members/{user_id}')
    def edit_member(team:str,user_id:str,body:MemberInput,session=Depends(authenticated)):
        with engine.begin() as conn:
            caller=member(conn,team,session['user_id'],write=True)
            target=member(conn,team,user_id)
            if target['role']=='owner' and (caller['role']!='owner' or body.role!='owner') or body.role=='owner' and target['role']!='owner' or caller['role']!='owner' and (target['role'] in ('captain','coach') or body.role in ('captain','coach')): fail('forbidden',403)
            conn.execute(update(memberships).where(memberships.c.id==target['id']).values(role=body.role))
            conn.execute(delete(roster_details).where(roster_details.c.membership_id==target['id']))
            conn.execute(roster_details.insert().values(membership_id=target['id'],game_role=body.game_role,squad=body.squad))
            record(conn,team,session['user_id'],'member.updated',user_id)
        return {'ok':True}

    @app.post('/api/v1/teams/{team}/leave')
    def leave(team:str,session=Depends(authenticated)):
        with engine.begin() as conn:
            current=member(conn,team,session['user_id'])
            if current['role']=='owner': fail('transfer_ownership_first',409)
            conn.execute(delete(memberships).where(memberships.c.id==current['id']))
            conn.execute(delete(account_invites).where(account_invites.c.team_id==team,account_invites.c.sender_id==session['user_id']))
            record(conn,team,session['user_id'],'member.left',session['user_id'])
        return {'ok':True}

    @app.post('/api/v1/teams/{team}/invites',status_code=201)
    def invite(team:str,body:InviteInput,session=Depends(authenticated)):
        code=secrets.token_urlsafe(24)
        with engine.begin() as conn:
            role=member(conn,team,session['user_id'],write=True)['role']
            if role!='owner' and body.role not in ('player','viewer'):
                fail('forbidden',403)
            id=uid();expires=time.time()+body.expires_hours*3600
            conn.execute(invites.insert().values(id=id,team_id=team,code_hash=digest(code),role=body.role,expires=expires))
            record(conn,team,session['user_id'],'invite.created',id)
        return {'id':id,'code':code,'expires':expires,'role':body.role}

    @app.delete('/api/v1/teams/{team}/invites/{invite_id}')
    def revoke_invite(team:str,invite_id:str,session=Depends(authenticated)):
        with engine.begin() as conn:
            member(conn,team,session['user_id'],write=True)
            conn.execute(delete(invites).where(invites.c.id==invite_id,invites.c.team_id==team))
            record(conn,team,session['user_id'],'invite.revoked',invite_id)
        return {'ok':True}

    @app.post('/api/v1/invites/join')
    def join(body:JoinInput,session=Depends(authenticated)):
        with engine.begin() as conn:
            invite=conn.execute(select(invites).where(invites.c.code_hash==digest(body.code)).with_for_update()).mappings().first()
            if not invite or invite['expires']<time.time():
                fail('invalid_invite',404)
            existing=conn.execute(select(memberships).where(memberships.c.team_id==invite['team_id'],memberships.c.user_id==session['user_id'])).first()
            if existing:
                fail('already_member',409)
            removed=conn.execute(delete(invites).where(invites.c.id==invite['id']))
            if removed.rowcount!=1:
                fail('invalid_invite',404)
            conn.execute(memberships.insert().values(id=uid(),team_id=invite['team_id'],user_id=session['user_id'],role=invite['role']))
            record(conn,invite['team_id'],session['user_id'],'member.joined',session['user_id'])
        return {'team_id':invite['team_id'],'role':invite['role']}

    @app.delete('/api/v1/teams/{team}/members/{user_id}')
    def remove_member(team:str,user_id:str,session=Depends(authenticated)):
        with engine.begin() as conn:
            caller=member(conn,team,session['user_id'],write=True)
            target=member(conn,team,user_id)
            if target['role']=='owner' or caller['role']!='owner' and target['role'] in ('captain','coach'):
                fail('forbidden',403)
            conn.execute(delete(memberships).where(memberships.c.id==target['id']))
            conn.execute(delete(account_invites).where(account_invites.c.team_id==team,account_invites.c.sender_id==user_id))
            record(conn,team,session['user_id'],'member.removed',user_id)
        return {'ok':True}

    @app.post('/api/v1/teams/{team}/ownership')
    def transfer(team:str,body:TransferInput,session=Depends(authenticated)):
        with engine.begin() as conn:
            conn.execute(select(teams).where(teams.c.id==team).with_for_update()).first()
            old=member(conn,team,session['user_id'],owner=True)
            new=member(conn,team,body.user_id)
            if old['id']==new['id']:
                fail('same_owner')
            conn.execute(update(memberships).where(memberships.c.id==old['id']).values(role='captain'))
            conn.execute(update(memberships).where(memberships.c.id==new['id']).values(role='owner'))
            conn.execute(update(teams).where(teams.c.id==team).values(owner_id=body.user_id))
            record(conn,team,session['user_id'],'ownership.transferred',body.user_id)
        return {'ok':True}

    @app.get('/api/v1/teams/{team}/documents')
    def list_documents(team:str,session=Depends(authenticated),offset:int=Query(0,ge=0),limit:int=Query(50,ge=1,le=100)):
        with engine.connect() as conn:
            member(conn,team,session['user_id'])
            query=select(documents).where(documents.c.team_id==team).order_by(documents.c.updated,documents.c.id).offset(offset).limit(limit)
            return {'items':[dict(row) for row in conn.execute(query).mappings()],'offset':offset,'limit':limit}

    @app.put('/api/v1/teams/{team}/media/{identifier}')
    async def upload_media(team:str,identifier:str,request:Request,session=Depends(authenticated)):
        if not re.fullmatch('[0-9a-f]{64}',identifier):fail('invalid_media',422)
        with engine.begin() as conn:
            member(conn,team,session['user_id'],write=True)
            content=await request.body()
            if not content or hashlib.sha256(content).hexdigest()!=identifier:fail('invalid_media',422)
            mime=media_type(content)
            if mime is None:fail('invalid_media',422)
            old=conn.execute(select(media.c.id).where(media.c.team_id==team,media.c.id==identifier)).first()
            if not old:
                # Serialize quota checks for this team; blobs are immutable by SHA.
                conn.execute(select(teams.c.id).where(teams.c.id==team).with_for_update()).first()
                used=conn.execute(select(func.coalesce(func.sum(media.c.size),0)).where(media.c.team_id==team)).scalar_one()
                if used+len(content)>100*1024*1024:fail('media_quota',413)
                conn.execute(media.insert().values(id=identifier,team_id=team,content=content,mime=mime,size=len(content)))
            return {'id':identifier,'size':len(content)}

    @app.get('/api/v1/teams/{team}/media/{identifier}')
    def download_media(team:str,identifier:str,session=Depends(authenticated)):
        with engine.connect() as conn:
            member(conn,team,session['user_id'])
            row=conn.execute(select(media).where(media.c.team_id==team,media.c.id==identifier)).mappings().first()
            if not row:fail('not_found',404)
            return Response(content=row['content'],media_type=row['mime'])

    @app.post('/api/v1/teams/{team}/documents')
    def write_document(team:str,body:DocumentWrite,session=Depends(authenticated)):
        # Preserve the canonical request bytes of pre-utility clients so an
        # acknowledged operation can still be retried after a server upgrade.
        if body.payload.utility is None:
            excluded={'payload': {'utility'}}
        else:
            empty_new_fields=set()
            if not body.payload.utility.image_ids: empty_new_fields.add('image_ids')
            if body.payload.utility.video_id is None: empty_new_fields.add('video_id')
            if body.payload.utility.training_revision==1: empty_new_fields.add('training_revision')
            if not body.payload.utility.review_reason: empty_new_fields.add('review_reason')
            excluded={'payload': {'utility': empty_new_fields}}
        if not body.payload.task_review_reason:
            if isinstance(excluded['payload'],set): excluded['payload'].add('task_review_reason')
            else: excluded['payload']['task_review_reason']=True
        legacy_hash=hashlib.sha256(body.model_dump_json(exclude=excluded).encode()).hexdigest()
        provided=[] if body.payload.utility is None else sorted(
            f for f in ('image_ids','video_id') if f in body.payload.utility.model_fields_set)
        canonical=json.dumps({'request':body.model_dump(mode='json',exclude_unset=True),'utility_fields':provided},
                             sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()
        request_hash='v2:'+base64.urlsafe_b64encode(hashlib.sha256(canonical).digest()).decode().rstrip('=')
        with engine.begin() as conn:
            caller=member(conn,team,session['user_id'])
            manager=caller['role'] in ('owner','captain','coach')
            if not manager and (caller['role']!='player' or body.kind!='task'):
                fail('forbidden',403)
            previous=conn.execute(select(operations).where(operations.c.id==body.operation_id)).mappings().first()
            if previous:
                if previous['team_id']!=team or previous['user_id']!=session['user_id'] or previous['request_hash'] not in (request_hash,legacy_hash):
                    fail('operation_conflict',409)
                return previous['response']
            current=conn.execute(select(documents).where(documents.c.id==body.document_id).with_for_update()).mappings().first()
            if current and current['team_id']!=team:
                fail('not_found',404)
            if (current['version'] if current else 0)!=body.expected_version:
                fail('version_conflict',409)
            if current and current['kind']!=body.kind:
                fail('kind_conflict',409)
            payload=body.payload.model_dump()
            # Older clients cannot send fields they do not know. Preserve newer
            # attachments on their full-document edits; explicit null/[] removes them.
            if current and body.kind=='utility' and payload['utility']:
                old_utility=current['payload'].get('utility') or {}
                for field in ('image_ids','video_id','training_revision','review_reason'):
                    if field not in body.payload.utility.model_fields_set and field in old_utility:
                        payload['utility'][field]=old_utility[field]

            if current and body.kind=='task' and 'task_review_reason' not in body.payload.model_fields_set:
                payload['task_review_reason']=current['payload'].get('task_review_reason','')
            if current and body.kind=='task':
                previous_status=current['payload'].get('status','todo')
                allowed={'todo':('in_progress','submitted'),'in_progress':('submitted','todo'),'submitted':('approved','todo'),'approved':('todo',)}
                if payload['status']!=previous_status and payload['status'] not in allowed[previous_status]: fail('invalid_transition',422)
            if current and body.kind=='task' and payload['status']=='todo' and current['payload'].get('status')!='todo' and ('task_review_reason' not in body.payload.model_fields_set or not payload['task_review_reason']):
                fail('review_reason_required',422)

            if not manager:
                # Players may submit only their own existing assignment. Every
                # other field is immutable; approval belongs to the coaching staff.
                old=DocumentPayload.model_validate(current['payload']).model_dump() if current else {}
                if not current or old.get('assignee_user_id')!=session['user_id']:
                    fail('forbidden',403)
                if (old.get('status'),payload['status']) not in (('todo','in_progress'),('todo','submitted'),('in_progress','submitted')):
                    fail('forbidden',403)
                if {k:v for k,v in old.items() if k!='status'}!={k:v for k,v in payload.items() if k!='status'}:
                    fail('forbidden',403)
            for field in ('image_id','lower_image_id'):
                if payload[field] and not conn.execute(select(media.c.id).where(media.c.team_id==team,media.c.id==payload[field],media.c.mime.in_(['image/png','image/jpeg']))).first():fail('invalid_media',422)
            for key,kind in [('map_id','map'),('strategy_id','strategy')]:
                if payload[key]:
                    linked=conn.execute(select(documents).where(documents.c.id==payload[key],documents.c.team_id==team,documents.c.kind==kind)).first()
                    if not linked:
                        fail('invalid_link',422)
            if payload['utility']:
                old_revision=((current['payload'].get('utility') or {}).get('training_revision',1)) if current else payload['utility']['training_revision']
                revision=payload['utility']['training_revision']
                if revision not in (old_revision,old_revision+1): fail('invalid_training_revision',422)
                if revision>old_revision and not payload['utility']['review_reason']: fail('review_reason_required',422)
                video_id=payload['utility']['video_id']
                if video_id and not conn.execute(select(media.c.id).where(media.c.id==video_id,media.c.team_id==team,media.c.mime=='video/mp4')).first():
                    fail('invalid_media',422)
                for image_id in payload['utility']['image_ids']:
                    if not conn.execute(select(media.c.id).where(media.c.id==image_id,media.c.team_id==team,media.c.mime.in_(['image/png','image/jpeg']))).first():
                        fail('invalid_media',422)
                for linked_id in payload['utility']['strategy_ids']:
                    if not conn.execute(select(documents.c.id).where(documents.c.id==linked_id,documents.c.team_id==team,documents.c.kind=='strategy')).first():
                        fail('invalid_link',422)
            if body.kind=='utility' and (not payload['map_id'] or not payload['side'] or not payload['utility']):
                fail('utility_requires_map_side_details',422)
            if body.kind=='strategy' and (not payload['map_id'] or not payload['side']):
                fail('strategy_requires_map_side',422)
            if payload['assignee_user_id']:
                member(conn,team,payload['assignee_user_id'])
            version=body.expected_version+1
            timestamp=time.time()
            if current:
                changed=conn.execute(update(documents).where(documents.c.id==body.document_id,documents.c.version==body.expected_version).values(payload=payload,version=version,updated=timestamp))
                if changed.rowcount!=1:
                    fail('version_conflict',409)
            else:
                conn.execute(documents.insert().values(id=body.document_id,team_id=team,kind=body.kind,payload=payload,version=version,updated=timestamp))
            conn.execute(document_versions.insert().values(id=uid(),document_id=body.document_id,version=version,payload=payload,author_id=session['user_id'],created=timestamp))
            response={'id':body.document_id,'version':version,'updated':timestamp}
            conn.execute(operations.insert().values(id=body.operation_id,team_id=team,user_id=session['user_id'],request_hash=request_hash,response=response,created=timestamp))
            record(conn,team,session['user_id'],'document.saved',body.document_id)
            return response

    @app.get('/api/v1/teams/{team}/documents/{document}/versions')
    def history(team:str,document:str,session=Depends(authenticated),offset:int=Query(0,ge=0),limit:int=Query(50,ge=1,le=100)):
        with engine.connect() as conn:
            member(conn,team,session['user_id'])
            if not conn.execute(select(documents.c.id).where(documents.c.id==document,documents.c.team_id==team)).first():
                fail('not_found',404)
            return {'items':[dict(row) for row in conn.execute(select(document_versions).where(document_versions.c.document_id==document).order_by(document_versions.c.version.desc()).offset(offset).limit(limit)).mappings()]}

    @app.get('/api/v1/teams/{team}/audit')
    def audit_log(team:str,session=Depends(authenticated),offset:int=Query(0,ge=0),limit:int=Query(50,ge=1,le=100)):
        with engine.connect() as conn:
            member(conn,team,session['user_id'],write=True)
            return {'items':[dict(row) for row in conn.execute(select(audit).where(audit.c.team_id==team).order_by(audit.c.created.desc(),audit.c.id).offset(offset).limit(limit)).mappings()]}
    return app
