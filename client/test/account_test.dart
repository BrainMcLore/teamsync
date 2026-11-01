import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/store.dart';

void main() {
  test('API validates origins', () {
    for (final address in [
      'http://example.com',
      'https://user:pass@example.com',
      'https://example.com/path',
      'https://example.com?token=bad',
      'teamsync://auth',
    ]) {
      expect(() => AccountClient(address), throwsA(isA<DomainError>()));
    }
    expect(
      AccountClient('https://example.com/').base.toString(),
      'https://example.com',
    );
  });
  test('JSON preserves Cyrillic, emoji and byte length', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final payload = {
      'title': 'Выход на А',
      'notes': 'Смок 🟢\nВторой этаж — КТ',
    };
    server.listen((request) async {
      final bytes = await request.fold<List<int>>(
        [],
        (all, part) => all..addAll(part),
      );
      expect(request.contentLength, bytes.length);
      expect(jsonDecode(utf8.decode(bytes)), payload);
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":true}');
      await request.response.close();
    });
    final client = AccountClient('http://127.0.0.1:${server.port}');
    expect(await client.request('POST', '/documents', body: payload), {
      'ok': true,
    });
  });
  test('Bearer scoped and redirects refused', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final authorization = <String?>[];
    server.listen((request) async {
      authorization.add(request.headers.value('Authorization'));
      if (request.uri.path == '/redirect') {
        request.response.statusCode = 302;
        request.response.headers.set('Location', 'http://127.0.0.1:1/stolen');
      } else if (request.uri.path == '/fail') {
        request.response.statusCode = 409;
        request.response.write(
          jsonEncode({
            'error': {'code': 'version_conflict'},
          }),
        );
      } else {
        request.response.write('{"ok":true}');
      }
      await request.response.close();
    });
    final client = AccountClient('http://127.0.0.1:${server.port}')
      ..token = 'test-token';
    expect(await client.request('GET', '/public', authorize: false), {
      'ok': true,
    });
    expect(await client.request('GET', '/private'), {'ok': true});
    await expectLater(
      client.request('GET', '/fail'),
      throwsA(
        isA<DomainError>().having((e) => e.code, 'code', 'version_conflict'),
      ),
    );
    await expectLater(client.request('GET', '/redirect'), throwsA(anything));
    expect(authorization, [
      null,
      'Bearer test-token',
      'Bearer test-token',
      'Bearer test-token',
    ]);
  });
}
