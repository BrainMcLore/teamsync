// Developer-only entry point for the task-owned emulator. Never used in releases.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isAndroid) {
    throw StateError('QA debug emulator entry only');
  }
  final api = AccountClient('http://127.0.0.1:8766');
  await api.storage.delete(key: api.storageKey);
  final random = Random.secure();
  final verifier = base64UrlEncode(
    List.generate(48, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
  final challenge = base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes)
      .replaceAll('=', '');
  await api.storage.write(
    key: api.pendingKey,
    value: jsonEncode({
      'verifier': verifier,
      'expires': DateTime.now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
    }),
  );
  final root = await getApplicationSupportDirectory();
  final store = Store('${root.path}/teamsync.sqlite');
  store.setSetting('api_url', api.base.toString());
  store.close();
  await File('${root.path}/qa-challenge-06.txt').writeAsString(challenge);
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Cold login QA prepared'))),
    ),
  );
}
