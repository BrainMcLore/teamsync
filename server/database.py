import time
import uuid

from sqlalchemy import (MetaData, Table, Column, String, Integer, Float, JSON,
                        ForeignKey, UniqueConstraint, create_engine, event, LargeBinary)

metadata = MetaData()
users = Table('users', metadata,
    Column('id', String(36), primary_key=True), Column('name', String(120), nullable=False),
    Column('language', String(2), nullable=False, default='ru'))
identities = Table('external_identities', metadata,
    Column('id', String(36), primary_key=True),
    Column('user_id', ForeignKey('users.id'), nullable=False, index=True),
    Column('provider', String(16), nullable=False), Column('subject', String(64), nullable=False),
    UniqueConstraint('provider', 'subject'), UniqueConstraint('user_id', 'provider'))
sessions = Table('sessions', metadata,
    Column('id', String(36), primary_key=True), Column('user_id', ForeignKey('users.id'), nullable=False, index=True),
    Column('token_hash', String(64), nullable=False, unique=True), Column('device', String(120), nullable=False),
    Column('expires', Float, nullable=False), Column('created', Float, nullable=False))
auth_states = Table('auth_states', metadata,
    Column('state_hash', String(64), primary_key=True), Column('provider', String(16), nullable=False),
    Column('challenge', String(64), nullable=False), Column('redirect', String(300), nullable=False),
    Column('link_user', ForeignKey('users.id')), Column('expires', Float, nullable=False))
auth_codes = Table('auth_codes', metadata,
    Column('code_hash', String(64), primary_key=True), Column('user_id', ForeignKey('users.id'), nullable=False),
    Column('challenge', String(64), nullable=False), Column('expires', Float, nullable=False))
teams = Table('teams', metadata,
    Column('id', String(36), primary_key=True), Column('name', String(120), nullable=False),
    Column('owner_id', ForeignKey('users.id'), nullable=False), Column('created', Float, nullable=False))
memberships = Table('memberships', metadata,
    Column('id', String(36), primary_key=True), Column('team_id', ForeignKey('teams.id'), nullable=False, index=True),
    Column('user_id', ForeignKey('users.id'), nullable=False, index=True),
    Column('role', String(16), nullable=False), UniqueConstraint('team_id', 'user_id'))
invites = Table('invites', metadata,
    Column('id', String(36), primary_key=True), Column('team_id', ForeignKey('teams.id'), nullable=False, index=True),
    Column('code_hash', String(64), nullable=False, unique=True), Column('role', String(16), nullable=False),
    Column('expires', Float, nullable=False))
account_invites = Table('account_invites', metadata,
    Column('id', String(36), primary_key=True),
    Column('team_id', ForeignKey('teams.id'), nullable=False, index=True),
    Column('sender_id', ForeignKey('users.id'), nullable=False),
    Column('recipient_id', ForeignKey('users.id'), nullable=False, index=True),
    Column('role', String(16), nullable=False),
    Column('expires', Float, nullable=False), Column('created', Float, nullable=False),
    UniqueConstraint('team_id', 'recipient_id'))
roster_details = Table('roster_details', metadata,
    Column('membership_id', ForeignKey('memberships.id', ondelete='CASCADE'), primary_key=True),
    Column('game_role', String(40), nullable=False, default=''),
    Column('squad', String(16), nullable=False, default='main'))
documents = Table('documents', metadata,
    Column('id', String(36), primary_key=True), Column('team_id', ForeignKey('teams.id'), nullable=False, index=True),
    Column('kind', String(24), nullable=False), Column('payload', JSON, nullable=False),
    Column('version', Integer, nullable=False), Column('updated', Float, nullable=False))
media = Table('team_media',metadata,
    Column('id',String(64),primary_key=True),Column('team_id',ForeignKey('teams.id'),primary_key=True),
    Column('content',LargeBinary,nullable=False),Column('mime',String(32),nullable=False),
    Column('size',Integer,nullable=False))
document_versions = Table('document_versions', metadata,
    Column('id', String(36), primary_key=True), Column('document_id', ForeignKey('documents.id'), nullable=False),
    Column('version', Integer, nullable=False), Column('payload', JSON, nullable=False),
    Column('author_id', ForeignKey('users.id'), nullable=False), Column('created', Float, nullable=False),
    UniqueConstraint('document_id','version'))
operations = Table('sync_operations', metadata,
    Column('id', String(36), primary_key=True), Column('team_id', ForeignKey('teams.id'), nullable=False),
    Column('user_id', ForeignKey('users.id'), nullable=False), Column('request_hash', String(64), nullable=False),
    Column('response', JSON, nullable=False), Column('created', Float, nullable=False))
audit = Table('audit_events', metadata,
    Column('id', String(36), primary_key=True), Column('team_id', ForeignKey('teams.id'), nullable=False, index=True),
    Column('user_id', ForeignKey('users.id'), nullable=False), Column('action', String(64), nullable=False),
    Column('object_id', String(36)), Column('created', Float, nullable=False))

utility_progress = Table('utility_progress', metadata,
    Column('id', String(36), primary_key=True),
    Column('team_id', ForeignKey('teams.id'), nullable=False, index=True),
    Column('document_id', ForeignKey('documents.id'), nullable=False),
    Column('user_id', ForeignKey('users.id'), nullable=False),
    Column('revision', Integer, nullable=False), Column('version', Integer, nullable=False),
    Column('status', String(20), nullable=False), Column('reason', String(2000), nullable=False),
    Column('reviewed_by', ForeignKey('users.id')), Column('updated', Float, nullable=False),
    UniqueConstraint('team_id','document_id','user_id','revision'))
utility_progress_versions = Table('utility_progress_versions', metadata,
    Column('id', String(36), primary_key=True),
    Column('progress_id', ForeignKey('utility_progress.id'), nullable=False),
    Column('version', Integer, nullable=False), Column('status', String(20), nullable=False),
    Column('reason', String(2000), nullable=False), Column('author_id', ForeignKey('users.id'), nullable=False),
    Column('updated', Float, nullable=False), UniqueConstraint('progress_id','version'))

def uid():
    return str(uuid.uuid4())

def open_database(url):
    if url.startswith(('postgres://','postgresql://')):
        url='postgresql+psycopg://'+url.split('://',1)[1]
    engine = create_engine(url, connect_args={'check_same_thread': False} if url.startswith('sqlite') else {}, pool_pre_ping=True)
    if url.startswith('sqlite'):
        @event.listens_for(engine, 'connect')
        def foreign_keys(connection, _):
            connection.execute('PRAGMA foreign_keys=ON')
    # Bootstrap migration v1. Future revisions must be explicit migrations.
    metadata.create_all(engine)
    return engine

def record(conn, team, user, action, object_id=None):
    conn.execute(audit.insert().values(id=uid(), team_id=team, user_id=user, action=action, object_id=object_id, created=time.time()))
