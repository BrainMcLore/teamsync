import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'store.dart';

/// Only expose cached teams belonging to the last authenticated identity.
/// A legacy cache without an identity must be rebound after signing in.
List<RecordData> visibleAccountTeams(Store store) {
  if (store.setting('account_signed_out') == '1') return [];
  final active = store.setting('account_identity');
  if (active == null) return [];
  return store.teams.where((team) {
    final raw = store.setting('account_team_${team['id']}');
    if (raw == null) return false;
    try {
      final binding = jsonDecode(raw) as Map;
      return jsonEncode([binding['server'], binding['user']]) == active;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }).toList();
}

void rememberAccountIdentity(Store store, String server, String user) {
  store.setSetting('account_identity', jsonEncode([server, user]));
  store.setSetting('account_signed_out', '0');
}

/// Server roster snapshots are namespaced by server and signed-in account.
/// Tactical sync uses this binding to the authenticated remote team.
String saveAccountRoster(
  Store store,
  String server,
  String user,
  Map<String, dynamic> team,
  List<dynamic> roster, {
  String? localTeam,
  bool select = true,
}) {
  final namespace = sha256
      .convert(utf8.encode('$server/$user/${team['id']}'))
      .toString();
  final key = 'account_roster_$namespace';
  final previous = store.setting(key);
  final ids = previous == null
      ? <String, dynamic>{}
      : jsonDecode(previous) as Map<String, dynamic>;
  final result = store.transaction(() {
    var local = ids['team'] as String? ?? localTeam;
    if (localTeam != null &&
        store.setting('account_team_$localTeam') != null &&
        local != ids['team']) {
      throw DomainError('teamAlreadyLinked');
    }
    if (local == null || !store.teams.any((t) => t['id'] == local)) {
      local = store.createTeam(team['name'] as String);
    }
    store.db.execute('UPDATE teams SET name=? WHERE id=?', [
      team['name'],
      local,
    ]);
    final old = Map<String, dynamic>.from(ids['members'] as Map? ?? {});
    final current = <String, String>{};
    for (final raw in roster) {
      final row = Map<String, dynamic>.from(raw as Map);
      final account = row['id'] as String;
      var member = old[account] as String?;
      final present =
          member != null &&
          store.rows('SELECT id FROM members WHERE id=? AND team_id=?', [
            member,
            local,
          ]).isNotEmpty;
      if (!present) {
        member = store.addMember(
          local,
          row['name'] as String,
          row['role'] as String,
          (row['game_role'] as String?)?.isNotEmpty == true
              ? row['game_role'] as String
              : '—',
        );
      } else {
        store.db.execute(
          'UPDATE members SET name=?,role=?,game_role=? WHERE id=? AND team_id=?',
          [row['name'], row['role'], row['game_role'] ?? '—', member, local],
        );
      }
      current[account] = member;
    }
    for (final item in old.entries) {
      if (!current.containsKey(item.key)) {
        store.db.execute('UPDATE tasks SET member_id=NULL WHERE member_id=?', [
          item.value,
        ]);
        store.db.execute('DELETE FROM members WHERE id=? AND team_id=?', [
          item.value,
          local,
        ]);
      }
    }
    store.setSetting(key, jsonEncode({'team': local, 'members': current}));
    if (select) {
      store.setSetting('team', local);
      rememberAccountIdentity(store, server, user);
    }
    store.setSetting('shared_user_member_$local', current[user] ?? '');
    store.setSetting('shared_role_$local', team['role'] as String? ?? 'player');
    store.setSetting(
      'account_team_$local',
      jsonEncode({'server': server, 'team': team['id'], 'user': user}),
    );
    return local;
  });
  if (select) store.onTeamChange?.call();
  return result;
}
