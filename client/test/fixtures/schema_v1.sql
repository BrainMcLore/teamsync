
CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE teams(id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL);
CREATE TABLE members(id TEXT PRIMARY KEY, team_id TEXT NOT NULL REFERENCES teams(id), name TEXT NOT NULL, role TEXT NOT NULL, game_role TEXT NOT NULL);
CREATE INDEX members_team ON members(team_id);
CREATE TABLE maps(id TEXT PRIMARY KEY, team_id TEXT NOT NULL REFERENCES teams(id), name TEXT NOT NULL, image_path TEXT);
CREATE INDEX maps_team ON maps(team_id);
CREATE TABLE strategies(id TEXT PRIMARY KEY, map_id TEXT NOT NULL REFERENCES maps(id), title TEXT NOT NULL, side TEXT NOT NULL CHECK(side IN ('T','CT')), notes TEXT NOT NULL, objects TEXT NOT NULL, version INTEGER NOT NULL, updated_at TEXT NOT NULL);
CREATE INDEX strategies_map ON strategies(map_id);
CREATE TABLE strategy_versions(id TEXT PRIMARY KEY, strategy_id TEXT NOT NULL REFERENCES strategies(id) ON DELETE CASCADE, version INTEGER NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL, UNIQUE(strategy_id,version));
CREATE TABLE tasks(id TEXT PRIMARY KEY, team_id TEXT NOT NULL REFERENCES teams(id), strategy_id TEXT REFERENCES strategies(id), member_id TEXT REFERENCES members(id), title TEXT NOT NULL, notes TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('todo','submitted','approved')), updated_at TEXT NOT NULL);
CREATE INDEX tasks_team ON tasks(team_id);
CREATE TABLE demos(id TEXT PRIMARY KEY, team_id TEXT NOT NULL REFERENCES teams(id), name TEXT NOT NULL, path TEXT NOT NULL, size INTEGER NOT NULL, imported_at TEXT NOT NULL);
CREATE INDEX demos_team ON demos(team_id);
PRAGMA user_version = 1;
