import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'account.dart';
import 'account_roster.dart';
import 'store.dart';
import 'team_schedule.dart';

class ReminderPlatform {
  static const channel = MethodChannel('app.teamsync/reminders');
  bool get supported => Platform.isWindows || Platform.isAndroid;
  Future<Map> status() async {
    if (!supported) return {'supported': false, 'enabled': false};
    try {
      return await channel.invokeMapMethod<String, dynamic>('status') ??
          {'supported': false};
    } on MissingPluginException {
      return {'supported': false, 'enabled': false};
    }
  }

  Future<bool> permission() async =>
      await channel.invokeMethod<bool>('requestPermission') ?? false;
  Future<void> clear() async {
    if (supported) await channel.invokeMethod<void>('clear');
  }

  Future<int> replace(List<Map<String, dynamic>> items) async =>
      await channel.invokeMethod<int>('replace', {'items': items}) ?? 0;
  Future<void> settings() async => channel.invokeMethod<void>('settings');
  Future<bool> test(String body) async =>
      await channel.invokeMethod<bool>('test', {
        'title': 'TeamSync',
        'body': body,
      }) ??
      false;
}

/// Local generic notices. Account/event details remain inside the authenticated app.
List<Map<String, dynamic>> planReminders(
  List<Map<String, dynamic>> feed,
  int minutes,
  DateTime now,
  String body,
) {
  final result = <Map<String, dynamic>>[];
  final unique = <String>{};
  for (final row in feed) {
    final event = Map<String, dynamic>.from(row['event'] as Map);
    if (event['status'] != 'scheduled' || event['my_rsvp'] == 'declined') {
      continue;
    }
    final start = DateTime.tryParse(event['starts_at'] as String? ?? '');
    if (start == null ||
        start.isBefore(now.subtract(const Duration(minutes: 5))) ||
        start.isAfter(now.add(const Duration(days: 30)))) {
      continue;
    }
    final at = start.subtract(Duration(minutes: minutes));
    final id = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              row['scope'],
              event['id'],
              start.toUtc().toIso8601String(),
              minutes,
            ]),
          ),
        )
        .toString()
        .substring(0, 16);
    if (!unique.add(id)) continue;
    result.add({
      'id': id,
      'at': at.millisecondsSinceEpoch,
      'start': start.millisecondsSinceEpoch,
      'title': 'TeamSync',
      'body': body,
    });
  }
  result.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
  return result.take(64).toList();
}

class ReminderCoordinator extends ChangeNotifier {
  static final _controllers = Expando<ReminderCoordinator>();
  static ReminderCoordinator? of(Store store) => _controllers[store];
  final Store store;
  final ReminderPlatform native;
  final AccountClient Function(String)? clientFactory;
  final DateTime Function() clock;
  Timer? timer;
  bool busy = false,
      available = false,
      allowed = false,
      partial = false,
      foreground = true;
  bool _disposed = false,
      _again = false,
      _started = false,
      _logoutPending = false;
  int count = 0, _epoch = 0;
  String? error, lastSync;
  ReminderCoordinator(
    this.store, {
    ReminderPlatform? platform,
    this.clientFactory,
    DateTime Function()? now,
  }) : native = platform ?? ReminderPlatform(),
       clock = now ?? DateTime.now;
  String? get identity => store.setting('account_signed_out') == '1'
      ? null
      : store.setting('account_identity');
  String get preferenceKey => 'reminder_pref_${identity ?? ''}';
  Map get preference => jsonDecode(
    store.setting(preferenceKey) ?? '{"enabled":false,"minutes":15}',
  ) as Map;
  bool get enabled => identity != null && preference['enabled'] == true;
  int get minutes => preference['minutes'] as int? ?? 15;
  String get body => store.setting('language') == 'en'
      ? 'Practice reminder. Open TeamSync to check your current schedule.'
      : 'Напоминание о тренировке. Откройте TeamSync и проверьте актуальное расписание.';
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _controllers[store] = this;
    store.settingListeners.add(changed);
    unawaited(refresh());
  }

  void changed(String key) {
    if (_disposed) return;
    _epoch++;
    if (key == 'account_identity' ||
        key == 'account_signed_out' && store.setting(key) == '0') {
      _logoutPending = false;
    }
    if (key == 'account_identity' ||
        key == 'account_signed_out' ||
        key.startsWith('account_team_')) {
      count = 0;
      lastSync = null;
      unawaited(native.clear().catchError((_) {}));
    }
    unawaited(refresh());
  }

  Future<void> configure(bool value, int lead) async {
    if (![0, 5, 10, 15, 30, 60, 120].contains(lead)) throw DomainError('limit');
    final actor = identity;
    if (actor == null) throw DomainError('unauthorized');
    if (value && !await native.permission()) {
      throw DomainError('notificationPermission');
    }
    if (identity != actor) throw DomainError('syncAccountMismatch');
    store.setSetting(
      'reminder_pref_$actor',
      jsonEncode({'enabled': value, 'minutes': lead}),
    );
    await refresh();
  }

  List<Map<String, dynamic>> feed(Map<String, dynamic> cache) {
    final result = <Map<String, dynamic>>[];
    for (final team in visibleAccountTeams(store).take(20)) {
      final api = TeamSchedule(store, team['id'] as String);
      final scope = jsonEncode([
        api.binding['server'],
        api.binding['user'],
        api.binding['team'],
      ]);
      final events = {for (final row in api.cached()) row['id']: row};
      final pending = api.pending();
      for (final raw in cache[scope] as List? ?? []) {
        var event = Map<String, dynamic>.from(raw as Map);
        final local = events[event['id']];
        if (local != null &&
            (local['version'] as int) > (event['version'] as int)) {
          event = {...event, ...local};
        }
        final person = api
            .cachedPeople(event['id'] as String)
            .where((r) => r['user_id'] == api.binding['user'])
            .firstOrNull;
        if (person != null &&
            (person['version'] as int) >
                (event['my_rsvp_version'] as int? ?? 0)) {
          event['my_rsvp'] = person['rsvp'];
        }
        bool suppress = false;
        for (final operation in pending.where(
          (r) => r['event'] == event['id'],
        )) {
          final body = operation['body'] as Map;
          if (operation['target'] == api.binding['user'] &&
              body['rsvp'] != null) {
            event['my_rsvp'] = body['rsvp'];
          }
          if (operation['target'] == null &&
              (body['status'] == 'cancelled' ||
                  DateTime.parse(body['starts_at'] as String).toUtc() !=
                      DateTime.parse(event['starts_at'] as String).toUtc())) {
            suppress = true;
          }
        }
        if (!suppress) result.add({'scope': scope, 'event': event});
      }
    }
    return result;
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (busy) {
      _again = true;
      return;
    }
    busy = true;
    error = null;
    partial = false;
    notifyListeners();
    final epoch = _epoch, actor = identity;
    bool current() => !_disposed && epoch == _epoch && actor == identity;
    try {
      final status = await native.status();
      if (!current()) return;
      available = status['supported'] == true;
      allowed = status['enabled'] == true;
      if (available && _started) {
        timer ??= Timer.periodic(const Duration(minutes: 1), (_) {
          if (foreground) refresh();
        });
      }
      if (!available) {
        count = 0;
        return;
      }
      if (_logoutPending || actor == null || !enabled || !allowed) {
        await native.clear();
        if (current()) count = 0;
        return;
      }
      lastSync ??= store.setting('reminder_sync_$actor');
      final cacheKey = 'reminder_feed_$actor';
      final cached = Map<String, dynamic>.from(
        jsonDecode(store.setting(cacheKey) ?? '{}') as Map,
      );
      final fresh = <String, dynamic>{};
      final now = clock().toUtc();
      await native.replace(planReminders(feed(cached), minutes, now, body));
      if (!current()) return;
      final teams = visibleAccountTeams(store);
      if (teams.length > 20) partial = true;
      for (final team in teams.take(20)) {
        final local = team['id'] as String;
        final api = TeamSchedule(store, local, clientFactory: clientFactory);
        final scope = jsonEncode([
          api.binding['server'],
          api.binding['user'],
          api.binding['team'],
        ]);
        try {
          final events = <Map<String, dynamic>>[];
          int? offset = 0;
          while (offset != null && offset < 200) {
            final page = await api.list(
              now.subtract(const Duration(minutes: 5)),
              now.add(const Duration(days: 30)),
              offset: offset,
            );
            if (!current()) return;
            events.addAll(page.items);
            offset = page.next;
          }
          if (offset != null) partial = true;
          fresh[scope] = events;
        } on DomainError catch (e) {
          if (!current()) return;
          if (['unauthorized', 'syncAccountMismatch'].contains(e.code)) {
            await native.clear();
            count = 0;
            error = 'auth';
            return;
          }
          if (!['forbidden', 'not_found'].contains(e.code)) {
            partial = true;
            fresh[scope] = cached[scope] ?? [];
          }
        } catch (_) {
          if (!current()) return;
          partial = true;
          fresh[scope] = cached[scope] ?? [];
        }
      }
      if (!current()) return;
      store.setSetting(cacheKey, jsonEncode(fresh));
      final plan = planReminders(feed(fresh), minutes, now, body);
      final scheduled = await native.replace(plan);
      if (!current()) return;
      count = scheduled;
      if (!partial) {
        lastSync = now.toIso8601String();
        store.setSetting('reminder_sync_$actor', lastSync!);
      }
    } catch (_) {
      if (!_disposed) {
        error = 'unavailable';
        try {
          await native.clear();
          count = 0;
        } catch (_) {}
      }
    } finally {
      busy = false;
      if (!_disposed) {
        notifyListeners();
        if (_again) {
          _again = false;
          unawaited(refresh());
        }
      }
    }
  }

  Future<void> clearForLogout() async {
    _logoutPending = true;
    _epoch++;
    await native.clear();
    count = 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    timer?.cancel();
    store.settingListeners.remove(changed);
    if (_controllers[store] == this) _controllers[store] = null;
    super.dispose();
  }
}
