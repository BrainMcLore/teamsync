import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'store.dart';
import 'review_index.dart';

Map<String, dynamic> decodeReview(String source) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  if (data['schema'] != 1 ||
      data['parser'] != 'demoparser2' ||
      data['map'] is! String) {
    throw DomainError('reviewDataInvalid');
  }
  final frames = data['frames'] as List,
      players = data['players'] as List,
      rounds = data['rounds'] as List;
  if (frames.isEmpty ||
      frames.length > 200000 ||
      players.length > 128 ||
      rounds.isEmpty ||
      rounds.length > 1000) {
    throw DomainError('reviewDataInvalid');
  }
  if (data['tick_rate'] is! num ||
      (data['tick_rate'] as num) <= 0 ||
      !(data['tick_rate'] as num).isFinite ||
      (data['tick_rate'] as num) > 1024 ||
      data['sample_stride'] is! num ||
      (data['sample_stride'] as num) <= 0) {
    throw DomainError('reviewDataInvalid');
  }
  for (final raw in players) {
    final player = raw as Map;
    if (player['steamid'] is! String ||
        player['name'] is! String ||
        (player['name'] as String).length > 256) {
      throw DomainError('reviewDataInvalid');
    }
    for (final key in ['kills', 'deaths', 'assists']) {
      if (player[key] is! int || (player[key] as int) < 0) {
        throw DomainError('reviewDataInvalid');
      }
    }
  }
  for (final raw in rounds) {
    final r = raw as Map;
    if (r['number'] is! int ||
        r['start'] is! int ||
        r['end'] is! int ||
        (r['number'] as int) < 1 ||
        (r['start'] as int) > (r['end'] as int)) {
      throw DomainError('reviewDataInvalid');
    }
  }
  final kills = data['kills'] as List;
  if (kills.length > 100000) throw DomainError('reviewDataInvalid');
  for (final raw in kills) {
    final kill = raw as Map;
    if (kill['tick'] is! int) throw DomainError('reviewDataInvalid');
    for (final key in ['attacker_name', 'user_name', 'weapon']) {
      if (kill[key] != null && kill[key] is! String) {
        throw DomainError('reviewDataInvalid');
      }
    }
  }
  var previous = -1;
  for (final raw in frames) {
    final frame = raw as Map;
    final tick = frame['tick'] as int;
    if (frame['round'] is! int) throw DomainError('reviewDataInvalid');
    if (tick < previous) throw DomainError('reviewDataInvalid');
    previous = tick;
    final entries = frame['players'] as List;
    if (entries.length > 128) throw DomainError('reviewDataInvalid');
    for (final raw in entries) {
      final player = raw as Map;
      if (player['id'] is! String ||
          player['hp'] is! num ||
          (player['hp'] as num) < 0 ||
          (player['hp'] as num) > 100 ||
          ![2, 3].contains(player['team'])) {
        throw DomainError('reviewDataInvalid');
      }
      for (final axis in ['x', 'y']) {
        final value = player[axis];
        if (value is! num || !value.isFinite) {
          throw DomainError('reviewDataInvalid');
        }
      }
      for (final key in ['z', 'yaw', 'armor']) {
        final v = player[key];
        if (v != null && (v is! num || !v.isFinite)) {
          throw DomainError('reviewDataInvalid');
        }
      }
    }
  }
  data['_index'] = ReviewIndex(data);
  return data;
}

String? _cachedPath;
int? _cachedLength, _cachedModified;
WeakReference<Map<String, dynamic>>? _cachedReview;
final _pendingReviews = <String, Future<Map<String, dynamic>>>{};
Future<Map<String, dynamic>> _readReviewFile(String path) async {
  final file = File(path);
  if (await file.length() > 100 * 1024 * 1024) {
    throw DomainError('reviewDataInvalid');
  }
  return decodeReview(await file.readAsString());
}

Future<Map<String, dynamic>> readReview(String path) async {
  final stat = await File(path).stat();
  if (_cachedPath == path &&
      _cachedLength == stat.size &&
      _cachedModified == stat.modified.microsecondsSinceEpoch) {
    final cached = _cachedReview?.target;
    if (cached != null) return cached;
  }
  if (_pendingReviews.containsKey(path)) return _pendingReviews[path]!;
  final future = compute(_readReviewFile, path);
  _pendingReviews[path] = future;
  try {
    final data = await future;
    _cachedPath = path;
    _cachedLength = stat.size;
    _cachedModified = stat.modified.microsecondsSinceEpoch;
    _cachedReview = WeakReference(data);
    return data;
  } finally {
    _pendingReviews.remove(path);
  }
}

Future<String> importReview(
  Store store,
  Directory root,
  String team,
  Uint8List bytes,
) async {
  if (bytes.length > 100 * 1024 * 1024) throw DomainError('reviewDataInvalid');
  final data = await compute(decodeReview, utf8.decode(bytes));
  final file = File('${root.path}/reviews/${Store.uuid.v4()}.teamsync-review');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  final name = (data['name'] as String?) ?? data['map'] as String;
  store.addDemo(team, name, file.path, bytes.length);
  final id =
      store.rows('SELECT id FROM demos WHERE path=?', [file.path]).single['id']
          as String;
  store.saveAnalysis(
    id,
    file.path,
    data['map'] as String,
    '',
    participants: jsonEncode(data['players']),
  );
  return id;
}
