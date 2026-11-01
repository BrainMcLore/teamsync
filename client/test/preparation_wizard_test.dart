import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account_roster.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/ui/preparation_wizard.dart';

void main() {
  for (final lang in ['ru', 'en']) {
    testWidgets('map wizard creates a personal plan at 320px $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = Store(':memory:');
      addTearDown(store.close);
      final team = saveAccountRoster(
        store,
        'https://fixture.example',
        'alice',
        {'id': 'remote', 'name': 'Team', 'role': 'owner'},
        [
          {'id': 'alice', 'name': 'Alice', 'role': 'owner'},
          {'id': 'bob', 'name': 'Bob', 'role': 'player'},
        ],
      );
      final map = store.addMap(team, 'Mirage'),
          tactic = store.createStrategy(map, 'A execute', 'T');
      final bob =
          store.members(team).singleWhere((m) => m['name'] == 'Bob')['id']
              as String;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<int>(
                  context: context,
                  builder: (_) =>
                      PreparationWizard(store: store, team: team, map: map),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(PreparationWizard)),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      expect(find.text(l.prepChooseStrategies), findsOneWidget);
      expect(store.tasks(team), isEmpty);
      await tester.ensureVisible(find.byKey(ValueKey('prep-strategy-$tactic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('prep-strategy-$tactic')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(ValueKey('prep-member-$bob')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('prep-member-$bob')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      expect(find.text(l.prepDeadlineRequired), findsOneWidget);
      expect(store.tasks(team), isEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('prep-deadline')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prep-deadline')));
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
      await tester.ensureVisible(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prep-next')));
      await tester.pumpAndSettle();
      final saved = store.tasks(team).single;
      expect(saved['member_id'], bob);
      expect(saved['strategy_id'], tactic);
      expect(saved['criteria'], l.prepCriteriaRole);
      expect(DateTime.parse(saved['due_at'] as String).isUtc, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
