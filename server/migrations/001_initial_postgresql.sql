-- Initial TeamSync schema v1. New installations only.

CREATE TABLE users (
	id VARCHAR(36) NOT NULL, 
	name VARCHAR(120) NOT NULL, 
	language VARCHAR(2) NOT NULL, 
	PRIMARY KEY (id)
)

;

CREATE TABLE auth_codes (
	code_hash VARCHAR(64) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	challenge VARCHAR(64) NOT NULL, 
	expires FLOAT NOT NULL, 
	PRIMARY KEY (code_hash), 
	FOREIGN KEY(user_id) REFERENCES users (id)
)

;

CREATE TABLE auth_states (
	state_hash VARCHAR(64) NOT NULL, 
	provider VARCHAR(16) NOT NULL, 
	challenge VARCHAR(64) NOT NULL, 
	redirect VARCHAR(300) NOT NULL, 
	link_user VARCHAR(36), 
	expires FLOAT NOT NULL, 
	PRIMARY KEY (state_hash), 
	FOREIGN KEY(link_user) REFERENCES users (id)
)

;

CREATE TABLE external_identities (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	provider VARCHAR(16) NOT NULL, 
	subject VARCHAR(64) NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (provider, subject), 
	UNIQUE (user_id, provider), 
	FOREIGN KEY(user_id) REFERENCES users (id)
)

;

CREATE TABLE sessions (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	token_hash VARCHAR(64) NOT NULL, 
	device VARCHAR(120) NOT NULL, 
	expires FLOAT NOT NULL, 
	created FLOAT NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	UNIQUE (token_hash)
)

;

CREATE TABLE teams (
	id VARCHAR(36) NOT NULL, 
	name VARCHAR(120) NOT NULL, 
	owner_id VARCHAR(36) NOT NULL, 
	created FLOAT NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(owner_id) REFERENCES users (id)
)

;

CREATE TABLE audit_events (
	id VARCHAR(36) NOT NULL, 
	team_id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	action VARCHAR(64) NOT NULL, 
	object_id VARCHAR(36), 
	created FLOAT NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(team_id) REFERENCES teams (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
)

;

CREATE TABLE documents (
	id VARCHAR(36) NOT NULL, 
	team_id VARCHAR(36) NOT NULL, 
	kind VARCHAR(24) NOT NULL, 
	payload JSON NOT NULL, 
	version INTEGER NOT NULL, 
	updated FLOAT NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(team_id) REFERENCES teams (id)
)

;

CREATE TABLE invites (
	id VARCHAR(36) NOT NULL, 
	team_id VARCHAR(36) NOT NULL, 
	code_hash VARCHAR(64) NOT NULL, 
	role VARCHAR(16) NOT NULL, 
	expires FLOAT NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(team_id) REFERENCES teams (id), 
	UNIQUE (code_hash)
)

;

CREATE TABLE memberships (
	id VARCHAR(36) NOT NULL, 
	team_id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	role VARCHAR(16) NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (team_id, user_id), 
	FOREIGN KEY(team_id) REFERENCES teams (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
)

;

CREATE TABLE sync_operations (
	id VARCHAR(36) NOT NULL, 
	team_id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	request_hash VARCHAR(64) NOT NULL, 
	response JSON NOT NULL, 
	created FLOAT NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(team_id) REFERENCES teams (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
)

;

CREATE TABLE document_versions (
	id VARCHAR(36) NOT NULL, 
	document_id VARCHAR(36) NOT NULL, 
	version INTEGER NOT NULL, 
	payload JSON NOT NULL, 
	author_id VARCHAR(36) NOT NULL, 
	created FLOAT NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (document_id, version), 
	FOREIGN KEY(document_id) REFERENCES documents (id), 
	FOREIGN KEY(author_id) REFERENCES users (id)
)

;
CREATE INDEX ix_external_identities_user_id ON external_identities (user_id);
CREATE INDEX ix_sessions_user_id ON sessions (user_id);
CREATE INDEX ix_audit_events_team_id ON audit_events (team_id);
CREATE INDEX ix_documents_team_id ON documents (team_id);
CREATE INDEX ix_invites_team_id ON invites (team_id);
CREATE INDEX ix_memberships_team_id ON memberships (team_id);
CREATE INDEX ix_memberships_user_id ON memberships (user_id);