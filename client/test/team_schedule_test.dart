import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/team_schedule.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/ui/schedule_page.dart';

Map<String, dynamic> eventData(
  String id, {
  String title = 'Practice',
  int version = 1,
}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day + 1, 18);
  return {
    'id': id,
    'version': version,
    'title': title,
    'notes': 'Timing and utility',
    'location': 'Practice server',
    'kind': 'practice',
    'starts_at': start.toUtc().toIso8601String(),
    'ends_at': start.add(const Duration(hours: 2)).toUtc().toIso8601String(),
    'status': 'scheduled',
    'reason': '',
  };
}

Map<String, dynamic> eventBody(String title) =>
    {...eventData(Store.uuid.v4(), title: title), 'expected_version': 0}
      ..remove('id')
      ..remove('version');

class ScheduleApi extends AccountClient {
  ScheduleApi() : super('https://fixture.example');
  final operations = <String, Map<String, dynamic>>{},
      events = <String, Map<String, dynamic>>{};
  bool offline = false, loseAck = false;
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
    if (offline) throw DomainError('offline');
    if (held != null) {
      if (!entered.isCompleted) entered.complete();
      return held!.future;
    }
    if (method == 'GET') {
      if (path.contains('/history')) return {'items': []};
      if (path.contains('/participation?')) {
        return {
          'event': events.values.first,
          'items': [
            {
              'user_id': 'alice',
              'name': 'Alice',
              'role': 'owner',
              'active': true,
              'version': 0,
              'rsvp': 'unknown',
              'attendance': 'unmarked',
              'reason': '',
              'recorded_by_name': null,
            },
          ],
          'next': null,
        };
      }
      return {'items': events.values.toList(), 'next': null};
    }
    if (body!['title'] == 'Conflict') throw DomainError('version_conflict');
    final id = body['operation_id'] as String;
    final result = operations.putIfAbsent(
      id,
      () =>
          {
              'id': path.split('/').last,
              ...body,
              'version': (body['expected_version'] as int) + 1,
            }
            ..remove('operation_id')
            ..remove('expected_version'),
    );
    events[result['id'] as String] = result;
    if (loseAck) {
      loseAck = false;
      throw DomainError('offline');
    }
    return result;
  }
}

(Store, String) fixture() {
  final s = Store(':memory:'), team = Store.uuid.v4();
  s.setSetting(
    'account_team_$team',
    jsonEncode({
      'server': 'https://fixture.example',
      'team': 'remote-team',
      'user': 'alice',
    }),
  );
  s.setSetting(
    'account_identity',
    jsonEncode(['https://fixture.example', 'alice']),
  );
  s.setSetting('shared_role_$team', 'owner');
  return (s, team);
}

void main() {
  test(
    'schedule mutation survives a lost acknowledgement and reopening',
    () async {
      final (s, team) = fixture();
      addTearDown(s.close);
      final api = ScheduleApi()..loseAck = true;
      var service = TeamSchedule(s, team, clientFactory: (_) => api);
      final id = Store.uuid.v4();
      service.enqueue(id, eventBody('Practice'), 'Practice');
      final operation =
          (service.pending().single['body'] as Map)['operation_id'];
      await expectLater(service.flush(), throwsA(isA<DomainError>()));
      service = TeamSchedule(s, team, clientFactory: (_) => api);
      expect(
        (service.pending().single['body'] as Map)['operation_id'],
        operation,
      );
      await service.flush();
      expect(api.operations, hasLength(1));
      expect(service.pending(), isEmpty);
      expect(service.cached().single['id'], id);
    },
  );
  test(
    'one conflict preserves its local copy without blocking other events',
    () async {
      final (s, team) = fixture();
      addTearDown(s.close);
      final api = ScheduleApi();
      final service = TeamSchedule(s, team, clientFactory: (_) => api);
      service.enqueue(
        Store.uuid.v4(),
        eventBody('Conflict'),
        'Keep this title',
      );
      service.enqueue(Store.uuid.v4(), eventBody('Valid'), 'Valid');
      await service.flush();
      expect(service.pending().single['error'], 'version_conflict');
      expect((service.pending().single['body'] as Map)['title'], 'Conflict');
      expect(service.cached().single['title'], 'Valid');
      final op =
          (service.pending().single['body'] as Map)['operation_id'] as String;
      service.discard(op);
      expect(service.pending(), isEmpty);
      s.setSetting('shared_role_$team', 'viewer');
      expect(
        () => service.enqueue('x', eventBody('No'), 'No'),
        throwsA(isA<DomainError>()),
      );
      s.setSetting('shared_role_$team', 'player');
      expect(
        () => service.enqueue(
          'x',
          {'attendance': 'present', 'expected_version': 0},
          'No',
          target: 'alice',
        ),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => service.enqueue(
          'x',
          {'rsvp': 'going', 'expected_version': 0},
          'No',
          target: 'bob',
        ),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test('late results cannot enter another account cache or acknowledge its predecessor queue', () async {
    final (s, team) = fixture();
    addTearDown(s.close);
    final api = ScheduleApi()..held = Completer<Map<String, dynamic>>();
    final service = TeamSchedule(s, team, clientFactory: (_) => api);
    service.enqueue(Store.uuid.v4(), eventBody('Pending'), 'Pending');
    final future = service.flush();
    await api.entered.future;
    s.setSetting(
      'account_identity',
      jsonEncode(['https://fixture.example', 'bob']),
    );
    api.held!.complete(eventData('event'));
    await expectLater(future, throwsA(isA<DomainError>()));
    expect(s.setting('${service.key}_events'), isNull);
    expect(
      jsonDecode(s.setting('${service.key}_queue')!) as List,
      hasLength(1),
    );
    expect(() => service.cached(), throwsA(isA<DomainError>()));
  });
  test('older cached versions cannot overwrite newer event data', () {
    final (s, team) = fixture();
    addTearDown(s.close);
    final service = TeamSchedule(s, team);
    service.merge(
      '_events',
      [eventData('e', title: 'New', version: 3)],
      'id',
      200,
    );
    service.merge(
      '_events',
      [eventData('e', title: 'Old', version: 2)],
      'id',
      200,
    );
    expect(service.cached().single['title'], 'New');
  });
  for (final lang in ['ru', 'en']) {
    testWidgets('schedule and event form fit 320px $lang', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (s, team) = fixture();
      addTearDown(s.close);
      final api = ScheduleApi()..offline = true;
      final service = TeamSchedule(s, team, clientFactory: (_) => api);
      service.merge('_events', [eventData('e')], 'id', 200);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SchedulePage(store: s, team: team, service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Practice server'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final l = AppLocalizations.of(tester.element(find.byType(SchedulePage)));
      await tester.tap(find.text(l.scheduleNew));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('event-title')),
        'Team dry run',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('event-save')));
      await tester.tap(find.byKey(const ValueKey('event-save')));
      await tester.pumpAndSettle();
      expect(service.pending(), hasLength(1));
      final body = service.pending().single['body'] as Map;
      expect((body['starts_at'] as String).endsWith('Z'), isTrue);
      expect(body['title'], 'Team dry run');
      expect(tester.takeException(), isNull);
      api.offline = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(service.pending(), isEmpty);
      expect(api.operations, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('attendance correction requires a reason $lang', (
      tester,
    ) async {
      Map<String, String>? result;
      final event = eventData('e')
        ..['starts_at'] = DateTime.now()
            .subtract(const Duration(days: 1))
            .toUtc()
            .toIso8601String();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Map<String, String>>(
                    context: context,
                    builder: (_) => AttendanceForm(
                      row: {'name': 'Alice', 'attendance': 'present'},
                      event: event,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AttendanceForm)),
      );
      await tester.tap(find.byKey(const ValueKey('attendance-state')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.attendanceLate).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attendance-save')));
      await tester.pumpAndSettle();
      expect(find.text(l.scheduleCorrectReason), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('attendance-reason')),
        'Ten minutes late',
      );
      await tester.tap(find.byKey(const ValueKey('attendance-save')));
      await tester.pumpAndSettle();
      expect(result, {'attendance': 'late', 'reason': 'Ten minutes late'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('attendance shows RSVP separately from factual status $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (s, team) = fixture();
      addTearDown(s.close);
      final api = ScheduleApi();
      final event = eventData('e');
      api.events['e'] = event;
      final service = TeamSchedule(s, team, clientFactory: (_) => api);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ScheduleAttendance(schedule: service, event: event),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(ScheduleAttendance)),
      );
      expect(find.text('${l.scheduleReply}: ${l.rsvpUnknown}'), findsOneWidget);
      expect(
        find.text('${l.scheduleRecord}: ${l.attendanceUnmarked}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
