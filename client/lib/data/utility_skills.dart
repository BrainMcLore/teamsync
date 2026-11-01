import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'account.dart';
import 'store.dart';

class SkillStore {
  final Store store;
  final String team;
  SkillStore(this.store, this.team);
  Map get binding => jsonDecode(store.setting('account_team_$team')!) as Map;
  String get user => binding['user'] as String;
  Map<String, String> get roster {
    final b = binding;
    final key = sha256.convert(
      utf8.encode('${b['server']}/${b['user']}/${b['team']}'),
    );
    final value =
        jsonDecode(store.setting('account_roster_$key') ?? '{}') as Map;
    return Map<String, String>.from(value['members'] as Map? ?? {});
  }

  String document(String local) {
    final state =
        jsonDecode(store.setting('tactical_sync_$team') ?? '{}') as Map;
    final e = (state['entries'] as Map? ?? {})['utility:$local'] as Map?;
    return e?['remote'] as String? ??
        Store.uuid.v5(
          '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
          '${binding['server']}/${binding['team']}/utility/$local',
        );
  }

  Map<String, dynamic> row(String document, String target, int revision) {
    final record = store.rows(
      'SELECT * FROM utility_progress_cache WHERE team_id=? AND document_id=? AND user_id=? AND revision=?',
      [team, document, target, revision],
    ).firstOrNull;
    return {
      'document': document,
      'user': target,
      'revision': revision,
      'remote': record == null
          ? <String, dynamic>{
              'version': 0,
              'status': 'not_started',
              'reason': '',
            }
          : jsonDecode(record['remote'] as String),
      'desired': record?['desired'] == null
          ? null
          : jsonDecode(record!['desired'] as String),
      'pending': record?['pending'] == null
          ? null
          : jsonDecode(record!['pending'] as String),
      'conflict': record?['conflict'] == 1,
      'archived': record?['archived'] == 1,
    };
  }

  List<Map<String, dynamic>> get rows => store
      .rows(
        'SELECT document_id,user_id,revision FROM utility_progress_cache WHERE team_id=?',
        [team],
      )
      .map(
        (r) => row(
          r['document_id'] as String,
          r['user_id'] as String,
          r['revision'] as int,
        ),
      )
      .toList();
  void save(Map<String, dynamic> row) {
    store.db.execute(
      '''INSERT INTO utility_progress_cache VALUES(?,?,?,?,?,?,?,?,?)
ON CONFLICT(team_id,document_id,user_id,revision) DO UPDATE SET remote=excluded.remote,desired=excluded.desired,pending=excluded.pending,conflict=excluded.conflict,archived=excluded.archived''',
      [
        team,
        row['document'],
        row['user'],
        row['revision'],
        jsonEncode(row['remote']),
        row['desired'] == null ? null : jsonEncode(row['desired']),
        row['pending'] == null ? null : jsonEncode(row['pending']),
        row['conflict'] == true ? 1 : 0,
        row['archived'] == true ? 1 : 0,
      ],
    );
    store.notifyRemoteTactical('skills:$team');
  }

  bool mayWrite(String target, String status) =>
      store.canEditTeam(team) ||
      (store.setting('shared_role_$team') == 'player' &&
          target == user &&
          status != 'confirmed');
  void desire(
    String local,
    int revision,
    String target,
    String status, {
    String reason = '',
  }) {
    if (!['not_started', 'learning', 'ready', 'confirmed'].contains(status) ||
        reason.length > 2000) {
      throw DomainError('invalidText');
    }
    if (!mayWrite(target, status)) throw DomainError('readOnlyTeam');
    final utility = store.rows(
      'SELECT details FROM utilities WHERE id=? AND team_id=?',
      [local, team],
    ).firstOrNull;
    if (utility == null) throw DomainError('not_found');
    final actual =
        (jsonDecode(utility['details'] as String)
            as Map)['training_revision'] ??
        1;
    if (actual != revision) throw DomainError('progress_revision_changed');
    if (target != user && !roster.containsKey(target)) {
      throw DomainError('crossTeam');
    }

    if (store.setting('account_signed_out') == '1' ||
        store.setting('account_identity') !=
            jsonEncode([binding['server'], user])) {
      throw DomainError('syncAccountMismatch');
    }
    final record = row(document(local), target, revision);
    record['desired'] = {
      'status': status,
      'reason': reason,
      'base_version': (record['remote'] as Map)['version'],
      'after_operation': (record['pending'] as Map?)?['operation_id'],
    };
    record['archived'] = false;
    save(record);
    store.onTacticalChange?.call();
  }

  void resolve(
    String document,
    String target,
    int revision, {
    required bool keepLocal,
  }) {
    final record = row(document, target, revision),
        desired = record['desired'] as Map?;
    if (keepLocal && desired != null) {
      if (!mayWrite(target, desired['status'] as String)) {
        throw DomainError('readOnlyTeam');
      }
      desired['base_version'] = (record['remote'] as Map)['version'];
      desired['after_operation'] = null;
    } else {
      record['desired'] = null;
    }
    record['conflict'] = false;
    record['pending'] = null;
    save(record);
    store.onTacticalChange?.call();
  }
}

class SkillSync {
  final SkillStore local;
  final AccountClient api;
  final String path, user;
  final void Function() assertActive;
  bool blocked = false, pending = false;
  int conflicts = 0;
  SkillSync(this.local, this.api, this.path, this.user, this.assertActive);

  Future<void> flush() async {
    for (final old in local.rows.where(
      (r) => r['pending'] != null && r['archived'] != true,
    )) {
      final body = Map<String, dynamic>.from(old['pending'] as Map);
      if (!local.mayWrite(old['user'] as String, body['status'] as String)) {
        blocked = true;
        continue;
      }
      assertActive();
      try {
        final remote = await api.request(
          'POST',
          '$path/utilities/${old['document']}/progress',
          body: body,
        );
        final row = local.row(
          old['document'] as String,
          old['user'] as String,
          old['revision'] as int,
        );
        if ((row['pending'] as Map?)?['operation_id'] != body['operation_id']) {
          continue;
        }
        row['remote'] = remote;
        row['pending'] = null;
        final desired = row['desired'] as Map?;
        if (desired != null) {
          if (desired['status'] == body['status'] &&
              desired['reason'] == body['reason']) {
            row['desired'] = null;
          } else if (desired['after_operation'] == body['operation_id']) {
            desired['base_version'] = remote['version'];
            desired['after_operation'] = null;
          }
        }
        local.save(row);
      } on DomainError catch (e) {
        final row = local.row(
          old['document'] as String,
          old['user'] as String,
          old['revision'] as int,
        );
        if (e.code == 'forbidden') {
          blocked = true;
          continue;
        }
        if (e.code == 'progress_revision_changed' || e.code == 'not_found') {
          row['archived'] = true;
          row['pending'] = null;
          local.save(row);
          continue;
        }
        if (e.code == 'version_conflict' || e.code == 'write_conflict') {
          row['conflict'] = true;
          row['pending'] = null;
          local.save(row);
          conflicts++;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> pull() async {
    for (var offset = 0; ; offset += 100) {
      assertActive();
      final values =
          (await api.request(
                'GET',
                '$path/utility-progress?offset=$offset&limit=100',
              ))['items']
              as List;
      local.store.transaction(() {
        for (final value in values) {
          final remote = Map<String, dynamic>.from(value as Map);
          final row = local.row(
            remote['document_id'] as String,
            remote['user_id'] as String,
            remote['revision'] as int,
          );
          final old = row['remote'] as Map, desired = row['desired'] as Map?;
          var changed = false;
          if (desired != null &&
              row['pending'] == null &&
              desired['base_version'] != remote['version']) {
            if (desired['status'] == remote['status'] &&
                desired['reason'] == remote['reason']) {
              row['desired'] = null;
              row['conflict'] = false;
              changed = true;
            } else {
              row['conflict'] = true;
              changed = true;
            }
          }
          if (jsonEncode(old) != jsonEncode(remote) ||
              changed ||
              row['desired'] != null) {
            row['remote'] = remote;
            local.save(row);
          }
        }
      });
      if (values.length < 100) break;
    }
  }

  Future<void> run() async {
    await flush();
    await pull();
    for (final original in local.rows.where(
      (r) =>
          r['desired'] != null &&
          r['pending'] == null &&
          r['conflict'] != true &&
          r['archived'] != true,
    )) {
      final row = local.row(
            original['document'] as String,
            original['user'] as String,
            original['revision'] as int,
          ),
          desired = row['desired'] as Map;
      if (!local.mayWrite(row['user'] as String, desired['status'] as String)) {
        blocked = true;
        continue;
      }
      row['pending'] = {
        'operation_id': Store.uuid.v4(),
        'target_user_id': row['user'],
        'revision': row['revision'],
        'expected_version': (row['remote'] as Map)['version'],
        'status': desired['status'],
        'reason': desired['reason'],
      };
      local.save(row);
    }
    await flush();
    pending = local.rows.any(
      (r) =>
          r['archived'] != true &&
          r['conflict'] != true &&
          (r['desired'] != null || r['pending'] != null),
    );
    conflicts = local.rows.where((r) => r['conflict'] == true).length;
  }
}
