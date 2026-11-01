"""Append-only task discussion, retry-safe IDs and stable cursor pagination."""
import time
import uuid
from fastapi import Depends, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select, or_, and_, func
from sqlalchemy.exc import IntegrityError
from .auth import fail
from .database import documents, task_comments, users, record


class CommentWrite(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    id: str
    text: str = Field(min_length=1, max_length=5000)

    @field_validator('id')
    @classmethod
    def valid_id(cls, value):
        return str(uuid.UUID(value))


def attach_discussion_routes(app, engine, authenticated, member):
    def task(conn, team, document, user):
        membership = member(conn, team, user)
        if not conn.execute(select(documents.c.id).where(
                documents.c.id == document, documents.c.team_id == team,
                documents.c.kind == 'task')).first():
            fail('not_found', 404)
        return membership

    def read(conn, comment):
        return dict(conn.execute(select(task_comments, users.c.name.label('author_name'))
            .join(users, users.c.id == task_comments.c.author_id)
            .where(task_comments.c.id == comment)).mappings().one())

    @app.get('/api/v1/teams/{team}/documents/{document}/comments')
    def comments(team: str, document: str, session=Depends(authenticated),
                 before: str | None = None, limit: int = Query(50, ge=1, le=100)):
        with engine.connect() as conn:
            task(conn, team, document, session['user_id'])
            query = select(task_comments, users.c.name.label('author_name')).join(
                users, users.c.id == task_comments.c.author_id).where(
                task_comments.c.document_id == document, task_comments.c.team_id == team)
            if before is not None:
                cursor = conn.execute(select(task_comments).where(
                    task_comments.c.id == before, task_comments.c.document_id == document,
                    task_comments.c.team_id == team)).mappings().first()
                if cursor is None:
                    fail('not_found', 404)
                query = query.where(or_(task_comments.c.created < cursor['created'],
                    and_(task_comments.c.created == cursor['created'], task_comments.c.id < before)))
            rows = list(conn.execute(query.order_by(task_comments.c.created.desc(),
                task_comments.c.id.desc()).limit(limit + 1)).mappings())
            return {'items': [dict(r) for r in rows[:limit]],
                    'next': rows[limit-1]['id'] if len(rows) > limit else None}

    @app.post('/api/v1/teams/{team}/documents/{document}/comments')
    def post_comment(team: str, document: str, body: CommentWrite, session=Depends(authenticated)):
        def existing(conn):
            row = conn.execute(select(task_comments).where(task_comments.c.id == body.id)).mappings().first()
            if row is None:
                return None
            if (row['team_id'], row['document_id'], row['author_id'], row['text']) != (
                    team, document, session['user_id'], body.text):
                fail('operation_conflict', 409)
            return read(conn, body.id)
        try:
            with engine.begin() as conn:
                membership = task(conn, team, document, session['user_id'])
                if membership['role'] == 'viewer':
                    fail('forbidden', 403)
                previous = existing(conn)
                if previous is not None:
                    return previous
                count = conn.execute(select(func.count()).select_from(task_comments).where(
                    task_comments.c.document_id == document)).scalar_one()
                daily = conn.execute(select(func.count()).select_from(task_comments).where(
                    task_comments.c.author_id == session['user_id'],
                    task_comments.c.created > time.time()-86400)).scalar_one()
                if count >= 10000 or daily >= 1000:
                    fail('limit', 429)
                conn.execute(task_comments.insert().values(id=body.id, team_id=team,
                    document_id=document, author_id=session['user_id'], text=body.text, created=time.time()))
                record(conn, team, session['user_id'], 'task.comment.created', body.id)
                return read(conn, body.id)
        except IntegrityError:
            # Concurrent retries race on the immutable primary key.
            with engine.connect() as conn:
                task(conn, team, document, session['user_id'])
                previous = existing(conn)
                if previous is None:
                    fail('operation_conflict', 409)
                return previous
