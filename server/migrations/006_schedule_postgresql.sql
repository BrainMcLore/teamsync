CREATE TABLE IF NOT EXISTS schedule_events (
  id VARCHAR(36) PRIMARY KEY, team_id VARCHAR(36) NOT NULL REFERENCES teams(id),
  payload JSON NOT NULL, starts DOUBLE PRECISION NOT NULL, version INTEGER NOT NULL,
  updated DOUBLE PRECISION NOT NULL, created_by VARCHAR(36) NOT NULL REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS ix_schedule_events_team_starts ON schedule_events(team_id,starts,id);
CREATE TABLE IF NOT EXISTS schedule_participation (
  id VARCHAR(36) PRIMARY KEY, event_id VARCHAR(36) NOT NULL REFERENCES schedule_events(id),
  user_id VARCHAR(36) NOT NULL REFERENCES users(id), payload JSON NOT NULL,
  version INTEGER NOT NULL, updated DOUBLE PRECISION NOT NULL, UNIQUE(event_id,user_id)
);
CREATE TABLE IF NOT EXISTS schedule_history (
  id VARCHAR(36) PRIMARY KEY, event_id VARCHAR(36) NOT NULL REFERENCES schedule_events(id),
  user_id VARCHAR(36) REFERENCES users(id), author_id VARCHAR(36) NOT NULL REFERENCES users(id),
  kind VARCHAR(24) NOT NULL, version INTEGER NOT NULL, payload JSON NOT NULL, created DOUBLE PRECISION NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_schedule_history_event_created ON schedule_history(event_id,created,id);
