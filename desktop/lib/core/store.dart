import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';
import 'models.dart';

class TaskStore {
  final Database db;
  TaskStore(String path) : db = sqlite3.open(path) {
    db.execute('PRAGMA journal_mode=WAL');
    db.execute(
      'CREATE TABLE IF NOT EXISTS tasks (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, data TEXT NOT NULL)',
    );
    db.execute('PRAGMA user_version=1');
  }
  List<DownloadTask> load() => db
      .select('SELECT data FROM tasks ORDER BY rowid DESC')
      .map((r) => DownloadTask.fromJson(jsonDecode(r['data'])))
      .toList();
  void save(DownloadTask task) => db.execute(
    'INSERT OR REPLACE INTO tasks VALUES (?,?)',
    [task.id, encodeTask(task)],
  );
  void remove(String id) => db.execute('DELETE FROM tasks WHERE id=?', [id]);
  dynamic setting(String key, dynamic fallback) {
    final rows = db.select('SELECT data FROM settings WHERE key=?', [key]);
    return rows.isEmpty ? fallback : jsonDecode(rows.first['data']);
  }

  void set(String key, dynamic value) => db.execute(
    'INSERT OR REPLACE INTO settings VALUES (?,?)',
    [key, jsonEncode(value)],
  );
  void close() => db.close();
}
