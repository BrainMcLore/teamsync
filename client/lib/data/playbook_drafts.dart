import 'dart:convert';
import 'dart:io';

import 'store.dart';
import 'playbook.dart';

class PlaybookDrafts {
  final Store store;
  final Directory root;
  final String team;
  PlaybookDrafts(this.store, this.root, this.team);
  String get key => 'playbooks:$team';
  List<Map<String, dynamic>> load() =>
      (jsonDecode(store.setting(key) ?? '[]') as List)
          .cast<Map<String, dynamic>>();
  void save(List<Map<String, dynamic>> books) =>
      store.setSetting(key, jsonEncode(books));
  Map<String, dynamic> create(String title, String roundTitle) {
    final books = load();
    final book = <String, dynamic>{
      'id': Store.uuid.v4(),
      'title': store.requiredText(title),
      'pages': [page(roundTitle)],
    };
    books.add(book);
    save(books);
    return book;
  }

  static Map<String, dynamic> page(String title) => {
    'id': Store.uuid.v4(),
    'title': title,
    'economy': '',
    'plan': '',
    'roles': '',
    'attachments': <dynamic>[],
  };
  Future<void> attach(String bookId, String pageId, String strategyId) async {
    final strategy = store.strategy(strategyId);
    final owner = store
        .maps(team)
        .any((map) => map['id'] == strategy['map_id']);
    if (!owner) throw DomainError('wrongTeam');
    final bytes = await Playbook.snapshot(strategy);
    if (bytes == null) throw DomainError('invalidImage');
    final folder = Directory('${root.path}/playbook-snapshots');
    await folder.create(recursive: true);
    final file = File('${folder.path}/${Store.uuid.v4()}.png');
    await file.writeAsBytes(bytes, flush: true);
    try {
      final books = load();
      final book = books.singleWhere((b) => b['id'] == bookId);
      final page =
          (book['pages'] as List).singleWhere((p) => p['id'] == pageId) as Map;
      (page['attachments'] as List).add({
        'id': Store.uuid.v4(),
        'strategy_id': strategyId,
        'title': strategy['title'],
        'map': strategy['map_name'],
        'side': strategy['side'],
        'version': strategy['version'],
        'level': strategy['level'],
        'notes': strategy['notes'],
        'path': file.path,
        'captured_at': store.now,
      });
      save(books);
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }
}
