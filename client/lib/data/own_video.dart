import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'files.dart';
import 'store.dart';

/// Only explicitly selected local MP4 clips are imported. External videos stay links.
class OwnVideo {
  static const limit = 20 * 1024 * 1024;
  static const channel = MethodChannel('app.teamsync/media');

  static void validate(Uint8List bytes) {
    if (bytes.length < 24 || bytes.length > limit) {
      throw DomainError('invalidVideo');
    }
    final data = ByteData.sublistView(bytes);
    var count = 0,
        hasMovie = false,
        hasData = false,
        hasVideo = false,
        hasType = false;
    String type(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));
    void walk(int start, int end, int depth) {
      var offset = start;
      while (offset < end) {
        if (++count > 2048 || end - offset < 8 || depth > 4) {
          throw DomainError('invalidVideo');
        }
        var size = data.getUint32(offset), header = 8;
        final atom = type(offset + 4);
        if (size == 1) {
          if (end - offset < 16) throw DomainError('invalidVideo');
          size = data.getUint64(offset + 8);
          header = 16;
        } else if (size == 0) {
          size = end - offset;
        }
        if (size < header || size > end - offset) {
          throw DomainError('invalidVideo');
        }
        if (depth == 0) {
          if (offset == 0 && atom == 'ftyp' && size >= 16) hasType = true;
          if (atom == 'moov') hasMovie = true;
          if (atom == 'mdat' && size > header) hasData = true;
        }
        if (['moov', 'trak', 'mdia'].contains(atom)) {
          walk(offset + header, offset + size, depth + 1);
        }
        if (depth == 3 &&
            atom == 'hdlr' &&
            size >= header + 12 &&
            type(offset + header + 8) == 'vide') {
          hasVideo = true;
        }
        offset += size;
      }
    }

    walk(0, bytes.length, 0);
    if (!hasType || !hasMovie || !hasData || !hasVideo) {
      throw DomainError('invalidVideo');
    }
  }

  static Future<String> importBytes(LocalFiles files, Uint8List bytes) async {
    validate(bytes);
    final target = File('${files.root.path}/media/${Store.uuid.v4()}.mp4');
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.partial');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(target.path);
      return target.path;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  static Future<String?> pick(LocalFiles files) async {
    final source = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'MP4',
          extensions: ['mp4'],
          mimeTypes: ['video/mp4'],
          uniformTypeIdentifiers: ['public.mpeg-4'],
        ),
      ],
    );
    if (source == null) return null;
    if (await source.length() > limit) throw DomainError('invalidVideo');
    return importBytes(files, await source.readAsBytes());
  }

  static Future<bool> canOpenOnAndroid(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() > limit) return false;
    validate(await file.readAsBytes());
    if (Platform.isAndroid) {
      return await channel.invokeMethod<bool>('canOpenVideo', {
            'path': file.absolute.path,
          }) ??
          false;
    }
    return false;
  }

  static Future<void> open(String path) async {
    final file = File(path);
    if (!await file.exists()) throw DomainError('fileMissing');
    if (await file.length() > limit) throw DomainError('invalidVideo');
    validate(await file.readAsBytes());
    final opened = Platform.isAndroid
        ? await channel.invokeMethod<bool>('openVideo', {
                'path': file.absolute.path,
              }) ??
              false
        : Platform.isWindows &&
              await launchUrl(
                file.absolute.uri,
                mode: LaunchMode.externalApplication,
              );
    if (!opened) throw DomainError('videoUnavailable');
  }
}
