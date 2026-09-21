import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'native.dart';
import 'store.dart';

class CookieVault {
  final TaskStore store;
  final String directory;
  CookieVault(this.store, this.directory);
  Map<String, dynamic> get entries =>
      Map<String, dynamic>.from(store.setting('cookies', {}));
  String? keyFor(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    final keys =
        entries.keys.where((k) => host == k || host.endsWith('.$k')).toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    return keys.isEmpty ? null : keys.first;
  }

  Future<void> import(String domain, String filename) async {
    domain = domain.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    if (!RegExp(
      r'^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}$',
    ).hasMatch(domain)) {
      throw const FormatException('请输入站点域名，例如 youtube.com');
    }
    final file = File(filename);
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('Cookies 文件过大');
    }
    final text = await file.readAsString();
    final lines = text
        .split('\n')
        .where(
          (l) =>
              l.startsWith('#HttpOnly_') ||
              (!l.startsWith('#') && l.trim().isNotEmpty),
        );
    final selected = <String>[];
    for (final line in lines) {
      final fields = line.replaceFirst('#HttpOnly_', '').split('\t');
      if (fields.length != 7) {
        throw const FormatException('请选择 Netscape 格式的 cookies.txt');
      }
      final host = fields.first.replaceFirst(RegExp(r'^\.'), '').toLowerCase();
      if (host == domain || host.endsWith('.$domain')) {
        selected.add(line);
      }
    }
    if (selected.isEmpty) {
      throw const FormatException('文件中没有此域名的 Cookies');
    }
    final protected = await NativeBridge.protect(
      utf8.encode('# Netscape HTTP Cookie File\n${selected.join('\n')}\n'),
    );
    store.set('cookies', entries..[domain] = base64Encode(protected));
  }

  void remove(String domain) => store.set('cookies', entries..remove(domain));
  Future<File?> materialize(String url) async {
    final key = keyFor(url);
    if (key == null) {
      return null;
    }
    await Directory(directory).create(recursive: true);
    await NativeBridge.restrictFile(directory);
    final data = await NativeBridge.unprotect(base64Decode(entries[key]));
    final file = File(p.join(directory, '${const Uuid().v4()}.txt'));
    await file.create();
    await NativeBridge.restrictFile(file.path);
    await file.writeAsBytes(data, flush: true);
    return file;
  }

  Future<void> clearTemporary() async {
    final dir = Directory(directory);
    if (await dir.exists()) {
      await for (final file in dir.list(followLinks: false)) {
        if (file is File && p.extension(file.path) == '.txt') {
          await file.delete();
        }
      }
    }
  }
}
