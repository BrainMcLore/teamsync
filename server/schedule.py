"""Fixed UTC events, separate self RSVP/coach attendance and optimistic versions."""
import hashlib
import json
import time
import uuid
from datetime import datetime, timezone
from typing import Literal
from fastapi import Depends, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import select, update, union, and_
from .auth import fail
from .database import (schedule_events as events, schedule_participation as participation,
    schedule_history as history, operations, teams, users, memberships, uid, record)


class Mutation(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    operation_id: str
    expected_version: int = Field(ge=0, le=1000000000)

    @field_validator('operation_id')
    @classmethod
    def identifier(cls, value):
        return str(uuid.UUID(value))


class EventWrite(Mutation):
    title: str = Field(min_length=1, max_length=120)
    notes: str = Field(default='', max_length=5000)
    location: str = Field(default='', max_length=200)
    kind: Literal['practice', 'scrim', 'review', 'bootcamp'] = 'practice'
    starts_at: datetime
    ends_at: datetime
    status: Literal['scheduled', 'cancelled'] = 'scheduled'
    reason: str = Field(default='', max_length=2000)

    @field_validator('starts_at', 'ends_at')
    @classmethod
    def aware(cls, value):
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError('timezone_required')
        value = value.astimezone(timezone.utc)
        if not 2000 <= value.year <= 2200:
            raise ValueError('invalid_time')
        return value

    @model_validator(mode='after')
    def interval(self):
        seconds = (self.ends_at-self.starts_at).total_seconds()
        if not 60 <= seconds <= 7*86400 or self.status == 'cancelled' and not self.reason:
            raise ValueError('invalid_interval_or_cancellation_reason')
        return self


class ParticipationWrite(Mutation):
    rsvp: Literal['going', 'maybe', 'declined', 'unknown'] | None = None
    attendance: Literal['unmarked', 'present', 'late', 'absent', 'excused'] | None = None
    reason: str = Field(default='', max_length=2000)

    @model_validator(mode='after')
    def single_action(self):
        if (self.rsvp is None) == (self.attendance is None):
            raise ValueError('one_action_required')
        if self.rsvp is not None and self.reason:
            raise ValueError('attendance_reason_only')
        return self


def attach_schedule_routes(app, engine, authenticated, member):
    def event(conn, team, identifier):
        value = conn.execute(select(events).where(events.c.id == identifier, events.c.team_id == team)).mappings().first()
        if value is None:
            fail('not_found', 404)
        return value

    def response(row):
        return {k: v for k, v in dict(row).items() if k not in ('payload', 'starts')} | row['payload']

    def start(conn, team, session, path, body, manager=False):
        # Same lock order as existing team mutation routes.
        conn.execute(select(teams.c.id).where(teams.c.id == team).with_for_update()).first()
        caller = member(conn, team, session['user_id'], write=manager)
        request_hash = hashlib.sha256(json.dumps([path, body.model_dump(mode='json')], sort_keys=True).encode()).hexdigest()
        previous = conn.execute(select(operations).where(operations.c.id == body.operation_id)).mappings().first()
        if previous and (previous['team_id'], previous['user_id'], previous['request_hash']) != (team, session['user_id'], request_hash):
            fail('operation_conflict', 409)
        return caller, request_hash, previous['response'] if previous else None

    def finish(conn, team, session, body, request_hash, result, identifier, target=None):
        timestamp = time.time()
        conn.execute(operations.insert().values(id=body.operation_id, team_id=team, user_id=session['user_id'],
            request_hash=request_hash, response=result, created=timestamp))
        conn.execute(history.insert().values(id=uid(), event_id=identifier, user_id=target,
            author_id=session['user_id'], kind='event' if target is None else ('rsvp' if body.rsvp is not None else 'attendance'),
            version=result['version'], payload=result, created=timestamp))
        record(conn, team, session['user_id'], 'schedule.saved' if target is None else 'schedule.participation', identifier)
        return result

    @app.get('/api/v1/teams/{team}/events')
    def listing(team: str, from_at: datetime, until_at: datetime, session=Depends(authenticated),
                offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100)):
        if from_at.tzinfo is None or until_at.tzinfo is None or not 0 < (until_at-from_at).total_seconds() <= 366*86400:
            fail('invalid_time_range', 422)
        with engine.connect() as conn:
            member(conn, team, session['user_id'])
            rows = list(conn.execute(select(events).where(events.c.team_id == team,
                events.c.starts >= from_at.timestamp(), events.c.starts < until_at.timestamp())
                .order_by(events.c.starts, events.c.id).offset(offset).limit(limit+1)).mappings())
            return {'items': [response(r) for r in rows[:limit]], 'next': offset+limit if len(rows) > limit else None}

    @app.post('/api/v1/teams/{team}/events/{identifier}')
    def save_event(team: str, identifier: str, body: EventWrite, session=Depends(authenticated)):
        try:
            if str(uuid.UUID(identifier)) != identifier:
                fail('invalid_link', 422)
        except ValueError:
            fail('invalid_link', 422)
        with engine.begin() as conn:
            _, request_hash, previous = start(conn, team, session, f'event/{identifier}', body, manager=True)
            if previous is not None:
                return previous
            current = conn.execute(select(events).where(events.c.id == identifier)).mappings().first()
            if current and current['team_id'] != team:
                fail('not_found', 404)
            if (current['version'] if current else 0) != body.expected_version:
                fail('version_conflict', 409)
            payload = body.model_dump(mode='json', exclude={'operation_id', 'expected_version'})
            if current and any(current['payload'][key] != payload[key] for key in ('starts_at', 'ends_at')):
                # Times of already recorded sessions must not be silently reinterpreted.
                if any(r['payload'].get('attendance', 'unmarked') != 'unmarked' for r in conn.execute(
                        select(participation).where(participation.c.event_id == identifier)).mappings()):
                    fail('attendance_time_locked', 409)
            if current:
                conn.execute(update(events).where(events.c.id == identifier).values(payload=payload,
                    starts=body.starts_at.timestamp(), version=body.expected_version+1, updated=time.time()))
            else:
                conn.execute(events.insert().values(id=identifier, team_id=team, payload=payload,
                    starts=body.starts_at.timestamp(), version=1, updated=time.time(), created_by=session['user_id']))
            result = response(event(conn, team, identifier))
            return finish(conn, team, session, body, request_hash, result, identifier)

    @app.post('/api/v1/teams/{team}/events/{identifier}/participation/{target}')
    def save_participation(team: str, identifier: str, target: str, body: ParticipationWrite, session=Depends(authenticated)):
        with engine.begin() as conn:
            caller, request_hash, previous = start(conn, team, session, f'participation/{identifier}/{target}', body)
            current_event = event(conn, team, identifier)
            if previous is not None:
                return previous
            manager = caller['role'] in ('owner', 'captain', 'coach')
            if caller['role'] == 'viewer' or (body.rsvp is not None and target != session['user_id']) or (body.attendance is not None and not manager):
                fail('forbidden', 403)
            member(conn, team, target)
            if current_event['payload']['status'] == 'cancelled':
                fail('event_cancelled', 409)
            current = conn.execute(select(participation).where(participation.c.event_id == identifier,
                participation.c.user_id == target)).mappings().first()
            if (current['version'] if current else 0) != body.expected_version:
                fail('version_conflict', 409)
            payload = dict(current['payload']) if current else {'rsvp': 'unknown', 'attendance': 'unmarked', 'reason': '', 'recorded_by': None, 'recorded_at': None}
            if body.rsvp is not None:
                payload['rsvp'] = body.rsvp
            else:
                if body.attendance not in ('unmarked', 'excused') and current_event['starts'] > time.time():
                    fail('event_not_started', 409)
                if payload['attendance'] != 'unmarked' and payload['attendance'] != body.attendance and not body.reason:
                    fail('attendance_reason_required', 422)
                payload.update(attendance=body.attendance, reason=body.reason,
                    recorded_by=session['user_id'], recorded_at=time.time())
            fields = {'payload': payload, 'version': body.expected_version+1, 'updated': time.time()}
            row_id = current['id'] if current else uid()
            if current:
                conn.execute(update(participation).where(participation.c.id == row_id).values(**fields))
            else:
                conn.execute(participation.insert().values(id=row_id, event_id=identifier, user_id=target, **fields))
            result = response(conn.execute(select(participation).where(participation.c.id == row_id)).mappings().one())
            return finish(conn, team, session, body, request_hash, result, identifier, target)

    @app.get('/api/v1/teams/{team}/events/{identifier}/participation')
    def roster(team: str, identifier: str, session=Depends(authenticated), offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100)):
        with engine.connect() as conn:
            member(conn, team, session['user_id'])
            current_event = event(conn, team, identifier)
            candidates = union(select(memberships.c.user_id).where(memberships.c.team_id == team),
                select(participation.c.user_id).where(participation.c.event_id == identifier)).subquery()
            reviewer = users.alias('reviewer')
            query = select(users.c.id.label('user_id'), users.c.name, memberships.c.role,
                participation.c.payload, participation.c.version, participation.c.updated,
                reviewer.c.name.label('recorded_by_name')).select_from(users.join(candidates, candidates.c.user_id == users.c.id)
                .outerjoin(memberships, and_(memberships.c.user_id == users.c.id, memberships.c.team_id == team))
                .outerjoin(participation, and_(participation.c.user_id == users.c.id, participation.c.event_id == identifier)))
            # Author display lookup is applied after the bounded roster query.
            query = query.outerjoin(reviewer, reviewer.c.id == participation.c.payload['recorded_by'].as_string())
            rows = list(conn.execute(query.order_by(users.c.id).offset(offset).limit(limit+1)).mappings())
            items = []
            for row in rows[:limit]:
                data = dict(row)
                payload = data.pop('payload') or {'rsvp': 'unknown', 'attendance': 'unmarked', 'reason': '', 'recorded_by': None, 'recorded_at': None}
                data.update(payload)
                data['version'] = data['version'] or 0
                data['active'] = data['role'] is not None
                items.append(data)
            return {'event': response(current_event), 'items': items, 'next': offset+limit if len(rows) > limit else None}

    @app.get('/api/v1/teams/{team}/events/{identifier}/history')
    def history_list(team: str, identifier: str, session=Depends(authenticated), offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100)):
        with engine.connect() as conn:
            member(conn, team, session['user_id'])
            event(conn, team, identifier)
            target = users.alias('target')
            rows = conn.execute(select(history, users.c.name.label('author_name'), target.c.name.label('target_name'))
                .join(users, users.c.id == history.c.author_id).outerjoin(target, target.c.id == history.c.user_id)
                .where(history.c.event_id == identifier).order_by(history.c.created.desc(), history.c.id.desc())
                .offset(offset).limit(limit)).mappings()
            return {'items': [dict(row) for row in rows]}
