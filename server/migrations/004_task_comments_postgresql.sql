CREATE TABLE IF NOT EXISTS task_comments (
  id VARCHAR(36) PRIMARY KEY,
  team_id VARCHAR(36) NOT NULL REFERENCES teams(id),
  document_id VARCHAR(36) NOT NULL REFERENCES documents(id),
  author_id VARCHAR(36) NOT NULL REFERENCES users(id),
  text VARCHAR(5000) NOT NULL,
  created DOUBLE PRECISION NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_task_comments_document_cursor ON task_comments(document_id,created,id);
CREATE INDEX IF NOT EXISTS ix_task_comments_author_created ON task_comments(author_id,created);
