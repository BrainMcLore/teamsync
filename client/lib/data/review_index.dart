import 'dart:math' as math;

/// Built once off the UI isolate. Playback queries never rescan/sort the match.
class ReviewIndex {
  final List<Map<String, dynamic>> events = [];
  final List<Map<String, dynamic>> intervals = [];
  final List<Map> players;
  int maxLifetime = 0;
  ReviewIndex(Map<String, dynamic> data)
    : players = (data['players'] as List).cast<Map>().toList()
        ..sort((a, b) => (b['kills'] as int).compareTo(a['kills'] as int)) {
    for (final raw in data['kills'] as List) {
      events.add({...raw as Map<String, dynamic>, 'kind': 'kill'});
    }
    final source = data['events'] as Map? ?? {};
    for (final key in [
      'bomb_planted',
      'bomb_defused',
      'bomb_exploded',
      'smokegrenade_detonate',
      'inferno_startburn',
      'flashbang_detonate',
    ]) {
      for (final raw in source[key] as List? ?? []) {
        events.add({...raw as Map<String, dynamic>, 'kind': key});
      }
    }
    events.sort((a, b) => (a['tick'] as int).compareTo(b['tick'] as int));
    for (final pair in [
      ('smokegrenade_detonate', 'smokegrenade_expired', 'S'),
      ('inferno_startburn', 'inferno_expire', 'M'),
    ]) {
      final endings = <Object?, List<int>>{};
      for (final raw in source[pair.$2] as List? ?? []) {
        (endings[raw['entityid']] ??= []).add(raw['tick'] as int);
      }
      for (final values in endings.values) {
        values.sort();
      }
      for (final raw in source[pair.$1] as List? ?? []) {
        final point = raw as Map<String, dynamic>, start = point['tick'] as int;
        final values = endings[point['entityid']];
        if (values == null || point['x'] is! num || point['y'] is! num) {
          continue;
        }
        var low = 0, high = values.length;
        while (low < high) {
          final mid = (low + high) ~/ 2;
          if (values[mid] < start) {
            low = mid + 1;
          } else {
            high = mid;
          }
        }
        if (low == values.length) continue;
        final end = values[low];
        intervals.add({...point, 'end': end, 'label': pair.$3});
        maxLifetime = math.max(maxLifetime, end - start);
      }
    }
    intervals.sort((a, b) => (a['tick'] as int).compareTo(b['tick'] as int));
  }
  static int upperBound(List<Map<String, dynamic>> values, int tick) {
    var low = 0, high = values.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if ((values[mid]['tick'] as int) <= tick) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  List<Map<String, dynamic>> recent(int tick, [int count = 6]) {
    final end = upperBound(events, tick);
    return events.sublist(math.max(0, end - count), end).reversed.toList();
  }

  List<Map<String, dynamic>> active(int tick) {
    final start = upperBound(intervals, tick - maxLifetime - 1),
        end = upperBound(intervals, tick);
    return [
      for (var i = start; i < end; i++)
        if ((intervals[i]['end'] as int) > tick) intervals[i],
    ];
  }
}

int floorFrameAtTick(List<dynamic> frames, num tick) {
  var low = 0, high = frames.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if ((frames[middle]['tick'] as int) <= tick) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return (low - 1).clamp(0, frames.length - 1);
}

/// Visual interpolation only; events, health, side and notes keep sampled ticks.
List<dynamic> interpolatedPlayers(Map frame, Map? next, double tick, num rate) {
  if (next == null ||
      frame['round'] != next['round'] ||
      (next['tick'] as int) - (frame['tick'] as int) > rate) {
    return frame['players'] as List;
  }
  final span = (next['tick'] as int) - (frame['tick'] as int);
  if (span <= 0) return frame['players'] as List;
  final fraction = ((tick - (frame['tick'] as int)) / span).clamp(0.0, 1.0);
  final future = {for (final p in next['players'] as List) p['id']: p as Map};
  return [
    for (final raw in frame['players'] as List)
      (() {
        final p = raw as Map, b = future[p['id']];
        if (b == null ||
            b['team'] != p['team'] ||
            b['alive'] != p['alive'] ||
            (p['hp'] as num) <= 0 ||
            math.pow((b['x'] as num) - (p['x'] as num), 2) +
                    math.pow((b['y'] as num) - (p['y'] as num), 2) >
                400 * 400) {
          return p;
        }
        final yaw = (p['yaw'] as num?) ?? 0,
            delta = (((b['yaw'] as num?) ?? yaw) - yaw + 540) % 360 - 180;
        return {
          ...p,
          'x': (p['x'] as num) + ((b['x'] as num) - (p['x'] as num)) * fraction,
          'y': (p['y'] as num) + ((b['y'] as num) - (p['y'] as num)) * fraction,
          'z':
              ((p['z'] as num?) ?? 0) +
              (((b['z'] as num?) ?? 0) - ((p['z'] as num?) ?? 0)) * fraction,
          'yaw': yaw + delta * fraction,
        };
      })(),
  ];
}
