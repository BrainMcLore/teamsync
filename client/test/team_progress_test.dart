import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/team_progress.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/ui/team_progress_dialog.dart';

void main() {
  test(
    'snapshot separates review from accepted work and unfinished deadlines',
    () {
      final now = DateTime.utc(2026, 11, 2, 12);
      final rows = <RecordData>[
        {'member_id': 'a', 'status': 'todo', 'due_at': '2026-11-02T11:59:00Z'},
        {
          'member_id': 'a',
          'status': 'in_progress',
          'due_at': '2026-11-02T12:00:00Z',
        },
        {
          'member_id': 'b',
          'status': 'submitted',
          'due_at': '2026-11-01T00:00:00Z',
        },
        {
          'member_id': 'b',
          'status': 'approved',
          'due_at': '2026-11-01T00:00:00Z',
        },
        {'member_id': null, 'status': 'todo', 'due_at': 'invalid'},
        {'member_id': null, 'status': 'legacy'},
      ];
      final report = TeamProgress(rows, now: now);
      expect(report.overall.total, 6);
      expect(report.overall.overdue, 1);
      expect(report.overall.count('approved'), 1);
      expect(report.overall.count('submitted'), 1);
      expect(report.members['a']!.total, 2);
      expect(report.members['b']!.overdue, 0);
      expect(report.members[null]!.total, 2);
      expect(TeamProgress([], now: now).overall.total, 0);
    },
  );

  for (final language in ['ru', 'en']) {
    testWidgets('progress dialog fits 320px $language with idle members', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = Store(':memory:');
      addTearDown(store.close);
      final team = store.createTeam('Team');
      store.addMember(team, 'Idle teammate', 'player', 'AWP');
      store.createTask(team, 'Unassigned', '');
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TeamProgressDialog(store: store, team: team),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Idle teammate'), findsOneWidget);
    });
  }
}
