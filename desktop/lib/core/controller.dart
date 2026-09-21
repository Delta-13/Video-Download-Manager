import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'store.dart';
import 'cookies.dart';
import 'engines.dart';
import 'native.dart';

final downloadsProvider = ChangeNotifierProvider<DownloadController>(
  (ref) => throw UnimplementedError('Override at startup'),
);

class DownloadController extends ChangeNotifier {
  final TaskStore store;
  final String dataDirectory;
  final EnginePaths paths;
  final bool enableBrowser;
  late final CookieVault cookies = CookieVault(
    store,
    p.join(dataDirectory, 'cookies-temp'),
  );
  late final VideoRunner videos = VideoRunner(paths, cookies);
  late final AriaEngine aria = AriaEngine(paths, dataDirectory);
  final List<DownloadTask> tasks = [];
  final Set<String> selected = {};
  final Set<String> _workers = {};
  final Set<String> _inboxBusy = {};
  final Map<String, DateTime> _lastSaved = {};
  Timer? _timer;
  bool _ticking = false, _closing = false;
  bool ready = false;
  bool initializing = true;
  String? engineError;
  String filter = 'all', search = '';
  String? focused;
  DownloadController(
    this.store,
    this.dataDirectory,
    this.paths, {
    this.enableBrowser = true,
  });
  ThemeMode get themeMode =>
      ThemeMode.values.byName(store.setting('theme', 'system'));
  bool get reduceTransparency => store.setting('reduceTransparency', false);
  int get concurrency => store.setting('concurrency', 3);
  String get directory => store.setting(
    'directory',
    p.join(Platform.environment['USERPROFILE'] ?? dataDirectory, 'Downloads'),
  );
  DownloadOptions defaults() => DownloadOptions(
    directory: directory,
    connections: store.setting('connections', 8),
    fragments: store.setting('fragments', 4),
    speedLimit: store.setting('speedLimit', 0),
  );
  void setting(String key, dynamic value) {
    store.set(key, value);
    notifyListeners();
  }

  List<DownloadTask> get visible => tasks.where((t) {
    final matches = switch (filter) {
      'active' =>
        t.status.active ||
            t.status == TaskStatus.queued ||
            t.status == TaskStatus.seeding ||
            t.status == TaskStatus.awaitingSelection,
      'paused' => t.status == TaskStatus.paused,
      'completed' => t.status == TaskStatus.completed,
      'failed' => t.status == TaskStatus.failed,
      'scheduled' => t.status == TaskStatus.scheduled,
      _ => true,
    };
    return matches &&
        ('${t.title} ${t.host}').toLowerCase().contains(search.toLowerCase());
  }).toList();
  DownloadTask? get detail => tasks.where((t) => t.id == focused).firstOrNull;
  double get totalSpeed => tasks.fold(0, (a, t) => a + t.progress.speed);
  void view(String value) {
    filter = value;
    selected.clear();
    notifyListeners();
  }

  void find(String value) {
    search = value;
    notifyListeners();
  }

  void focus(String? id) {
    focused = id;
    notifyListeners();
  }

  void select(String id, bool value) {
    if (value) {
      selected.add(id);
    } else {
      selected.remove(id);
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    tasks.addAll(store.load());
    for (final task in tasks) {
      if (task.status.active ||
          task.status == TaskStatus.queued ||
          task.status == TaskStatus.seeding) {
        task.status = TaskStatus.paused;
      }
      if (task.requestId?.startsWith('pending:') == true) {
        task.status = TaskStatus.canceled;
      }
      if (task.schedule != null &&
          task.schedule!.next.isBefore(DateTime.now())) {
        task.schedule!.missed = true;
      }
      store.save(task);
    }
    await cookies.clearTemporary();
    if (paths.missing.isNotEmpty) {
      engineError = '缺少引擎：${paths.missing.join('、')}。请重新安装完整安装包。';
    } else {
      try {
        await paths.verify();
        await aria.start();
        ready = true;
      } catch (error) {
        engineError = '下载引擎启动失败：$error';
      }
    }
    final inbox = p.join(dataDirectory, 'inbox');
    await Directory(inbox).create(recursive: true);
    await NativeBridge.restrictFile(inbox);
    if (enableBrowser) {
      await NativeBridge.startInbox(inbox);
    }
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_tick()),
    );
    initializing = false;
    notifyListeners();
  }

  String tempFor(DownloadTask task) =>
      p.join(task.options.directory, '.vdm', task.id);
  Future<void> validateDirectory(String directory) async {
    if (!p.isAbsolute(directory)) {
      throw const FormatException('请选择绝对下载目录');
    }
    final dir = Directory(directory);
    await dir.create(recursive: true);
    final probe = File(p.join(directory, '.vdm-write-${const Uuid().v4()}'));
    await probe.writeAsString('');
    await probe.delete();
  }

  Future<DownloadTask> add(
    String source,
    DownloadOptions options, {
    TaskKind? kind,
    String? title,
    String? identity,
    Schedule? schedule,
    String? requestId,
    bool paused = false,
  }) async {
    source = validateSource(source, allowTorrentFile: true);
    await validateDirectory(options.directory);
    final existing = tasks
        .where(
          (t) =>
              (requestId != null && t.requestId == requestId) ||
              (schedule == null &&
                  t.schedule == null &&
                  (t.identity == (identity ?? source) || t.source == source) &&
                  t.options.contentKey == options.contentKey &&
                  t.status != TaskStatus.canceled),
        )
        .firstOrNull;
    if (existing != null) {
      focused = existing.id;
      notifyListeners();
      return existing;
    }
    final task = DownloadTask(
      id: const Uuid().v4(),
      source: source,
      kind: kind ?? detectKind(source),
      title:
          title ??
          (source.startsWith('magnet:')
              ? Uri.parse(source).queryParameters['dn'] ?? '磁力链接'
              : safeName(p.basename(Uri.tryParse(source)?.path ?? source))),
      options: options.clone(),
      identity: identity ?? source,
      schedule: schedule,
      requestId: requestId,
      status: schedule != null
          ? TaskStatus.scheduled
          : paused
          ? TaskStatus.paused
          : TaskStatus.queued,
    );
    tasks.insert(0, task);
    store.save(task);
    focused = task.id;
    notifyListeners();
    return task;
  }

  void changed(DownloadTask task, {bool force = false}) {
    final now = DateTime.now();
    if (force ||
        !task.status.active ||
        now.difference(_lastSaved[task.id] ?? DateTime(2000)).inSeconds >= 2) {
      store.save(task);
      _lastSaved[task.id] = now;
    }
    if (!_closing) {
      notifyListeners();
    }
  }

  Future<void> _run(DownloadTask task) async {
    _workers.add(task.id);
    task.error = null;
    task.status = TaskStatus.resolving;
    changed(task, force: true);
    try {
      final temp = tempFor(task);
      await Directory(temp).create(recursive: true);
      if (task.status == TaskStatus.paused ||
          task.status == TaskStatus.canceled) {
        return;
      }
      if (task.kind == TaskKind.video) {
        await videos.download(task, temp, changed);
      } else {
        await aria.add(task, temp);
        if (task.status == TaskStatus.paused ||
            task.status == TaskStatus.canceled) {
          if (task.gid != null) {
            await aria.pause(task.gid!);
          }
          return;
        }
        task.status = task.kind == TaskKind.torrent && !task.filesConfirmed
            ? TaskStatus.resolving
            : TaskStatus.downloading;
        changed(task, force: true);
      }
    } catch (error) {
      if (task.status != TaskStatus.paused &&
          task.status != TaskStatus.canceled) {
        task.status = TaskStatus.failed;
        task.error =
            error is StateError &&
                !error.message.toString().startsWith('aria2:')
            ? error.message.toString()
            : classifyError(error.toString());
        task.progress.speed = 0;
        changed(task, force: true);
      }
    } finally {
      _workers.remove(task.id);
    }
  }

  Future<void> _tick() async {
    if (_closing || _ticking) {
      return;
    }
    _ticking = true;
    try {
      await File(
        p.join(dataDirectory, 'inbox', 'heartbeat'),
      ).writeAsString('${DateTime.now().millisecondsSinceEpoch}');
      if (enableBrowser) {
        await _readInbox();
      }
      if (!ready) {
        return;
      }
      for (final task
          in tasks
              .where(
                (t) =>
                    t.requestId?.startsWith('pending:') == true &&
                    t.status != TaskStatus.canceled,
              )
              .toList()) {
        if (DateTime.now().difference(task.created).inSeconds > 35) {
          await cancel(task);
        }
      }
      await _schedules();
      for (final task in tasks.toList()) {
        if (task.kind != TaskKind.video &&
            task.gid != null &&
            (task.status.active ||
                task.status == TaskStatus.awaitingSelection ||
                task.status == TaskStatus.seeding)) {
          await _poll(task);
        }
      }
      var active = tasks.where((t) => t.status.active).length;
      for (final task
          in tasks
              .where((t) => t.status == TaskStatus.queued)
              .toList()
              .reversed) {
        if (active >= concurrency) {
          break;
        }
        if (!_workers.contains(task.id)) {
          active++;
          unawaited(_run(task));
        }
      }
      notifyListeners();
    } finally {
      _ticking = false;
    }
  }

  Future<void> _poll(DownloadTask task) async {
    try {
      var j = await aria.status(task.gid!);
      if ((j['followedBy'] as List?)?.isNotEmpty == true) {
        task.gid = j['followedBy'][0];
        j = await aria.status(task.gid!);
        changed(task, force: true);
      }
      final files = (j['files'] as List? ?? [])
          .map(
            (f) => TorrentFile(
              int.parse(f['index']),
              f['path'],
              int.parse(f['length']),
              f['selected'] == 'true',
            ),
          )
          .toList();
      task.files = files;
      int number(String key) => int.tryParse('${j[key]}') ?? 0;
      task.progress = DownloadProgress(
        received: number('completedLength'),
        total: number('totalLength'),
        speed: number('downloadSpeed').toDouble(),
        upload: number('uploadLength'),
        uploadSpeed: number('uploadSpeed').toDouble(),
        connections: number('connections'),
        ratio: number('completedLength') == 0
            ? 0
            : number('uploadLength') / number('completedLength'),
      );
      final torrent = j['bittorrent'] as Map?;
      if (torrent?['info']?['name'] != null) {
        task.title = torrent!['info']['name'];
      }
      if (task.kind == TaskKind.torrent &&
          !task.filesConfirmed &&
          files.any((f) => f.size > 0) &&
          torrent?['info'] != null) {
        if (j['status'] == 'active' || j['status'] == 'waiting') {
          await aria.pause(task.gid!);
        }
        task.status = TaskStatus.awaitingSelection;
        task.progress.speed = 0;
        changed(task, force: true);
        return;
      }
      if (j['status'] == 'error') {
        throw StateError(j['errorMessage'] ?? 'aria2 error');
      }
      final complete = j['status'] == 'complete';
      final seeding =
          task.kind == TaskKind.torrent &&
          j['seeder'] == 'true' &&
          j['status'] == 'active';
      if (seeding) {
        task.status = TaskStatus.seeding;
      }
      if (complete) {
        if (!task.published) {
          await _publishAria(task, files);
        }
        task.status = TaskStatus.completed;
        task.progress.speed = 0;
        task.progress.uploadSpeed = 0;
      }
      changed(task, force: complete);
    } catch (error) {
      task.status = TaskStatus.failed;
      task.error = classifyError(error.toString());
      task.progress.speed = 0;
      changed(task, force: true);
    }
  }

  Future<void> _publishAria(DownloadTask task, List<TorrentFile> files) async {
    final temp = p.normalize(tempFor(task));
    final chosen = files.where((f) => f.selected).toList();
    if (chosen.isEmpty) {
      throw const FileSystemException('No output');
    }
    // Torrent paths are untrusted metadata. Reject escapes and links before publishing.
    for (final f in chosen) {
      if (!p.isWithin(temp, p.normalize(f.path)) ||
          !File(f.path).existsSync() ||
          FileSystemEntity.isLinkSync(f.path) ||
          !p.isWithin(
            Directory(temp).resolveSymbolicLinksSync(),
            File(f.path).resolveSymbolicLinksSync(),
          )) {
        throw const FileSystemException('Invalid torrent output');
      }
    }
    for (final f in chosen) {
      final relative = p.relative(f.path, from: temp);
      final destination = p.join(task.options.directory, p.dirname(relative));
      final result = await NativeBridge.publish(f.path, destination);
      task.output ??= result;
    }
    task.published = true;
  }

  Future<void> chooseFiles(DownloadTask task, List<int> indexes) async {
    if (indexes.isEmpty ||
        !indexes.every((i) => task.files.any((f) => f.index == i))) {
      throw const FormatException('请至少选择一个文件');
    }
    await aria.rpc('changeOption', [
      task.gid,
      {'select-file': indexes.join(',')},
    ]);
    task.selectedFiles = indexes;
    task.filesConfirmed = true;
    task.status = TaskStatus.queued;
    changed(task, force: true);
  }

  Future<void> pause(DownloadTask task) async {
    if (!task.canPause && task.status != TaskStatus.queued) {
      return;
    }
    task.status = TaskStatus.paused;
    task.progress.speed = 0;
    changed(task, force: true);
    if (task.kind == TaskKind.video) {
      await videos.stop(task.id);
    } else if (task.gid != null) {
      await aria.pause(task.gid!);
    }
  }

  Future<void> resume(DownloadTask task) async {
    if (!task.canResume) {
      return;
    }
    task.error = null;
    task.status = TaskStatus.queued;
    changed(task, force: true);
  }

  Future<void> cancel(DownloadTask task) async {
    task.status = TaskStatus.canceled;
    task.progress.speed = 0;
    task.schedule = null;
    changed(task, force: true);
    if (task.kind == TaskKind.video) {
      await videos.stop(task.id);
    } else if (task.gid != null) {
      try {
        await aria.remove(task.gid!);
      } catch (_) {}
      task.gid = null;
    }
  }

  Future<void> restart(DownloadTask task) async {
    await cancel(task);
    while (_workers.contains(task.id)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final temp = Directory(tempFor(task));
    final root = p.join(task.options.directory, '.vdm');
    if (!p.isWithin(root, temp.path) || p.basename(temp.path) != task.id) {
      throw StateError('Invalid task directory');
    }
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
    task.published = false;
    task.output = null;
    task.filesConfirmed = false;
    task.progress = DownloadProgress();
    await resume(task);
  }

  Future<void> bulk(bool pauseTasks, {bool all = false}) async {
    final targets = tasks
        .where((t) => all || selected.isEmpty || selected.contains(t.id))
        .toList();
    for (final task in targets) {
      if (pauseTasks) {
        await pause(task);
      } else {
        await resume(task);
      }
    }
  }

  Future<void> _schedules() async {
    final now = DateTime.now();
    for (final task
        in tasks.where((t) => t.status == TaskStatus.scheduled).toList()) {
      final schedule = task.schedule;
      if (schedule == null || schedule.missed || schedule.next.isAfter(now)) {
        continue;
      }
      if (now.difference(schedule.next).inMinutes >= 2) {
        schedule.missed = true;
        changed(task, force: true);
        continue;
      }
      await runScheduled(task);
    }
  }

  Future<void> runScheduled(DownloadTask task) async {
    final schedule = task.schedule!;
    if (schedule.repeat == RepeatRule.once) {
      task.schedule = null;
      task.status = TaskStatus.queued;
    } else {
      final run = DownloadTask(
        id: const Uuid().v4(),
        source: task.source,
        kind: task.kind,
        title: task.title,
        options: task.options.clone(),
        identity: '${task.identity}:${schedule.next.toIso8601String()}',
      );
      tasks.insert(0, run);
      store.save(run);
      do {
        schedule.next = schedule.following(schedule.next);
      } while (!schedule.next.isAfter(DateTime.now()));
      schedule.missed = false;
    }
    changed(task, force: true);
  }

  Future<void> _readInbox() async {
    final inbox = Directory(p.join(dataDirectory, 'inbox'));
    await for (final f in inbox.list(followLinks: false)) {
      if (f is! File ||
          !f.path.endsWith('.request') ||
          _inboxBusy.contains(f.path)) {
        continue;
      }
      _inboxBusy.add(f.path);
      unawaited(() async {
        Map<String, dynamic> response;
        try {
          if (await f.length() > 1024 * 1024) {
            throw const FormatException('Message too large');
          }
          final request =
              jsonDecode(await f.readAsString()) as Map<String, dynamic>;
          response = await browserRequest(request);
        } catch (_) {
          response = {'ok': false, 'error': '无法接收任务，请在下载器中检查链接。'};
        }
        try {
          final out = File(
            '${f.path.substring(0, f.path.length - 8)}.response',
          );
          final partial = File('${out.path}.tmp');
          await partial.writeAsString(jsonEncode(response), flush: true);
          await partial.rename(out.path);
          if (await f.exists()) {
            await f.delete();
          }
        } on FileSystemException {
          // The native host times out and the browser resumes its own download.
        } finally {
          _inboxBusy.remove(f.path);
        }
      }());
    }
  }

  Future<Map<String, dynamic>> browserRequest(
    Map<String, dynamic> request,
  ) async {
    if (request['protocolVersion'] != 1 ||
        request['requestId'] is! String ||
        !RegExp(r'^[a-zA-Z0-9-]{8,80}$').hasMatch(request['requestId'])) {
      throw const FormatException('Unsupported browser protocol');
    }
    if (!ready || _closing) {
      return {'ok': false, 'error': engineError};
    }
    final id = request['requestId'] as String;
    final action = request['action'];
    final requests = Map<String, dynamic>.from(
      store.setting('browserRequests', {}),
    );
    DownloadTask? previous() => tasks
        .where(
          (t) =>
              t.id == requests[id] ||
              t.requestId == id ||
              t.requestId == 'pending:$id',
        )
        .firstOrNull;
    if (action == 'ping') {
      return {'ok': true, 'version': '2.0.0'};
    }
    if (action == 'send' || action == 'prepare') {
      final source = validateSource(request['url'] as String);
      final old = previous();
      if (old != null) {
        return {'ok': true, 'taskId': old.id};
      }
      final options = defaults();
      if (request['referer'] is String && request['referer'].isNotEmpty) {
        options.referer = validateSource(request['referer']);
      }
      if (action == 'prepare') {
        if (request['method'] != 'GET') {
          return {'ok': false, 'error': '只能接管 GET 下载'};
        }
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 5);
        try {
          final req = await client.getUrl(Uri.parse(source));
          req.headers.set('Range', 'bytes=0-0');
          if (options.referer != null) {
            req.headers.set('Referer', options.referer!);
          }
          final response = await req.close().timeout(
            const Duration(seconds: 6),
          );
          if (response.statusCode != 200 && response.statusCode != 206 ||
              response.headers.contentType?.mimeType == 'text/html') {
            return {'ok': false, 'error': '无法独立下载，保留浏览器任务'};
          }
          await response.first.timeout(const Duration(seconds: 5));
        } finally {
          client.close(force: true);
        }
      }
      final task = await add(
        source,
        options,
        kind: action == 'prepare' ? TaskKind.file : null,
        title: request['filename'] is String
            ? safeName(p.basename(request['filename']))
            : null,
        requestId: action == 'prepare' ? 'pending:$id' : id,
        paused: action == 'prepare',
      );
      requests[id] = task.id;
      while (requests.length > 2000) {
        requests.remove(requests.keys.first);
      }
      store.set('browserRequests', requests);
      return {'ok': true, 'taskId': task.id};
    }
    final task = previous();
    if (task == null) {
      return {'ok': false, 'error': '任务不存在'};
    }
    if (action == 'abort') {
      // A failed duplicate handoff must not cancel a pre-existing user task.
      if (task.requestId == id || task.requestId == 'pending:$id') {
        await cancel(task);
      }
      return {'ok': true};
    }
    if (action == 'commit') {
      await resume(task);
      for (var i = 0; i < 40; i++) {
        if (_closing) return {'ok': false, 'error': '下载器正在退出'};
        if (task.progress.received > 0 || task.status == TaskStatus.completed) {
          if (task.requestId == 'pending:$id') task.requestId = id;
          changed(task, force: true);
          return {'ok': true, 'taskId': task.id};
        }
        if (task.status == TaskStatus.failed ||
            task.status == TaskStatus.canceled) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (task.requestId == id || task.requestId == 'pending:$id') {
        await cancel(task);
      }
      return {'ok': false, 'error': '下载未启动，恢复浏览器下载'};
    }
    throw const FormatException('Unknown action');
  }

  Future<void> shutdown() async {
    _closing = true;
    _timer?.cancel();
    while (_ticking) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    while (_inboxBusy.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    for (final task in tasks) {
      if (task.status.active || task.status == TaskStatus.seeding) {
        task.status = TaskStatus.paused;
      }
      store.save(task);
    }
    await videos.dispose();
    while (_workers.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await aria.dispose();
    await cookies.clearTemporary();
    store.close();
  }
}
