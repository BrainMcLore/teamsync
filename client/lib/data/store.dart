import 'dart:convert';
import 'dart:async';

import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

typedef RecordData = Map<String, Object?>;

class DomainError implements Exception {
  final String code;
  DomainError(this.code);
}

class Store {
  final _tacticalUpdates = StreamController<String>.broadcast(sync: true);
  Stream<String> get tacticalUpdates => _tacticalUpdates.stream;
  void notifyRemoteTactical(String id) => _tacticalUpdates.add(id);
  final Set<String> editingStrategies = {};
  void Function()? onTacticalChange;
  void Function()? onTeamChange;
  bool applyingSync = false;
  final editingUtilities = <String>{};
  bool canEditTeam(String team) =>
      applyingSync ||
      !['player', 'viewer'].contains(setting('shared_role_$team'));
  void assertStrategyEdit(String map) {
    final team =
        rows('SELECT team_id FROM maps WHERE id=?', [map]).single['team_id']
            as String;
    if (!canEditTeam(team)) throw DomainError('readOnlyTeam');
  }

  final Database db;
  static const uuid = Uuid();
  Store(String path) : db = sqlite3.open(path) {
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA journal_mode = WAL');
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version > 0 && version < 7 && path != ':memory:') {
      final backup =
          '$path.pre-v7-${DateTime.now().toUtc().millisecondsSinceEpoch}.sqlite';
      db.execute("VACUUM INTO '${backup.replaceAll("'", "''")}'");
    }
    if (version > 7) {
      db.close();
      throw DomainError('newerDatabase');
    }
    if (version == 0) {
      transaction(() {
        db.execute('''
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
''');
      });
    }
    if (version < 2) {
      transaction(() {
        db.execute('''
ALTER TABLE maps ADD COLUMN catalog_id TEXT;
ALTER TABLE maps ADD COLUMN lower_image_path TEXT;
ALTER TABLE demos ADD COLUMN source_page TEXT;
ALTER TABLE demos ADD COLUMN analysis_path TEXT;
ALTER TABLE demos ADD COLUMN map_key TEXT;
ALTER TABLE demos ADD COLUMN sha256 TEXT;
ALTER TABLE demos ADD COLUMN match_id TEXT;
ALTER TABLE demos ADD COLUMN participants TEXT;
ALTER TABLE strategies ADD COLUMN level TEXT NOT NULL DEFAULT 'default';
CREATE TABLE demo_annotations(id TEXT PRIMARY KEY,demo_id TEXT NOT NULL REFERENCES demos(id),tick INTEGER NOT NULL,round INTEGER NOT NULL,note TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE INDEX annotation_demo ON demo_annotations(demo_id,tick);
PRAGMA user_version=2;
''');
      });
    }
    if (version < 3) {
      transaction(() {
        db.execute(
          'ALTER TABLE demos ADD COLUMN scouting TEXT NOT NULL DEFAULT \'{}\'',
        );
        db.execute('PRAGMA user_version=3');
      });
    }
    if (version < 4) {
      transaction(() {
        db.execute("""
CREATE TABLE utilities(id TEXT PRIMARY KEY, team_id TEXT NOT NULL REFERENCES teams(id), map_id TEXT NOT NULL REFERENCES maps(id), title TEXT NOT NULL, side TEXT NOT NULL CHECK(side IN ('T','CT')), notes TEXT NOT NULL, details TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE INDEX utilities_team_map ON utilities(team_id,map_id);
PRAGMA user_version=4;
""");
      });
    }
    if (version < 5) {
      transaction(() {
        db.execute("""
CREATE TABLE utility_progress_cache(team_id TEXT NOT NULL REFERENCES teams(id),document_id TEXT NOT NULL,user_id TEXT NOT NULL,revision INTEGER NOT NULL,remote TEXT NOT NULL,desired TEXT,pending TEXT,conflict INTEGER NOT NULL DEFAULT 0,archived INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(team_id,document_id,user_id,revision));
CREATE INDEX utility_progress_pending ON utility_progress_cache(team_id,archived);
PRAGMA user_version=5;
""");
      });
    }
    if (version < 6) {
      transaction(() {
        db.execute("""
CREATE TABLE tasks_v6(id TEXT PRIMARY KEY,team_id TEXT NOT NULL REFERENCES teams(id),strategy_id TEXT REFERENCES strategies(id),member_id TEXT REFERENCES members(id),title TEXT NOT NULL,notes TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('todo','in_progress','submitted','approved')),updated_at TEXT NOT NULL,review_reason TEXT NOT NULL DEFAULT '');
INSERT INTO tasks_v6 SELECT *,'' FROM tasks;
DROP TABLE tasks;
ALTER TABLE tasks_v6 RENAME TO tasks;
CREATE INDEX tasks_team ON tasks(team_id);
PRAGMA user_version=6;
""");
      });
    }
    if (version < 7) {
      transaction(() {
        db.execute("""
ALTER TABLE tasks ADD COLUMN task_type TEXT NOT NULL DEFAULT 'general';
ALTER TABLE tasks ADD COLUMN due_at TEXT;
ALTER TABLE tasks ADD COLUMN criteria TEXT NOT NULL DEFAULT '';
PRAGMA user_version=7;
""");
      });
    }
  }

  T transaction<T>(T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final value = action();
      db.execute('COMMIT');
      return value;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<RecordData> rows(String sql, [List<Object?> args = const []]) =>
      db.select(sql, args).map((r) => Map<String, Object?>.from(r)).toList();
  String? setting(String key) =>
      rows('SELECT value FROM settings WHERE key=?', [
            key,
          ]).firstOrNull?['value']
          as String?;
  void setSetting(String key, String value) => db.execute(
    'INSERT INTO settings VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, value],
  );
  String get now => DateTime.now().toUtc().toIso8601String();
  String requiredText(String value, [int max = 120]) {
    final text = value.trim();
    if (text.isEmpty || text.length > max) throw DomainError('invalidText');
    return text;
  }

  List<RecordData> get teams => rows('SELECT * FROM teams ORDER BY created_at');
  String createTeam(String name) {
    final id = uuid.v4();
    db.execute('INSERT INTO teams(id,name,created_at) VALUES(?,?,?)', [
      id,
      requiredText(name),
      now,
    ]);
    return id;
  }

  List<RecordData> members(String team) =>
      rows('SELECT * FROM members WHERE team_id=? ORDER BY name', [team]);
  String addMember(String team, String name, String role, String gameRole) {
    if (!['owner', 'captain', 'coach', 'player', 'viewer'].contains(role)) {
      throw DomainError('invalidRole');
    }
    final id = uuid.v4();
    db.execute('INSERT INTO members VALUES(?,?,?,?,?)', [
      id,
      team,
      requiredText(name),
      role,
      requiredText(gameRole, 40),
    ]);
    return id;
  }

  List<RecordData> maps(String team) =>
      rows('SELECT * FROM maps WHERE team_id=? ORDER BY name', [team]);
  String addMap(String team, String name) {
    final id = uuid.v4();
    db.execute('INSERT INTO maps(id,team_id,name) VALUES(?,?,?)', [
      id,
      team,
      requiredText(name),
    ]);
    return id;
  }

  void mapImage(String map, String path) =>
      db.execute('UPDATE maps SET image_path=? WHERE id=?', [path, map]);
  List<RecordData> strategies(String team) => rows(
    "SELECT s.*,m.name AS map_name,m.catalog_id AS map_key,m.image_path AS primary_image_path,m.lower_image_path,CASE WHEN s.level='lower' THEN COALESCE(m.lower_image_path,m.image_path) ELSE m.image_path END AS image_path FROM strategies s JOIN maps m ON m.id=s.map_id WHERE m.team_id=? ORDER BY s.updated_at DESC",
    [team],
  );
  RecordData strategy(String id) => rows(
    "SELECT s.*,m.name AS map_name,m.catalog_id AS map_key,m.image_path AS primary_image_path,m.lower_image_path,CASE WHEN s.level='lower' THEN COALESCE(m.lower_image_path,m.image_path) ELSE m.image_path END AS image_path FROM strategies s JOIN maps m ON m.id=s.map_id WHERE s.id=?",
    [id],
  ).single;
  String createStrategy(
    String map,
    String title,
    String side, {
    String level = 'default',
  }) {
    assertStrategyEdit(map);
    if (!['T', 'CT'].contains(side)) throw DomainError('invalidSide');
    if (!['default', 'lower'].contains(level)) {
      throw DomainError('invalidLevel');
    }
    final id = uuid.v4();
    transaction(() {
      db.execute(
        'INSERT INTO strategies(id,map_id,title,side,notes,objects,version,updated_at,level) VALUES(?,?,?,?,?,?,?,?,?)',
        [id, map, requiredText(title), side, '', '[]', 1, now, level],
      );
      _snapshot(id);
    });
    if (!applyingSync) onTacticalChange?.call();
    return id;
  }

  void _snapshot(String id) {
    final snapshot = rows('SELECT * FROM strategies WHERE id=?', [id]).single;
    db.execute('INSERT INTO strategy_versions VALUES(?,?,?,?,?)', [
      uuid.v4(),
      id,
      snapshot['version'],
      jsonEncode(snapshot),
      now,
    ]);
  }

  void saveStrategy(
    String id,
    String notes,
    List<Map<String, dynamic>> objects,
    int expectedVersion, {
    String? level,
  }) {
    assertStrategyEdit(strategy(id)['map_id'] as String);
    if (level != null && !['default', 'lower'].contains(level)) {
      throw DomainError('invalidLevel');
    }
    validateStrategy(notes, objects);
    transaction(() {
      final current = strategy(id);
      if (current['version'] != expectedVersion) throw DomainError('conflict');
      db.execute(
        'UPDATE strategies SET notes=?,objects=?,version=version+1,updated_at=?,level=COALESCE(?,level) WHERE id=?',
        [notes, jsonEncode(objects), now, level, id],
      );
      _snapshot(id);
    });
    if (!applyingSync) onTacticalChange?.call();
  }

  void validateStrategy(String notes, List<Map<String, dynamic>> objects) {
    if (notes.length > 20000 || objects.length > 2000) {
      throw DomainError('limit');
    }
    for (final object in objects) {
      if (![
        'marker',
        't',
        'ct',
        'smoke',
        'flash',
        'molotov',
        'arrow',
      ].contains(object['type'])) {
        throw DomainError('invalidObject');
      }
      for (final coordinate in [
        'x',
        'y',
        if (object['type'] == 'arrow') ...'x2,y2'.split(','),
      ]) {
        final value = object[coordinate];
        if (value is! num || !value.isFinite || value < 0 || value > 1) {
          throw DomainError('invalidObject');
        }
      }
    }
  }

  List<RecordData> versions(String id) => rows(
    'SELECT * FROM strategy_versions WHERE strategy_id=? ORDER BY version DESC',
    [id],
  );
  void restoreVersion(String id, int version) {
    final old = rows(
      'SELECT payload FROM strategy_versions WHERE strategy_id=? AND version=?',
      [id, version],
    ).single;
    final value = jsonDecode(old['payload'] as String) as Map<String, dynamic>;
    saveStrategy(
      id,
      value['notes'] as String,
      (jsonDecode(value['objects'] as String) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      strategy(id)['version'] as int,
      level: value['level'] as String? ?? 'default',
    );
  }

  List<RecordData> tasks(String team) => rows(
    'SELECT t.*,m.name AS member_name,s.title AS strategy_title FROM tasks t LEFT JOIN members m ON m.id=t.member_id LEFT JOIN strategies s ON s.id=t.strategy_id WHERE t.team_id=? ORDER BY t.updated_at DESC',
    [team],
  );
  String createTask(
    String team,
    String title,
    String notes, {
    String? member,
    String? strategyId,
    String taskType = 'general',
    DateTime? dueAt,
    String criteria = '',
  }) {
    if (!canEditTeam(team)) throw DomainError('readOnlyTeam');
    if (notes.length > 20000) throw DomainError('limit');
    validateTaskPlan(taskType, dueAt, criteria);
    if (member != null &&
        rows('SELECT id FROM members WHERE id=? AND team_id=?', [
          member,
          team,
        ]).isEmpty) {
      throw DomainError('crossTeam');
    }
    if (strategyId != null &&
        rows(
          'SELECT s.id FROM strategies s JOIN maps m ON m.id=s.map_id WHERE s.id=? AND m.team_id=?',
          [strategyId, team],
        ).isEmpty) {
      throw DomainError('crossTeam');
    }
    final id = uuid.v4();
    db.execute(
      'INSERT INTO tasks(id,team_id,strategy_id,member_id,title,notes,status,updated_at,task_type,due_at,criteria) VALUES(?,?,?,?,?,?,?,?,?,?,?)',
      [
        id,
        team,
        strategyId,
        member,
        requiredText(title),
        notes,
        'todo',
        now,
        taskType,
        dueAt?.toUtc().toIso8601String(),
        criteria.trim(),
      ],
    );
    if (!applyingSync) onTacticalChange?.call();
    return id;
  }

  static DateTime? parseTaskDeadline(Object? value) {
    if (value == null) return null;
    if (value is! String) throw DomainError('invalidText');
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|([+-])(\d{2}):(\d{2}))$',
    ).firstMatch(value);
    if (match == null) throw DomainError('invalidText');
    int n(int group) => int.parse(match.group(group)!);
    final date = DateTime.utc(n(1), n(2), n(3));
    if (n(1) < 1 ||
        date.year != n(1) ||
        date.month != n(2) ||
        date.day != n(3) ||
        n(4) > 23 ||
        n(5) > 59 ||
        n(6) > 59 ||
        (match.group(10) != null && (n(10) > 23 || n(11) > 59))) {
      throw DomainError('invalidText');
    }
    return DateTime.parse(value).toUtc();
  }

  void validateTaskPlan(String taskType, DateTime? dueAt, String criteria) {
    if (criteria.length > 5000) throw DomainError('limit');
    if (dueAt != null && (dueAt.year < 1 || dueAt.year > 9999)) {
      throw DomainError('invalidText');
    }
    if (![
      'general',
      'utility',
      'tactic',
      'dry_run',
      'execute',
      'retake',
      'demo',
      'round_review',
      'fix',
      'quiz',
    ].contains(taskType)) {
      throw DomainError('invalidText');
    }
  }

  void updateTaskPlan(
    String id, {
    required String taskType,
    DateTime? dueAt,
    required String criteria,
    bool replaceAssignee = false,
    String? member,
  }) {
    final task = rows('SELECT * FROM tasks WHERE id=?', [id]).single;
    if (!canEditTeam(task['team_id'] as String)) {
      throw DomainError('readOnlyTeam');
    }
    if (!['todo', 'in_progress'].contains(task['status'])) {
      throw DomainError('invalidTransition');
    }
    if (replaceAssignee &&
        member != null &&
        rows('SELECT id FROM members WHERE id=? AND team_id=?', [
          member,
          task['team_id'],
        ]).isEmpty) {
      throw DomainError('crossTeam');
    }
    validateTaskPlan(taskType, dueAt, criteria);
    db.execute(
      'UPDATE tasks SET task_type=?,due_at=?,criteria=?,member_id=CASE WHEN ? THEN ? ELSE member_id END,updated_at=? WHERE id=?',
      [
        taskType,
        dueAt?.toUtc().toIso8601String(),
        criteria.trim(),
        replaceAssignee ? 1 : 0,
        member,
        now,
        id,
      ],
    );
    if (!applyingSync) onTacticalChange?.call();
  }

  void transitionTask(String id, String status, {String reason = ''}) {
    final task = rows('SELECT * FROM tasks WHERE id=?', [id]).single;
    final team = task['team_id'] as String;
    if (!canEditTeam(team) &&
        !(setting('shared_role_$team') == 'player' &&
            task['member_id'] == setting('shared_user_member_$team') &&
            ['todo', 'in_progress'].contains(task['status']) &&
            ['in_progress', 'submitted'].contains(status))) {
      throw DomainError('readOnlyTeam');
    }
    final current = task['status'];
    const allowed = {
      'todo': ['in_progress', 'submitted'],
      'in_progress': ['submitted', 'todo'],
      'submitted': ['approved', 'todo'],
      'approved': ['todo'],
    };
    if (!(allowed[current]?.contains(status) ?? false)) {
      throw DomainError('invalidTransition');
    }
    if (status == 'todo' && current != 'todo' && reason.trim().isEmpty) {
      throw DomainError('reviewReasonRequired');
    }
    if (reason.length > 2000) throw DomainError('limit');
    db.execute(
      'UPDATE tasks SET status=?,updated_at=?,review_reason=? WHERE id=?',
      [
        status,
        now,
        status == 'todo' ? reason.trim() : task['review_reason'],
        id,
      ],
    );
    if (!applyingSync) onTacticalChange?.call();
  }

  List<RecordData> demos(String team) => rows(
    'SELECT * FROM demos WHERE team_id=? ORDER BY imported_at DESC',
    [team],
  );
  void addDemo(String team, String name, String path, int size) => db.execute(
    'INSERT INTO demos(id,team_id,name,path,size,imported_at) VALUES(?,?,?,?,?,?)',
    [uuid.v4(), team, requiredText(name, 255), path, size, now],
  );
  void saveAnalysis(
    String id,
    String analysis,
    String map,
    String checksum, {
    String? sourcePage,
    String? match,
    String? participants,
  }) => db.execute(
    'UPDATE demos SET analysis_path=?,map_key=?,sha256=?,source_page=?,match_id=?,participants=? WHERE id=?',
    [analysis, map, checksum, sourcePage, match, participants, id],
  );
  List<RecordData> annotations(String demo) => rows(
    'SELECT * FROM demo_annotations WHERE demo_id=? ORDER BY tick',
    [demo],
  );
  void annotate(String demo, int tick, int round, String note) => db.execute(
    'INSERT INTO demo_annotations VALUES(?,?,?,?,?,?)',
    [uuid.v4(), demo, tick, round, requiredText(note, 2000), now],
  );
  void saveScouting(String demo, Map<String, dynamic> value) {
    for (final entry in value.entries) {
      if (![
            'teams',
            'event',
            'positions',
            'tier',
            'source',
          ].contains(entry.key) ||
          entry.value is! String ||
          (entry.value as String).length > 10000) {
        throw DomainError('invalidScouting');
      }
    }
    if (!['', '1', '2', '3', '4'].contains(value['tier'] ?? '')) {
      throw DomainError('invalidScouting');
    }
    final encoded = jsonEncode(value);
    if (encoded.length > 20000) throw DomainError('limit');
    final item = rows('SELECT team_id,match_id FROM demos WHERE id=?', [
      demo,
    ]).single;
    if (item['match_id'] != null) {
      db.execute('UPDATE demos SET scouting=? WHERE team_id=? AND match_id=?', [
        encoded,
        item['team_id'],
        item['match_id'],
      ]);
    } else {
      db.execute('UPDATE demos SET scouting=? WHERE id=?', [encoded, demo]);
    }
  }

  void deleteAnnotation(String id, String demo) => db.execute(
    'DELETE FROM demo_annotations WHERE id=? AND demo_id=?',
    [id, demo],
  );

  void close() {
    _tacticalUpdates.close();
    db.close();
  }
}
