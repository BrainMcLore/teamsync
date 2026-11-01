import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'store.dart';

class AccountClient {
  static const defaultServer = String.fromEnvironment('TEAMSYNC_API_URL');
  static bool loginInProgress = false;
  final Uri base;
  final FlutterSecureStorage storage;
  String? token;
  void Function()? cancelLogin;
  AccountClient(String address, {this.storage = const FlutterSecureStorage()})
    : base = Uri.parse(address.trim().replaceAll(RegExp(r'/+$'), '')) {
    if (base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.path.isNotEmpty ||
        base.host.isEmpty ||
        !(base.scheme == 'https' ||
            base.scheme == 'http' && base.host == '127.0.0.1')) {
      throw DomainError('invalidServer');
    }
  }
  String get storageKey =>
      'session_${sha256.convert(utf8.encode(base.toString()))}';
  Future<void> loadToken() async {
    token = await storage.read(key: storageKey);
  }

  String get pendingKey => '${storageKey}_pending';
  static bool isCallback(Uri uri) =>
      uri.scheme == 'teamsync' &&
      uri.host == 'auth' &&
      uri.path == '/callback' &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      !uri.hasPort;

  Future<void> completeLogin(Uri uri) async {
    if (!isCallback(uri)) throw DomainError('invalid_code');
    final pending = await storage.read(key: pendingKey);
    if (pending == null) throw DomainError('loginTimeout');
    final data = jsonDecode(pending) as Map<String, dynamic>;
    if ((data['expires'] as int) < DateTime.now().millisecondsSinceEpoch) {
      await storage.delete(key: pendingKey);
      throw DomainError('loginTimeout');
    }
    if (uri.queryParameters['error'] != null) {
      await storage.delete(key: pendingKey);
      throw DomainError('loginCancelled');
    }
    final code = uri.queryParameters['code'] ?? '';
    if (!RegExp(r'^[A-Za-z0-9_-]{40,100}$').hasMatch(code)) {
      throw DomainError('invalid_code');
    }
    final result = await request(
      'POST',
      '/api/v1/auth/exchange',
      body: {
        'code': code,
        'verifier': data['verifier'],
        'device': Platform.operatingSystem,
      },
      authorize: false,
    );
    final value = result['access_token'] as String;
    await storage.write(key: storageKey, value: value);
    token = value;
    await storage.delete(key: pendingKey);
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authorize = true,
  }) async {
    final destination = base.resolve(path);
    if (destination.origin != base.origin) throw DomainError('invalidServer');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .openUrl(method, destination)
          .timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      if (authorize && token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.headers.contentType = ContentType.json;
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      var count = 0;
      final data = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        count += chunk.length;
        if (count > 2 * 1024 * 1024) throw DomainError('serverError');
        data.addAll(chunk);
      }
      final result = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DomainError(
          (result['error'] as Map?)?['code'] as String? ?? 'serverError',
        );
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> login(
    String provider,
    String callbackMessage, {
    bool link = false,
  }) async {
    if (loginInProgress) throw DomainError('jobBusy');
    loginInProgress = true;
    final random = Random.secure();
    final verifier = base64UrlEncode(
      List.generate(48, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    final challenge = base64UrlEncode(
      sha256.convert(utf8.encode(verifier)).bytes,
    ).replaceAll('=', '');
    final completed = Completer<String>();
    HttpServer? loopback;
    StreamSubscription<Uri>? subscription;
    final timer = Timer(const Duration(minutes: 3), () {
      if (!completed.isCompleted) {
        completed.completeError(DomainError('loginTimeout'));
      }
    });
    cancelLogin = () {
      if (!completed.isCompleted) {
        completed.completeError(DomainError('loginCancelled'));
      }
    };
    // Attach an error listener immediately, including while the start request runs.
    final codeFuture = completed.future;
    unawaited(codeFuture.then<void>((_) {}, onError: (Object error) {}));
    try {
      String redirect;
      if (Platform.isWindows) {
        loopback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        redirect = 'http://127.0.0.1:${loopback.port}/callback';
        loopback.listen((request) async {
          final code = request.uri.queryParameters['code'];
          if (request.uri.path == '/callback' &&
              request.uri.queryParameters['error'] != null) {
            if (!completed.isCompleted) {
              completed.completeError(DomainError('loginCancelled'));
            }
            request.response.write(callbackMessage);
          } else if (request.uri.path != '/callback' ||
              code == null ||
              !RegExp(r'^[A-Za-z0-9_-]{40,100}$').hasMatch(code)) {
            request.response.statusCode = 400;
          } else {
            request.response.headers.contentType = ContentType.text;
            request.response.headers.set('Cache-Control', 'no-store');
            request.response.write(callbackMessage);
            if (!completed.isCompleted) completed.complete(code);
          }
          await request.response.close();
        });
      } else {
        redirect = 'teamsync://auth/callback';
        subscription = AppLinks().uriLinkStream.listen((uri) {
          if (isCallback(uri)) {
            if (uri.queryParameters['error'] != null &&
                !completed.isCompleted) {
              completed.completeError(DomainError('loginCancelled'));
              return;
            }
            final code = uri.queryParameters['code'];
            if (code != null &&
                RegExp(r'^[A-Za-z0-9_-]{40,100}$').hasMatch(code) &&
                !completed.isCompleted) {
              completed.complete(code);
            }
          }
        });
      }
      final start = await request(
        'POST',
        link
            ? '/api/v1/me/identities/$provider/start'
            : '/api/v1/auth/$provider/start',
        body: {'redirect': redirect, 'challenge': challenge},
        authorize: link,
      );
      if (!Platform.isWindows) {
        await storage.write(
          key: pendingKey,
          value: jsonEncode({
            'verifier': verifier,
            'expires': DateTime.now()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          }),
        );
      }
      final uri = Uri.parse(start['url'] as String);
      if (uri.scheme != 'https' ||
          !['steamcommunity.com', 'discord.com'].contains(uri.host)) {
        throw DomainError('serverError');
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw DomainError('serverError');
      }
      final code = await codeFuture;
      final result = await request(
        'POST',
        '/api/v1/auth/exchange',
        body: {
          'code': code,
          'verifier': verifier,
          'device': Platform.operatingSystem,
        },
        authorize: false,
      );
      final newToken = result['access_token'] as String;
      await storage.write(key: storageKey, value: newToken);
      token = newToken;
    } finally {
      timer.cancel();
      cancelLogin = null;
      loginInProgress = false;
      await subscription?.cancel();
      await loopback?.close(force: true);
      await storage.delete(key: pendingKey);
    }
  }

  Future<void> logout() async {
    try {
      if (token != null) await request('POST', '/api/v1/auth/logout');
    } finally {
      await storage.delete(key: storageKey);
      await storage.delete(key: pendingKey);
      token = null;
    }
  }

  Future<Uint8List> media(
    String method,
    String path, {
    Uint8List? bytes,
  }) async {
    final uri = base.resolve(path);
    if (uri.origin != base.origin || token == null) {
      throw DomainError('unauthorized');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 25));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (bytes != null) {
        if (bytes.length > 20 * 1024 * 1024) throw DomainError('limit');
        request.headers.contentType = ContentType.binary;
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      final result = BytesBuilder(copy: false);
      var length = 0;
      await for (final part in response.timeout(const Duration(seconds: 30))) {
        length += part.length;
        if (length > 20 * 1024 * 1024) throw DomainError('limit');
        result.add(part);
      }
      final data = result.takeBytes();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String code = 'serverError';
        try {
          code =
              (jsonDecode(utf8.decode(data)) as Map)['error']['code'] as String;
        } catch (_) {}
        throw DomainError(code);
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }
}
