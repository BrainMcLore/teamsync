import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import 'store.dart';
import 'map_catalog.dart';

class LocalFiles {
  final Directory root;
  LocalFiles(this.root);
  MapCatalog? _catalog;
  MapCatalog? get catalog => _catalog ??= MapCatalog.fromRoot(root);
  Future<String?> importRadar() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'PNG / JPEG',
          extensions: ['png', 'jpg', 'jpeg'],
          uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 20 * 1024 * 1024) {
      throw DomainError('invalidImage');
    }
    final bytes = await file.readAsBytes();
    final png =
        bytes.length > 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpg =
        bytes.length > 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpg) throw DomainError('invalidImage');
    await validateRadar(bytes);
    final target = File(
      '${root.path}/media/${Store.uuid.v4()}.${png ? 'png' : 'jpg'}',
    );
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  static Future<void> validateRadar(Uint8List bytes) async {
    if (bytes.length > 20 * 1024 * 1024) throw DomainError('invalidImage');
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      image = await ui.ImageDescriptor.encoded(buffer);
      if (image.width < 1 ||
          image.height < 1 ||
          image.width > 8192 ||
          image.height > 8192) {
        throw DomainError('invalidImage');
      }
    } catch (_) {
      throw DomainError('invalidImage');
    } finally {
      image?.dispose();
      buffer?.dispose();
    }
  }

  Future<({String name, String path, int size})?> importDemo() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'CS2 .dem',
          extensions: ['dem'],
          uniformTypeIdentifiers: ['public.data'],
        ),
      ],
    );
    if (file == null) return null;
    final size = await file.length();
    if (size < 16 || size > 2 * 1024 * 1024 * 1024) {
      throw DomainError('invalidDemo');
    }
    final header = await file
        .openRead(0, 8)
        .fold<List<int>>([], (a, b) => a..addAll(b));
    if (header.length != 8 || String.fromCharCodes(header) != 'PBDEMS2\u0000') {
      throw DomainError('invalidDemo');
    }
    final target = File('${root.path}/demos/${Store.uuid.v4()}.dem');
    await target.parent.create(recursive: true);
    try {
      final sink = target.openWrite();
      try {
        await sink.addStream(file.openRead());
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (await target.length() != size) throw DomainError('invalidDemo');
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
    return (name: file.name, path: target.path, size: size);
  }
}
