"""Task-scoped immutable evidence; file and task receipt commit atomically."""
import hashlib
import time
import uuid
from fastapi import Depends, Query, Request
from fastapi.responses import Response
from sqlalchemy import select, func, or_, and_
from sqlalchemy.exc import IntegrityError
from .auth import fail
from .database import documents, task_evidence, teams, media, users, record
from .media_types import media_type, valid_evidence_image


def attach_evidence_routes(app, engine, authenticated, member):
    def task(conn, team, document, user):
        membership = member(conn, team, user)
        row = conn.execute(select(documents).where(documents.c.id == document,
            documents.c.team_id == team, documents.c.kind == 'task')).mappings().first()
        if row is None:
            fail('not_found', 404)
        return membership, row

    def read(conn, identifier):
        return dict(conn.execute(select(task_evidence, users.c.name.label('author_name'))
            .join(users, users.c.id == task_evidence.c.author_id)
            .where(task_evidence.c.id == identifier)).mappings().one())

    @app.get('/api/v1/teams/{team}/documents/{document}/evidence')
    def listing(team: str, document: str, session=Depends(authenticated),
                before: str | None = None, limit: int = Query(50, ge=1, le=100)):
        with engine.connect() as conn:
            task(conn, team, document, session['user_id'])
            query = select(task_evidence, users.c.name.label('author_name')).join(
                users, users.c.id == task_evidence.c.author_id).where(
                task_evidence.c.team_id == team, task_evidence.c.document_id == document)
            if before:
                cursor = conn.execute(select(task_evidence).where(task_evidence.c.id == before,
                    task_evidence.c.team_id == team, task_evidence.c.document_id == document)).mappings().first()
                if cursor is None:
                    fail('not_found', 404)
                query = query.where(or_(task_evidence.c.created < cursor['created'],
                    and_(task_evidence.c.created == cursor['created'], task_evidence.c.id < before)))
            rows = list(conn.execute(query.order_by(task_evidence.c.created.desc(),
                task_evidence.c.id.desc()).limit(limit+1)).mappings())
            return {'items': [dict(r) for r in rows[:limit]],
                    'next': rows[limit-1]['id'] if len(rows) > limit else None}

    @app.get('/api/v1/teams/{team}/documents/{document}/evidence/media/{identifier}')
    def download(team: str, document: str, identifier: str, session=Depends(authenticated)):
        with engine.connect() as conn:
            task(conn, team, document, session['user_id'])
            proof = conn.execute(select(task_evidence).where(task_evidence.c.id == identifier,
                task_evidence.c.team_id == team, task_evidence.c.document_id == document)).mappings().first()
            if proof is None:
                fail('not_found', 404)
            blob = conn.execute(select(media).where(media.c.team_id == team,
                media.c.id == proof['media_id'])).mappings().one()
            return Response(content=blob['content'], media_type=blob['mime'])

    @app.put('/api/v1/teams/{team}/documents/{document}/evidence/media/{identifier}')
    async def upload(team: str, document: str, identifier: str, request: Request,
                     session=Depends(authenticated)):
        try:
            if str(uuid.UUID(identifier)) != identifier:
                fail('invalid_media', 422)
        except ValueError:
            fail('invalid_media', 422)
        content = await request.body()
        digest = hashlib.sha256(content).hexdigest()
        mime = media_type(content)
        if mime is None or (mime.startswith('image/') and not valid_evidence_image(content)):
            fail('invalid_media', 422)

        def existing(conn):
            row = conn.execute(select(task_evidence).where(task_evidence.c.id == identifier)).mappings().first()
            if row is None:
                return None
            if (row['team_id'], row['document_id'], row['author_id'], row['media_id']) != (
                    team, document, session['user_id'], digest):
                fail('operation_conflict', 409)
            return read(conn, identifier)
        try:
            with engine.begin() as conn:
                membership, assignment = task(conn, team, document, session['user_id'])
                # Serialize task acceptance/reassignment and the quota transaction.
                assignment = conn.execute(select(documents).where(documents.c.id == document)
                    .with_for_update()).mappings().one()
                previous = existing(conn)
                if previous is not None:
                    return previous
                if membership['role'] == 'viewer' or (
                    membership['role'] == 'player' and assignment['payload'].get('assignee_user_id') != session['user_id']):
                    fail('forbidden', 403)
                if assignment['payload'].get('status') == 'approved':
                    fail('invalid_transition', 409)
                count = conn.execute(select(func.count()).select_from(task_evidence).where(
                    task_evidence.c.document_id == document)).scalar_one()
                if count >= 100:
                    fail('limit', 429)
                conn.execute(select(teams.c.id).where(teams.c.id == team).with_for_update()).first()
                blob = conn.execute(select(media.c.id).where(media.c.team_id == team, media.c.id == digest)).first()
                if blob is None:
                    used = conn.execute(select(func.coalesce(func.sum(media.c.size), 0)).where(media.c.team_id == team)).scalar_one()
                    if used + len(content) > 100*1024*1024:
                        fail('media_quota', 413)
                    conn.execute(media.insert().values(id=digest, team_id=team, content=content, mime=mime, size=len(content)))
                conn.execute(task_evidence.insert().values(id=identifier, team_id=team,
                    document_id=document, author_id=session['user_id'], media_id=digest,
                    mime=mime, size=len(content), task_version=assignment['version'], created=time.time()))
                record(conn, team, session['user_id'], 'task.evidence.created', identifier)
                return read(conn, identifier)
        except IntegrityError:
            with engine.connect() as conn:
                task(conn, team, document, session['user_id'])
                previous = existing(conn)
                if previous is None:
                    fail('operation_conflict', 409)
                return previous
