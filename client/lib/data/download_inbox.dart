import 'dart:io';

/// Observes only files completed after opting in; never modifies browser files.
class DownloadInbox {
  final Directory folder;
  final Set<String> baseline;
  final Set<String> handled = {};
  final Map<String, (int, DateTime)> _stable = {};
  DownloadInbox._(this.folder, this.baseline);
  static Future<DownloadInbox> open(Directory folder) async {
    return DownloadInbox._(folder, {
      await for (final entry in folder.list()) entry.path,
    });
  }

  Future<File?> next({DateTime? now}) async {
    now ??= DateTime.now();
    if (!await folder.exists()) return null;
    final files = await folder.list().toList();
    for (final entry in files) {
      if (entry is! File ||
          baseline.contains(entry.path) ||
          handled.contains(entry.path) ||
          !RegExp(
            r'\.(dem|rar|zip)$',
            caseSensitive: false,
          ).hasMatch(entry.path)) {
        continue;
      }
      if (await File('${entry.path}.crdownload').exists() ||
          await File('${entry.path}.part').exists()) {
        continue;
      }
      final stat = await entry.stat();
      if (stat.size < 16 || stat.size > 2 * 1024 * 1024 * 1024) continue;
      final previous = _stable[entry.path];
      if (previous == null || previous.$1 != stat.size) {
        _stable[entry.path] = (stat.size, now);
      } else if (now.difference(previous.$2) >= const Duration(seconds: 10)) {
        handled.add(entry.path);
        return entry;
      }
    }
    return null;
  }
}
