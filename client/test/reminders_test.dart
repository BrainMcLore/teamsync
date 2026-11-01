import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/account_roster.dart';
import 'package:teamsync/data/reminders.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/team_schedule.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/ui/reminder_settings.dart';

class FakeNotifications extends ReminderPlatform {
  bool granted = true;
  int clears = 0;
  List<List<Map<String, dynamic>>> batches = [];
  @override
  bool get supported => true;
  @override
  Future<Map> status() async => {'supported': true, 'enabled': granted};
  @override
  Future<bool> permission() async => granted;
  @override
  Future<int> replace(List<Map<String, dynamic>> items) async {
    batches.add(items);
    return items.length;
  }

  @override
  Future<void> clear() async {
    clears++;
    batches.add([]);
  }
}

class ReminderApi extends AccountClient {
  ReminderApi() : super('https://fixture.example');
  List<Map<String, dynamic>> events = [];
  bool offline = false, removed = false;
  Completer<Map<String, dynamic>>? held;
  final entered = Completer<void>();
  @override
  Future<void> loadToken() async {
    token = 'fixture';
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authorize = true,
  }) async {
    if (held != null) {
      if (!entered.isCompleted) entered.complete();
      return held!.future;
    }
    if (removed) throw DomainError('not_found');
    if (offline) throw DomainError('offline');
    return {'items': events, 'next': null};
  }
}

(Store, String) fixture() {
  final s = Store(':memory:');
  final team = saveAccountRoster(
    s,
    'https://fixture.example',
    'alice',
    {'id': Store.uuid.v4(), 'name': 'Private team', 'role': 'owner'},
    [
      {'id': 'alice', 'name': 'Alice', 'role': 'owner'},
    ],
  );
  s.setSetting(
    'reminder_pref_${s.setting('account_identity')}',
    jsonEncode({'enabled': true, 'minutes': 15}),
  );
  return (s, team);
}

Map<String, dynamic> event(
  DateTime now, {
  String id = 'event',
  int minutes = 30,
}) => {
  'id': id,
  'title': 'Secret tactic practice',
  'version': 1,
  'kind': 'practice',
  'status': 'scheduled',
  'starts_at': now.add(Duration(minutes: minutes)).toUtc().toIso8601String(),
  'ends_at': now.add(Duration(minutes: minutes + 90)).toUtc().toIso8601String(),
  'my_rsvp': 'going',
  'my_rsvp_version': 1,
};
void main() {
  test('planner uses stable UTC IDs, caps future events and excludes cancellations/declines', () {
    final now = DateTime.utc(2026, 11, 1, 12);
    final first = event(now);
    final offset = {...first, 'starts_at': '2026-11-01T14:30:00+02:00'};
    final feed = [
      {'scope': 'alice/team', 'event': first},
      {'scope': 'alice/team', 'event': offset},
      {
        'scope': 'alice/team',
        'event': {...first, 'id': 'cancel', 'status': 'cancelled'},
      },
      {
        'scope': 'alice/team',
        'event': {...first, 'id': 'decline', 'my_rsvp': 'declined'},
      },
      {'scope': 'alice/team', 'event': event(now, id: 'expired', minutes: -10)},
    ];
    final plan = planReminders(feed, 15, now, 'Check schedule');
    expect(plan, hasLength(1));
    expect(plan.single['title'], 'TeamSync');
    expect(plan.single['body'], 'Check schedule');
    expect(jsonEncode(plan), isNot(contains('Secret')));
    expect(
      planReminders(
        [
          {'scope': 'bob/team', 'event': first},
        ],
        15,
        now,
        'Check',
      ).single['id'],
      isNot(plan.single['id']),
    );
    expect(
      planReminders(
        [
          {'scope': 'alice/team', 'event': first},
        ],
        30,
        now,
        'Check',
      ).single['id'],
      isNot(plan.single['id']),
    );
    final many = [
      for (var i = 0; i < 100; i++)
        {'scope': 'team', 'event': event(now, id: '$i', minutes: 60 + i)},
    ];
    expect(planReminders(many, 15, now, 'Check'), hasLength(64));
  });
  test(
    'fresh cancellation and local offline decline replace prior alarms',
    () async {
      final (s, team) = fixture();
      addTearDown(s.close);
      final native = FakeNotifications(), api = ReminderApi();
      final now = DateTime.utc(2026, 11, 1, 12);
      api.events = [event(now)];
      final c = ReminderCoordinator(
        s,
        platform: native,
        clientFactory: (_) => api,
        now: () => now,
      );
      addTearDown(c.dispose);
      await c.refresh();
      expect(native.batches.last, hasLength(1));
      final scope = TeamSchedule(s, team);
      scope.enqueue(
        'event',
        {'expected_version': 0, 'rsvp': 'declined'},
        'Decline',
        target: 'alice',
      );
      api.offline = true;
      await c.refresh();
      expect(native.batches.last, isEmpty);
      expect(c.partial, isTrue);
      scope.discard(
        (scope.pending().single['body'] as Map)['operation_id'] as String,
      );
      api.offline = false;
      api.events = [
        {...event(now), 'status': 'cancelled', 'version': 2},
      ];
      await c.refresh();
      expect(native.batches.last, isEmpty);
      api.removed = true;
      await c.refresh();
      expect(native.batches.last, isEmpty);
    },
  );
  test('late fetch after logout cannot restore any alarms', () async {
    final (s, _) = fixture();
    addTearDown(s.close);
    final native = FakeNotifications(), api = ReminderApi();
    final now = DateTime.utc(2026, 11, 1, 12);
    api.held = Completer<Map<String, dynamic>>();
    final c = ReminderCoordinator(
      s,
      platform: native,
      clientFactory: (_) => api,
      now: () => now,
    );
    addTearDown(c.dispose);
    s.settingListeners.add(c.changed);
    final request = c.refresh();
    await api.entered.future;
    s.setSetting('account_signed_out', '1');
    api.held!.complete({
      'items': [event(now)],
      'next': null,
    });
    await request;
    await Future<void>.delayed(Duration.zero);
    expect(native.batches.every((b) => b.isEmpty), isTrue);
    expect(native.clears, greaterThan(0));
  });
  test('permission rejection and per-account preferences do not silently enable alerts', () async {
    final (s, _) = fixture();
    addTearDown(s.close);
    final native = FakeNotifications()..granted = false;
    s.setSetting(
      'reminder_pref_${s.setting('account_identity')}',
      jsonEncode({'enabled': false, 'minutes': 15}),
    );
    final c = ReminderCoordinator(s, platform: native);
    addTearDown(c.dispose);
    await expectLater(c.configure(true, 15), throwsA(isA<DomainError>()));
    s.setSetting(
      'account_identity',
      jsonEncode(['https://fixture.example', 'bob']),
    );
    expect(c.enabled, isFalse);
    await c.refresh();
    expect(native.batches.every((b) => b.isEmpty), isTrue);
  });
  for (final lang in ['ru', 'en']) {
    testWidgets('reminder settings fit 320px $lang', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (s, _) = fixture();
      addTearDown(s.close);
      final api = ReminderApi(), native = FakeNotifications();
      final c = ReminderCoordinator(
        s,
        platform: native,
        clientFactory: (_) => api,
      );
      addTearDown(c.dispose);
      await c.refresh();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ReminderSettings(controller: c)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
