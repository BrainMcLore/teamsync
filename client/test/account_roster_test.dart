import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account_roster.dart';
import 'package:teamsync/data/store.dart';

void main() {
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
