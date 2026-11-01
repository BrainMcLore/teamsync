"""Account-bound skill verification with explicit material rechecks."""
import base64
import hashlib
import json
import time
import uuid
from typing import Literal

from fastapi import Depends, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select, update

from .auth import fail
from .database import (documents, teams, operations, utility_progress,
                       utility_progress_versions, users, uid, record)


class SkillWrite(BaseModel):
    model_config=ConfigDict(extra='forbid',str_strip_whitespace=True)
    operation_id: str
    target_user_id: str | None = None
    revision: int = Field(ge=1,le=1000000000)
    expected_version: int = Field(ge=0)
    status: Literal['not_started','learning','ready','confirmed']
    reason: str = Field(default='',max_length=2000)

    @field_validator('operation_id','target_user_id')
    @classmethod
    def valid_uuid(cls,value):
        return None if value is None else str(uuid.UUID(value))


def attach_skill_routes(app,engine,authenticated,member):
    @app.get('/api/v1/teams/{team}/utility-progress')
    def list_progress(team:str,session=Depends(authenticated),offset:int=Query(0,ge=0),limit:int=Query(100,ge=1,le=100)):
        with engine.connect() as conn:
            member(conn,team,session['user_id'])
            rows=conn.execute(select(utility_progress).where(utility_progress.c.team_id==team)
                              .order_by(utility_progress.c.id).offset(offset).limit(limit)).mappings()
            return {'items':[dict(row) for row in rows]}

    @app.post('/api/v1/teams/{team}/utilities/{document}/progress')
    def write_progress(team:str,document:str,body:SkillWrite,session=Depends(authenticated)):
        target=body.target_user_id or session['user_id']
        value={**body.model_dump(mode='json',exclude_unset=True),'target_user_id':target,
               'team':team,'document':document}
        request_hash='p1:'+base64.urlsafe_b64encode(hashlib.sha256(json.dumps(value,sort_keys=True,
            ensure_ascii=False,separators=(',',':')).encode()).digest()).decode().rstrip('=')
        with engine.begin() as conn:
            conn.execute(select(teams.c.id).where(teams.c.id==team).with_for_update()).first()
            caller=member(conn,team,session['user_id'])
            manager=caller['role'] in ('owner','captain','coach')
            if caller['role']=='viewer' or (not manager and (target!=session['user_id'] or body.status=='confirmed')):
                fail('forbidden',403)
            member(conn,team,target)
            previous=conn.execute(select(operations).where(operations.c.id==body.operation_id)).mappings().first()
            if previous:
                if previous['team_id']!=team or previous['user_id']!=session['user_id'] or previous['request_hash']!=request_hash:
                    fail('operation_conflict',409)
                return previous['response']
            material=conn.execute(select(documents).where(documents.c.id==document,
                documents.c.team_id==team,documents.c.kind=='utility')).mappings().first()
            if not material:fail('not_found',404)
            revision=(material['payload'].get('utility') or {}).get('training_revision',1)
            if body.revision!=revision:fail('progress_revision_changed',409)
            current=conn.execute(select(utility_progress).where(utility_progress.c.team_id==team,
                utility_progress.c.document_id==document,utility_progress.c.user_id==target,
                utility_progress.c.revision==revision).with_for_update()).mappings().first()
            if (current['version'] if current else 0)!=body.expected_version:fail('version_conflict',409)
            if body.status=='confirmed' and (not current or current['status']!='ready'):
                fail('invalid_transition',422)
            if target!=session['user_id'] and current and current['status'] in ('ready','confirmed') and body.status!='confirmed' and not body.reason:
                fail('review_reason_required',422)
            identifier=current['id'] if current else uid()
            version=body.expected_version+1
            changed=time.time()
            fields={'status':body.status,'reason':body.reason,'version':version,'updated':changed,
                    'reviewed_by':session['user_id'] if body.status=='confirmed' else None}
            if current:
                conn.execute(update(utility_progress).where(utility_progress.c.id==identifier).values(**fields))
            else:
                conn.execute(utility_progress.insert().values(id=identifier,team_id=team,document_id=document,
                    user_id=target,revision=revision,**fields))
            conn.execute(utility_progress_versions.insert().values(id=uid(),progress_id=identifier,
                version=version,status=body.status,reason=body.reason,author_id=session['user_id'],updated=changed))
            response={'id':identifier,'team_id':team,'document_id':document,'user_id':target,
                      'revision':revision,**fields}
            conn.execute(operations.insert().values(id=body.operation_id,team_id=team,user_id=session['user_id'],
                request_hash=request_hash,response=response,created=changed))
            record(conn,team,session['user_id'],'utility.progress',document)
            return response

    @app.get('/api/v1/teams/{team}/utility-progress/{progress}/versions')
    def progress_history(team:str,progress:str,session=Depends(authenticated),offset:int=Query(0,ge=0),limit:int=Query(50,ge=1,le=100)):
        with engine.connect() as conn:
            member(conn,team,session['user_id'])
            if not conn.execute(select(utility_progress.c.id).where(utility_progress.c.id==progress,
                utility_progress.c.team_id==team)).first():fail('not_found',404)
            rows=conn.execute(select(utility_progress_versions,users.c.name.label('author_name')).join(users,users.c.id==utility_progress_versions.c.author_id).where(utility_progress_versions.c.progress_id==progress)
                .order_by(utility_progress_versions.c.version.desc()).offset(offset).limit(limit)).mappings()
            return {'items':[dict(row) for row in rows]}
