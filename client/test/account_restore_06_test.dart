import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/store.dart';

class RestoreFixture extends AccountClient {
  RestoreFixture() : super('https://fixture.example');
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authorize = true,
  }) async {
    expect(body?['verifier'], 'saved-verifier');
    expect(authorize, isFalse);
    return {'access_token': 'new-session'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cold Android callback requires stored PKCE and restores secure session',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final api = RestoreFixture();
      await api.storage.write(
        key: api.pendingKey,
        value: jsonEncode({
          'verifier': 'saved-verifier',
          'expires': DateTime.now()
              .add(const Duration(minutes: 1))
              .millisecondsSinceEpoch,
        }),
      );
      await api.completeLogin(
        Uri.parse('teamsync://auth/callback?code=${'a' * 43}'),
      );
      final restored = AccountClient(api.base.toString());
      await restored.loadToken();
      expect(restored.token, 'new-session');
      expect(await api.storage.read(key: api.pendingKey), isNull);
      await expectLater(
        api.completeLogin(
          Uri.parse('teamsync://auth/callback?code=${'a' * 43}'),
        ),
        throwsA(isA<DomainError>()),
      );
      for (final url in [
        'teamsync://evil/callback',
        'teamsync://auth:55/callback',
        'teamsync://auth/callback#code=x',
        'https://auth/callback',
      ]) {
        expect(AccountClient.isCallback(Uri.parse(url)), isFalse);
      }
    },
  );
}
