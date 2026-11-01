import 'dart:convert';

import 'store.dart';

/// Freeze the server/account/team identity across asynchronous requests.
class TeamAccountScope {
  final Store store;
  final String team;
  final Map binding;
  TeamAccountScope(this.store, this.team)
    : binding = jsonDecode(store.setting('account_team_$team')!) as Map;
  void assertActive() {
    if (store.setting('account_team_$team') != jsonEncode(binding) ||
        store.setting('account_signed_out') == '1' ||
        store.setting('account_identity') !=
            jsonEncode([binding['server'], binding['user']])) {
      throw DomainError('syncAccountMismatch');
    }
  }
}
