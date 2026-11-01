import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

import 'store.dart';

class MapCatalog {
  final Directory folder;
  final Map<String, dynamic> manifest;
  MapCatalog(this.folder, this.manifest);
  List<Map<String, dynamic>> get maps =>
      (manifest['maps'] as List).cast<Map<String, dynamic>>();
  static Future<MapCatalog> install(Directory root) async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/maps/manifest.json'),
    ) as Map<String, dynamic>;
    final folder = Directory('${root.path}/catalog/${manifest['revision']}');
    await folder.create(recursive: true);
    for (final asset in (manifest['sha256'] as Map).keys.cast<String>()) {
      final file = File('${folder.path}/$asset');
      if (!await file.exists() ||
          sha256.convert(await file.readAsBytes()).toString() !=
              (manifest['sha256'] as Map)[asset]) {
        final data = await rootBundle.load('assets/maps/$asset');
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
    }
    final catalog = MapCatalog(folder, manifest);
    await File('${root.path}/catalog/current.json').writeAsString(
      jsonEncode({'folder': folder.path, 'manifest': manifest}),
      flush: true,
    );
    return catalog;
  }

  static MapCatalog? fromRoot(Directory root) {
    final file = File('${root.path}/catalog/current.json');
    if (!file.existsSync()) return null;
    final value = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return MapCatalog(
      Directory(value['folder'] as String),
      value['manifest'] as Map<String, dynamic>,
    );
  }

  String path(String asset) => '${folder.path}/${asset.split('/').last}';
  late final Map<String, Map<String, dynamic>> _byKey = {
    for (final map in maps) map['key'] as String: map,
  };
  Map<String, dynamic>? find(String key) => _byKey[key];
  String radar(Map<String, dynamic> map, [String level = 'default']) => path(
    ((map['levels'] as List).firstWhere(
          (l) => l['key'] == level,
          orElse: () => map['levels'][0],
        ) as Map)['asset']
        as String,
  );
  String? thumbnail(String key) {
    final map = find(key);
    return map?['thumbnail'] == null ? null : path(map!['thumbnail'] as String);
  }

  void ensureTeam(Store store, String team) {
    store.transaction(() {
      for (final map in maps) {
        final existing = store
            .maps(team)
            .where(
              (m) =>
                  m['catalog_id'] == map['key'] ||
                  m['name'] == map['name'] ||
                  m['name'] == map['key'],
            )
            .firstOrNull;
        final id =
            existing?['id'] as String? ??
            store.addMap(team, map['name'] as String);
        store.db.execute(
          'UPDATE maps SET catalog_id=?,image_path=COALESCE(image_path,?),lower_image_path=COALESCE(lower_image_path,?) WHERE id=?',
          [
            map['key'],
            radar(map),
            (map['levels'] as List).length > 1 ? radar(map, 'lower') : null,
            id,
          ],
        );
      }
    });
  }

  Offset worldToRadar(String key, num x, num y) {
    final calibration = find(key)?['calibration'] as Map?;
    if (calibration == null) throw DomainError('unknownCalibration');
    final scale = (calibration['scale'] as num).toDouble() * 1024;
    return Offset(
      (x - (calibration['pos_x'] as num)) / scale,
      ((calibration['pos_y'] as num) - y) / scale,
    );
  }

  String levelFor(String key, num z) {
    final sections =
        (find(key)?['calibration'] as Map?)?['verticalsections'] as Map?;
    if (sections == null) return 'default';
    for (final entry in sections.entries) {
      final section = entry.value as Map;
      if (z >= (section['AltitudeMin'] as num) &&
          z < (section['AltitudeMax'] as num)) {
        return entry.key as String;
      }
    }
    return 'default';
  }
}
