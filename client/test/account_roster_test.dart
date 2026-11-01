import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account_roster.dart';
import 'package:teamsync/data/store.dart';

void main() {
  test(
    'assignment choices exclude legacy members and another account cache',
    () {
      final store = Store(':memory:');
      addTearDown(store.close);
      final team = saveAccountRoster(
        store,
        'https://fixture.example',
        'alice',
        {'id': 'remote', 'name': 'Team', 'role': 'owner'},
        [
          {'id': 'alice', 'name': 'Alice', 'role': 'owner'},
        ],
      );
      store.addMember(team, 'Legacy offline player', 'player', 'IGL');
      expect(accountAssignableMembers(store, team).map((r) => r['name']), [
        'Alice',
      ]);
      rememberAccountIdentity(store, 'https://fixture.example', 'bob');
      expect(accountAssignableMembers(store, team), isEmpty);
    },
  );

  test('cached teams are isolated across account switches and logout', () {
    final store = Store(':memory:');
    addTearDown(store.close);
    final a = saveAccountRoster(store, 'https://one.example', 'alice', {
      'id': 'remote',
      'name': 'Alice',
    }, []);
    expect(visibleAccountTeams(store).single['id'], a);
    final b = saveAccountRoster(store, 'https://one.example', 'bob', {
      'id': 'remote',
      'name': 'Bob',
    }, []);
    expect(visibleAccountTeams(store).single['id'], b);
    rememberAccountIdentity(store, 'https://two.example', 'alice');
    expect(visibleAccountTeams(store), isEmpty);
    rememberAccountIdentity(store, 'https://one.example', 'alice');
    expect(visibleAccountTeams(store).single['id'], a);
    store.setSetting('account_signed_out', '1');
    expect(visibleAccountTeams(store), isEmpty);
    expect(store.teams, hasLength(2));
  });

  test(
    'account roster keeps stable member ids and separates servers and users',
    () {
      final store = Store(':memory:');
      addTearDown(store.close);
      final team = {'id': 'online-team', 'name': 'Five'};
      final members = [
        {'id': 'owner', 'name': 'Coach', 'role': 'owner'},
        {
          'id': 'player',
          'name': 'Sniper',
          'role': 'player',
          'game_role': 'AWPer',
        },
      ];
      final local = saveAccountRoster(
        store,
        'https://a.example',
        'me',
        team,
        members,
      );
      final original = store
          .members(local)
          .firstWhere((r) => r['name'] == 'Sniper')['id'];
      saveAccountRoster(store, 'https://a.example', 'me', team, [
        members.first,
        {...members.last, 'name': 'New nick'},
      ]);
      expect(
        store.members(local).firstWhere((r) => r['name'] == 'New nick')['id'],
        original,
      );
      final other = saveAccountRoster(
        store,
        'https://a.example',
        'other-account',
        team,
        members,
      );
      expect(other, isNot(local));
      final server = saveAccountRoster(
        store,
        'https://b.example',
        'me',
        team,
        members,
      );
      expect(server, isNot(local));
      saveAccountRoster(store, 'https://a.example', 'me', team, [
        members.first,
      ]);
      expect(store.members(local), hasLength(1));
      expect(store.members(other), hasLength(2));
    },
  );
}
