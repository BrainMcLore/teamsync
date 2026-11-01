CREATE TABLE IF NOT EXISTS task_evidence (
  id VARCHAR(36) PRIMARY KEY,
  team_id VARCHAR(36) NOT NULL REFERENCES teams(id),
  document_id VARCHAR(36) NOT NULL REFERENCES documents(id),
  author_id VARCHAR(36) NOT NULL REFERENCES users(id),
  media_id VARCHAR(64) NOT NULL,
  mime VARCHAR(32) NOT NULL,
  size INTEGER NOT NULL,
  task_version INTEGER NOT NULL,
  created DOUBLE PRECISION NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_task_evidence_document_cursor ON task_evidence(document_id,created,id);
