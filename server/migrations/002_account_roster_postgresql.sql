-- Additive migration. Existing identities, teams and materials are preserved.
CREATE TABLE IF NOT EXISTS account_invites (
  id VARCHAR(36) PRIMARY KEY,
  team_id VARCHAR(36) NOT NULL REFERENCES teams(id),
  sender_id VARCHAR(36) NOT NULL REFERENCES users(id),
  recipient_id VARCHAR(36) NOT NULL REFERENCES users(id),
  role VARCHAR(16) NOT NULL,
  expires DOUBLE PRECISION NOT NULL,
  created DOUBLE PRECISION NOT NULL,
  UNIQUE(team_id,recipient_id)
);
CREATE INDEX IF NOT EXISTS ix_account_invites_team_id ON account_invites(team_id);
CREATE INDEX IF NOT EXISTS ix_account_invites_recipient_id ON account_invites(recipient_id);
CREATE TABLE IF NOT EXISTS roster_details (
  membership_id VARCHAR(36) PRIMARY KEY REFERENCES memberships(id) ON DELETE CASCADE,
  game_role VARCHAR(40) NOT NULL DEFAULT '',
  squad VARCHAR(16) NOT NULL DEFAULT 'main'
);
