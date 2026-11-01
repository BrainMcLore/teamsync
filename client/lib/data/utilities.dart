import 'dart:convert';

import 'store.dart';

/// External videos remain links; TeamSync never downloads third-party clips.
class UtilityLibrary {
  final Store store;
  UtilityLibrary(this.store);

  static String? source(String value) {
    if (value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        ![
          'youtube.com',
          'www.youtube.com',
          'm.youtube.com',
          'youtu.be',
          'cs2tricks.com',
          'www.cs2tricks.com',
        ].contains(uri.host)) {
      throw DomainError('invalidSource');
    }
    return uri.toString();
  }

  List<RecordData> list(String team) => store.rows(
    'SELECT u.*,m.name AS map_name FROM utilities u JOIN maps m ON m.id=u.map_id WHERE u.team_id=? ORDER BY u.updated_at DESC',
    [team],
  );

  String save(
    String team,
    String map,
    String title,
    String side,
    String notes,
    Map<String, dynamic> details, {
    String? id,
  }) {
    if (!store.canEditTeam(team)) throw DomainError('readOnlyTeam');
    if (!['T', 'CT'].contains(side) ||
        store.maps(team).every((m) => m['id'] != map)) {
      throw DomainError('crossTeam');
    }
    if (![
      'smoke',
      'flash',
      'molotov',
      'he',
      'decoy',
    ].contains(details['grenade'])) {
      throw DomainError('invalidText');
    }
    if (notes.length > 20000 || jsonEncode(details).length > 20000) {
      throw DomainError('limit');
    }
    const limits = {
      'grenade': 20,
      'start': 500,
      'target': 500,
      'throw_type': 120,
      'author': 120,
      'source_url': 2000,
      'verified_at': 40,
      'map_revision': 120,
    };
    if (details.keys.any(
      (key) => !limits.containsKey(key) && key != 'strategy_ids',
    )) {
      throw DomainError('invalidText');
    }
    final value = <String, dynamic>{};
    for (final entry in limits.entries) {
      final raw = details[entry.key] ?? '';
      if (raw is! String || raw.length > entry.value) {
        throw DomainError('invalidText');
      }
      value[entry.key] = raw.trim();
    }
    value['source_url'] = source(value['source_url'] as String);
    final links = details['strategy_ids'] as List? ?? [];
    final allowed = store.strategies(team).map((s) => s['id']).toSet();
    if (links.length > 50 || links.any((id) => !allowed.contains(id))) {
      throw DomainError('crossTeam');
    }
    value['strategy_ids'] = links.toSet().toList();

    if (id != null && !list(team).any((u) => u['id'] == id)) {
      throw DomainError('crossTeam');
    }
    final key = id ?? Store.uuid.v4();
    store.db.execute(
      '''INSERT INTO utilities(id,team_id,map_id,title,side,notes,details,updated_at)
VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET map_id=excluded.map_id,title=excluded.title,
side=excluded.side,notes=excluded.notes,details=excluded.details,updated_at=excluded.updated_at''',
      [
        key,
        team,
        map,
        store.requiredText(title),
        side,
        notes,
        jsonEncode(value),
        store.now,
      ],
    );
    if (!store.applyingSync) store.onTacticalChange?.call();
    return key;
  }
}
