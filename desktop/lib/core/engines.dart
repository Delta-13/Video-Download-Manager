import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'models.dart';
import 'cookies.dart';
import 'native.dart';

typedef TaskChanged = void Function(DownloadTask task);

class EnginePaths {
  final String directory;
  EnginePaths(this.directory);
  String binary(String name) => p.join(directory, '$name.exe');
  static EnginePaths discover() {
    final bundled = p.join(p.dirname(Platform.resolvedExecutable), 'engines');
    return EnginePaths(bundled);
  }

  Future<void> verify() async {
    final manifest =
        jsonDecode(
              await File(p.join(directory, 'assets.lock.json')).readAsString(),
            )
            as Map;
    for (final entry in (manifest['files'] as List).where(
      (e) => (e['path'] as String).startsWith('engines/'),
    )) {
      final filename = p.basename(entry['path']);
      final actual = await sha256
          .bind(File(p.join(directory, filename)).openRead())
          .first;
      if (actual.toString() != entry['sha256']) {
        throw StateError('引擎校验失败：$filename，请重新安装完整安装包。');
      }
    }
  }

  List<String> get missing => [
    'yt-dlp',
    'aria2c',
    'ffmpeg',
    'ffprobe',
    'deno',
  ].where((n) => !File(binary(n)).existsSync()).toList();
  Map<String, String> get versions {
    final file = File(p.join(directory, 'assets.lock.json'));
    if (!file.existsSync()) {
      return {};
    }
    final data = jsonDecode(file.readAsStringSync())['downloads'] as Map;
    return data.map((k, v) => MapEntry(k.toString(), v['version'].toString()));
  }
}

class ManagedProcess {
  final Process process;
  ManagedProcess(this.process);
  static Future<ManagedProcess> start(
    String executable,
    List<String> args,
  ) async {
    final process = await Process.start(
      executable,
      args,
      runInShell: false,
      environment: {'PYTHONIOENCODING': 'utf-8', 'NO_COLOR': '1'},
    );
    try {
      await NativeBridge.attach(process.pid);
    } catch (_) {
      process.kill();
      rethrow;
    }
    return ManagedProcess(process);
  }

  Future<void> stop() async {
    await NativeBridge.terminate(process.pid);
  }

  Future<int> get exitCode async {
    final code = await process.exitCode;
    await NativeBridge.release(process.pid);
    return code;
  }
}

List<String> videoArguments(
  DownloadTask task,
  EnginePaths paths,
  String temp,
  String? cookies,
) {
  final o = task.options;
  final audio = o.audioLanguage == null
      ? 'ba'
      : 'ba[language=${o.audioLanguage}]/ba';
  final format = o.audioOnly
      ? '$audio/b'
      : o.formatId ??
            '${o.height == null ? 'bv' : 'bv[height<=${o.height}]'}+($audio)/b${o.height == null ? '' : '[height<=${o.height}]'}';
  return [
    '--ignore-config',
    '--no-playlist',
    '--no-colors',
    '--newline',
    '--progress',
    '--no-simulate',
    '--windows-filenames',
    '--continue',
    '--no-overwrites',
    '--socket-timeout',
    '30',
    '--retries',
    '5',
    '--fragment-retries',
    '5',
    '--abort-on-unavailable-fragments',
    '--concurrent-fragments',
    '${o.fragments}',
    '--ffmpeg-location',
    paths.directory,
    '--js-runtimes',
    'deno:${paths.binary('deno')}',
    '--downloader',
    'http,https:${paths.binary('aria2c')}',
    '--downloader',
    'dash,m3u8:native',
    '--downloader-args',
    'aria2c:-x${o.connections} -s${o.connections} -j1 --summary-interval=1 --enable-color=false --human-readable=false --truncate-console-readout=false',
    '--paths',
    temp,
    '--output',
    '%(title).120B [%(id)s].%(ext)s',
    '--format',
    format,
    '--progress-template',
    'download:VDM_PROGRESS:%(progress)j',
    '--progress-template',
    'postprocess:VDM_POST:%(progress)j',
    '--print',
    'after_move:VDM_FILE:%(filepath)j',
    '--print',
    'before_dl:VDM_INFO:{"title":%(title)j,"id":%(id)j,"extractor":%(extractor_key)j}',
    if (o.audioOnly) ...['--extract-audio', '--audio-format', 'mp3'],
    if (!o.audioOnly) ...['--merge-output-format', 'mp4/mkv'],
    if (o.subtitle != null) ...[
      o.automaticSubtitle ? '--write-auto-subs' : '--write-subs',
      '--sub-langs',
      o.subtitle!,
      '--convert-subs',
      o.subtitleFormat,
    ],
    if (o.speedLimit > 0) ...['--limit-rate', '${o.speedLimit}'],
    if (cookies != null) ...['--cookies', cookies],
    '--',
    task.source,
  ];
}

DownloadProgress? parseAriaProgress(String line) {
  final m = RegExp(
    r'\[#[a-zA-Z0-9]+\s+(\d+)B/(\d+)B(?:\([^)]*\))?.*?CN:(\d+).*?DL:(\d+)B',
  ).firstMatch(line);
  if (m == null) {
    return null;
  }
  return DownloadProgress(
    received: int.parse(m[1]!),
    total: int.parse(m[2]!),
    connections: int.parse(m[3]!),
    speed: double.parse(m[4]!),
  );
}

class VideoRunner {
  final EnginePaths paths;
  final CookieVault cookies;
  final Map<String, ManagedProcess> running = {};
  final Set<String> stopped = {};
  VideoRunner(this.paths, this.cookies);
  Future<VideoInfo> inspect(String source, String inspectionId) async {
    final cookie = await cookies.materialize(source);
    try {
      final worker = await ManagedProcess.start(paths.binary('yt-dlp'), [
        '--ignore-config',
        '--dump-single-json',
        '--flat-playlist',
        '--skip-download',
        '--no-warnings',
        '--socket-timeout',
        '25',
        '--retries',
        '2',
        '--js-runtimes',
        'deno:${paths.binary('deno')}',
        if (cookie != null) ...['--cookies', cookie.path],
        '--',
        source,
      ]);
      running[inspectionId] = worker;
      final stdout = worker.process.stdout.transform(utf8.decoder).join();
      final stderr = worker.process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      final code = await worker.exitCode;
      final out = await stdout;
      final err = await stderr;
      if (code != 0) {
        throw StateError(classifyError(err));
      }
      return VideoInfo(jsonDecode(out) as Map<String, dynamic>);
    } finally {
      running.remove(inspectionId);
      if (cookie != null && await cookie.exists()) {
        await cookie.delete();
      }
    }
  }

  Future<void> download(
    DownloadTask task,
    String temp,
    TaskChanged changed,
  ) async {
    stopped.remove(task.id);
    final cookie = await cookies.materialize(task.source);
    final finalFiles = <String>[];
    var failure = '';
    try {
      final worker = await ManagedProcess.start(
        paths.binary('yt-dlp'),
        videoArguments(task, paths, temp, cookie?.path),
      );
      running[task.id] = worker;
      if (stopped.contains(task.id)) {
        await worker.stop();
        await worker.exitCode;
        return;
      }
      void read(String line) {
        if (stopped.contains(task.id)) {
          return;
        }
        try {
          if (line.startsWith('VDM_PROGRESS:')) {
            final j = jsonDecode(line.substring(13)) as Map;
            if (j['status'] == 'downloading') {
              task.status = TaskStatus.downloading;
              task.progress = DownloadProgress(
                received: (j['downloaded_bytes'] as num?)?.toInt() ?? 0,
                total:
                    ((j['total_bytes'] ?? j['total_bytes_estimate']) as num?)
                        ?.toInt() ??
                    0,
                speed: (j['speed'] as num?)?.toDouble() ?? 0,
                eta: (j['eta'] as num?)?.toInt(),
              );
            }
          } else if (line.startsWith('VDM_INFO:')) {
            final info = jsonDecode(line.substring(9)) as Map;
            if (info['title'] is String) {
              task.title = info['title'];
            }
            if (info['id'] != null && info['extractor'] != null) {
              task.identity = '${info['extractor']}:${info['id']}';
            }
          } else if (line.startsWith('VDM_POST:')) {
            task.status = task.options.audioOnly
                ? TaskStatus.converting
                : TaskStatus.merging;
            task.progress.speed = 0;
          } else if (line.startsWith('VDM_FILE:')) {
            finalFiles.add(jsonDecode(line.substring(9)) as String);
          } else {
            final progress = parseAriaProgress(line);
            if (progress != null) {
              task.status = TaskStatus.downloading;
              task.progress = progress;
            }
            if (line.contains('ERROR:')) {
              failure = classifyError(line);
            }
            if (line.contains('[Merger]') || line.contains('[VideoRemuxer]')) {
              task.status = TaskStatus.merging;
            }
          }
          changed(task);
        } on FormatException {
          /* Unstructured engine diagnostics never become UI progress. */
        }
      }

      Future<void> drain(Stream<List<int>> stream) => stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(
            StreamTransformer.fromHandlers(
              handleData: (String chunk, EventSink<String> sink) =>
                  sink.add(chunk.replaceAll('\r', '\n')),
            ),
          )
          .transform(const LineSplitter())
          .forEach(read);
      final out = drain(worker.process.stdout);
      final err = drain(worker.process.stderr);
      final code = await worker.exitCode;
      await Future.wait([out, err]);
      if (stopped.contains(task.id)) {
        return;
      }
      if (code != 0 || finalFiles.isEmpty) {
        throw StateError(failure.isEmpty ? '下载未生成完整文件，请重试。' : failure);
      }
      for (final output in finalFiles) {
        if (!p.isWithin(p.normalize(temp), p.normalize(output)) ||
            !await File(output).exists()) {
          throw const FileSystemException('Invalid output path');
        }
      }
      // Publish media and requested subtitles only after yt-dlp and FFmpeg succeed.
      final publish = <File>[];
      await for (final file in Directory(temp).list(followLinks: false)) {
        if (file is File &&
            (finalFiles.any((f) => p.equals(f, file.path)) ||
                (task.options.subtitle != null &&
                    {
                      '.srt',
                      '.vtt',
                      '.ass',
                    }.contains(p.extension(file.path))))) {
          publish.add(file);
        }
      }
      var finalSize = 0;
      for (final file in publish) {
        finalSize += await file.length();
        final published = await NativeBridge.publish(
          file.path,
          task.options.directory,
        );
        if (finalFiles.any((f) => p.equals(f, file.path))) {
          task.output = published;
        }
      }
      task.published = true;
      task.status = TaskStatus.completed;
      task.progress = DownloadProgress(received: finalSize, total: finalSize);
      changed(task);
    } finally {
      running.remove(task.id);
      if (cookie != null && await cookie.exists()) {
        await cookie.delete();
      }
    }
  }

  Future<void> stop(String id) async {
    stopped.add(id);
    await running[id]?.stop();
  }

  Future<void> dispose() async {
    for (final id in running.keys.toList()) {
      await stop(id);
    }
  }
}

class AriaEngine {
  final EnginePaths paths;
  final String stateDirectory;
  final HttpClient client = HttpClient();
  ManagedProcess? process;
  int port = 0;
  final String secret = base64Url.encode(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  );
  int _request = 0;
  String startupDiagnostics = '';
  AriaEngine(this.paths, this.stateDirectory);
  Future<void> start() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = socket.port;
    await socket.close();
    final session = File(p.join(stateDirectory, 'aria2.session'));
    if (!await session.exists()) {
      await session.create(recursive: true);
    }
    process = await ManagedProcess.start(paths.binary('aria2c'), [
      '--no-conf',
      '--enable-rpc=true',
      '--rpc-listen-all=false',
      '--rpc-allow-origin-all=false',
      '--rpc-listen-port=$port',
      '--rpc-secret=$secret',
      '--input-file=${session.path}',
      '--save-session=${session.path}',
      '--save-session-interval=5',
      '--auto-save-interval=5',
      '--pause=true',
      '--pause-metadata=true',
      '--enable-color=false',
      '--console-log-level=error',
      '--summary-interval=0',
      '--max-concurrent-downloads=100',
      '--file-allocation=none',
      '--enable-dht=true',
      '--seed-time=0',
      '--continue=true',
      '--auto-file-renaming=false',
      '--allow-overwrite=false',
      '--max-tries=5',
      '--retry-wait=3',
      '--connect-timeout=20',
      '--timeout=30',
    ]);
    void diagnostic(String text) {
      startupDiagnostics =
          (startupDiagnostics +
          text
              .replaceAll(secret, '[redacted]')
              .replaceAll(RegExp(r'https?://[^\s]+'), '[URL]')
              .replaceAll(RegExp(r'magnet:[^\s]+'), '[magnet]'));
      if (startupDiagnostics.length > 4000) {
        startupDiagnostics = startupDiagnostics.substring(
          startupDiagnostics.length - 4000,
        );
      }
    }

    process!.process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(diagnostic);
    process!.process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(diagnostic);
    Object? lastError;
    for (var i = 0; i < 60; i++) {
      try {
        await rpc('getVersion');
        return;
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    await process!.stop();
    throw StateError('aria2 启动失败：$startupDiagnostics；本机 RPC：$lastError');
  }

  Future<dynamic> rpc(String method, [List<dynamic> args = const []]) async {
    final request = await client
        .postUrl(Uri.parse('http://127.0.0.1:$port/jsonrpc'))
        .timeout(const Duration(seconds: 3));
    request.headers.contentType = ContentType.json;
    final payload = utf8.encode(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': ++_request,
        'method': 'aria2.$method',
        'params': ['token:$secret', ...args],
      }),
    );
    request.contentLength = payload.length;
    request.add(payload);
    final response = await request.close().timeout(const Duration(seconds: 5));
    final body = jsonDecode(await response.transform(utf8.decoder).join());
    if (body['error'] != null) {
      throw StateError(
        'aria2: ${body['error']['code']} ${body['error']['message']}',
      );
    }
    return body['result'];
  }

  Future<void> add(DownloadTask task, String temp) async {
    if (task.gid != null) {
      try {
        final current = await status(task.gid!);
        if (task.kind == TaskKind.torrent &&
            !task.filesConfirmed &&
            (current['bittorrent'] as Map?)?['info'] != null) {
          return;
        }
        await rpc('unpause', [task.gid]);
        return;
      } catch (_) {
        task.gid = null;
      }
    }
    final options = <String, String>{
      'dir': temp,
      'pause': 'false',
      'split': '${task.options.connections}',
      'max-connection-per-server': '${task.options.connections}',
      'max-download-limit': '${task.options.speedLimit}',
      'seed-time': '${task.options.seedMinutes}',
      'seed-ratio': '${task.options.seedRatio}',
      'bt-save-metadata': 'true',
      'pause-metadata': 'true',
      if (task.options.referer != null) 'referer': task.options.referer!,
      if (task.kind == TaskKind.file) 'out': safeName(task.title),
      if (task.selectedFiles.isNotEmpty)
        'select-file': task.selectedFiles.join(','),
    };
    if (task.kind == TaskKind.torrent &&
        !task.source.startsWith('magnet:') &&
        !task.source.startsWith('http')) {
      options['pause'] = 'true';
      task.gid = await rpc('addTorrent', [
        base64Encode(await File(task.source).readAsBytes()),
        [],
        options,
      ]);
    } else {
      task.gid = await rpc('addUri', [
        [task.source],
        options,
      ]);
    }
  }

  Future<Map<String, dynamic>> status(String gid) async =>
      Map<String, dynamic>.from(await rpc('tellStatus', [gid]));
  Future<void> pause(String gid) async {
    await rpc('forcePause', [gid]);
  }

  Future<void> remove(String gid) async {
    try {
      await rpc('forceRemove', [gid]);
    } catch (_) {
      await rpc('removeDownloadResult', [gid]);
    }
  }

  Future<void> dispose() async {
    if (process == null) {
      return;
    }
    try {
      await rpc('forcePauseAll');
      await rpc('saveSession');
      await rpc('shutdown');
      await process!.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      await process!.stop();
    }
    client.close(force: true);
  }
}
