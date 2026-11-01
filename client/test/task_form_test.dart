import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/account_roster.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/ui/task_form.dart';

void main() {
  for (final lang in ['ru', 'en']) {
    testWidgets(
      'legacy assignment can select an account without losing task data $lang',
      (tester) async {
        final store = Store(':memory:');
        addTearDown(store.close);
        final team = saveAccountRoster(
          store,
          'https://fixture.example',
          'alice',
          {'id': Store.uuid.v4(), 'name': 'Five', 'role': 'owner'},
          [
            {'id': 'alice', 'name': 'Alice', 'role': 'owner'},
          ],
        );
        final legacy = store.addMember(team, 'Old player', 'player', 'entry');
        final task = store.createTask(
          team,
          'Legacy task',
          'Preserved',
          member: legacy,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TaskForm(
                store: store,
                team: team,
                value: store.tasks(team).single,
              ),
            ),
          ),
        );
        final l = AppLocalizations.of(tester.element(find.byType(TaskForm)));
        expect(find.text(l.taskUnlinkedAssignee), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('task-member')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alice').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('task-save')));
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
        final saved = store.tasks(team).single;
        expect(saved['id'], task);
        expect(saved['notes'], 'Preserved');
        expect(
          saved['member_id'],
          accountAssignableMembers(store, team).single['id'],
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'assignment form saves criteria and a picked deadline at 320px $lang',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = Store(':memory:');
        addTearDown(store.close);
        final team = store.createTeam('Task form');
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<String>(
                    context: context,
                    builder: (_) => TaskForm(store: store, team: team),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('task-title')),
          'Retake plan',
        );
        await tester.ensureVisible(find.byKey(const ValueKey('task-deadline')));
        await tester.tap(find.byKey(const ValueKey('task-deadline')));
        await tester.pumpAndSettle();
        final dateLabels = MaterialLocalizations.of(
          tester.element(find.byType(DatePickerDialog)),
        );
        await tester.tap(find.text(dateLabels.okButtonLabel));
        await tester.pumpAndSettle();
        final timeLabels = MaterialLocalizations.of(
          tester.element(find.byType(TimePickerDialog)),
        );
        await tester.tap(find.text(timeLabels.okButtonLabel));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('task-criteria')));
        await tester.enterText(
          find.byKey(const ValueKey('task-criteria')),
          'Три синхронных ретейка / Three coordinated retakes',
        );
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
        final saved = store.tasks(team).single;
        expect(saved['title'], 'Retake plan');
        expect(
          saved['criteria'],
          'Три синхронных ретейка / Three coordinated retakes',
        );
        expect(DateTime.parse(saved['due_at'] as String).isUtc, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'editing an assignment plan preserves progress and assignment $lang',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = Store(':memory:');
        addTearDown(store.close);
        final team = store.createTeam('Plan'),
            member = store.addMember(team, 'Player', 'player', 'IGL');
        final task = store.createTask(
          team,
          'Keep this title',
          'Keep notes',
          member: member,
          taskType: 'retake',
          dueAt: DateTime.utc(2026, 11, 2, 18),
          criteria: 'Old criteria',
        );
        store.transitionTask(task, 'submitted');
        store.transitionTask(task, 'todo', reason: 'Repeat timing');
        store.transitionTask(task, 'in_progress');
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<String>(
                    context: context,
                    builder: (_) => TaskForm(
                      store: store,
                      team: team,
                      value: store.tasks(team).single,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('task-title')), findsNothing);
        final l = AppLocalizations.of(tester.element(find.byType(TaskForm)));
        await tester.ensureVisible(find.byTooltip(l.taskClearDeadline));
        await tester.tap(find.byTooltip(l.taskClearDeadline));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('task-criteria')));
        await tester.enterText(
          find.byKey(const ValueKey('task-criteria')),
          'New coordinated timing',
        );
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
        final saved = store.tasks(team).single;
        expect(saved['title'], 'Keep this title');
        expect(saved['notes'], 'Keep notes');
        expect(saved['member_id'], member);
        expect(saved['status'], 'in_progress');
        expect(saved['review_reason'], 'Repeat timing');
        expect(saved['criteria'], 'New coordinated timing');
        expect(saved['due_at'], isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('an open task plan cannot be saved after switching accounts', (
    tester,
  ) async {
    final store = Store(':memory:');
    addTearDown(store.close);
    final team = saveAccountRoster(store, 'https://fixture.example', 'alice', {
      'id': 'remote',
      'name': 'Team',
      'role': 'owner',
    }, []);
    final task = store.createTask(team, 'Existing', '', criteria: 'Original');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => TaskForm(
                  store: store,
                  team: team,
                  value: store.tasks(team).single,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('task-criteria')));
    await tester.enterText(
      find.byKey(const ValueKey('task-criteria')),
      'Wrong account edit',
    );
    rememberAccountIdentity(store, 'https://fixture.example', 'bob');
    await tester.tap(find.byKey(const ValueKey('task-save')));
    await tester.pumpAndSettle();
    expect(store.tasks(team).single['id'], task);
    expect(store.tasks(team).single['criteria'], 'Original');
    expect(find.byType(TaskForm), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
