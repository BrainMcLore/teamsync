import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/files.dart';
import 'package:teamsync/data/own_video.dart';
import 'package:teamsync/data/store.dart';

void main() {
  test(
    'own clip import validates its video track and commits an immutable copy',
    () async {
      final root = Directory.systemTemp.createTempSync('teamsync_clip_');
      addTearDown(() => root.deleteSync(recursive: true));
      final bytes = await File('test/fixtures/own_clip.mp4').readAsBytes();
      OwnVideo.validate(bytes);
      final target = await OwnVideo.importBytes(LocalFiles(root), bytes);
      expect(await File(target).readAsBytes(), bytes);
      expect(target, startsWith(root.path));
      expect(
        root
            .listSync(recursive: true)
            .where((f) => f.path.endsWith('.partial')),
        isEmpty,
      );
      final bad = Uint8List.fromList(bytes);
      final text = String.fromCharCodes(bad);
      final handler = text.indexOf('vide');
      expect(handler, greaterThan(0));
      bad.setRange(handler, handler + 4, 'soun'.codeUnits);
      for (final input in [
        bad,
        bytes.sublist(0, bytes.length - 1),
        Uint8List.fromList([
          0,
          0,
          0,
          1,
          102,
          116,
          121,
          112,
          ...List.filled(24, 255),
        ]),
      ]) {
        expect(
          () => OwnVideo.validate(input),
          throwsA(
            isA<DomainError>().having((e) => e.code, 'code', 'invalidVideo'),
          ),
        );
      }
    },
  );
}
