import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:vdm/core/controller.dart';
import 'package:vdm/core/engines.dart';
import 'package:vdm/core/models.dart';
import 'package:vdm/core/native.dart';
import 'package:vdm/core/store.dart';
import 'package:vdm/main.dart';

List<int> bencode(dynamic value) {
  if (value is int) {
    return ascii.encode('i${value}e');
  }
  if (value is String) {
    return bencode(utf8.encode(value));
  }
  if (value is List<int>) {
    return [...ascii.encode('${value.length}:'), ...value];
  }
  if (value is List) {
    return [108, ...value.expand((v) => bencode(v)), 101];
  }
  final map = value as Map<String, dynamic>;
  final keys = map.keys.toList()..sort();
  return [
    100,
    ...keys.expand((k) => [...bencode(k), ...bencode(map[k])]),
    101,
  ];
}

Future<void> until(
  bool Function() condition, {
  DownloadTask? task,
  int seconds = 40,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!condition()) {
    if (task?.status == TaskStatus.failed) {
      throw StateError('Task failed: ${task!.error}');
    }
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException(
        'Waiting for task: ${task?.status} ${task?.error}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Windows engines: HTTP resume, video, HLS, torrent selection, DPAPI and handoff',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('VDM 本地引擎集成测试'))),
        ),
      );
      final root = await Directory.systemTemp.createTemp('vdm-integration-');
      final engines = EnginePaths.discover();
      expect(engines.missing, isEmpty);
      final out = Directory(p.join(root.path, 'downloads'))..createSync();
      final data = Directory(p.join(root.path, 'state'))..createSync();
      final media = Directory(p.join(root.path, 'media'))..createSync();
      final content = Uint8List.fromList(
        List.generate(6 * 1024 * 1024, (i) => i % 251),
      );
      final first = content.sublist(0, 64 * 1024),
          second = content.sublist(64 * 1024, 128 * 1024);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = 'http://127.0.0.1:${server.port}';
      final ranges = <String>[];
      var seedPort = 0;
      var transientFailures = 0;
      ManagedProcess? seeder;
      server.listen((request) async {
        try {
          final path = request.uri.path;
          if (path == '/retry.bin' && transientFailures++ < 2) {
            request.response.statusCode = 503;
            await request.response.close();
            return;
          }
          if (path == '/announce') {
            request.response.add(
              bencode({
                'interval': 1,
                'complete': 1,
                'incomplete': 1,
                'peers': <int>[127, 0, 0, 1, seedPort >> 8, seedPort & 255],
              }),
            );
            await request.response.close();
            return;
          }
          if (path == '/blocked') {
            request.response.statusCode = 403;
            await request.response.close();
            return;
          }
          List<int> bytes;
          if (path.startsWith('/seed/bundle/')) {
            bytes = path.endsWith('first.bin') ? first : second;
          } else if (path.startsWith('/media/')) {
            final file = File(p.join(media.path, p.basename(path)));
            bytes = await file.readAsBytes();
            request.response.headers.contentType = ContentType.parse(
              path.endsWith('.m3u8')
                  ? 'application/vnd.apple.mpegurl'
                  : path.endsWith('.mpd')
                  ? 'application/dash+xml'
                  : path.endsWith('.ts')
                  ? 'video/mp2t'
                  : 'video/mp4',
            );
          } else {
            bytes = content;
            request.response.headers.contentType = ContentType.binary;
          }
          var start = 0, end = bytes.length - 1;
          final range = request.headers.value('range');
          if (range != null && !path.contains('no-range')) {
            ranges.add(range);
            final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
            start = int.parse(m[1]!);
            if (m[2]!.isNotEmpty) {
              end = int.parse(m[2]!).clamp(0, bytes.length - 1);
            }
            request.response.statusCode = 206;
            request.response.headers.set(
              'Content-Range',
              'bytes $start-$end/${bytes.length}',
            );
          }
          if (path != '/unknown.bin') {
            request.response.contentLength = end - start + 1;
          }
          request.response.headers.set('Accept-Ranges', 'bytes');
          if (request.method != 'HEAD') {
            for (var offset = start; offset <= end; offset += 65536) {
              request.response.add(
                bytes.sublist(offset, (offset + 65536).clamp(0, end + 1)),
              );
              await request.response.flush();
              if (path == '/slow.bin') {
                await Future<void>.delayed(const Duration(milliseconds: 25));
              }
            }
          }
          await request.response.close();
        } catch (_) {
          request.response.close();
        }
      });
      var controller = DownloadController(
        TaskStore(p.join(data.path, 'tasks.sqlite')),
        data.path,
        engines,
        enableBrowser: false,
      );
      try {
        final protected = await NativeBridge.protect(
          utf8.encode('session=fixture'),
        );
        expect(
          await NativeBridge.unprotect(protected),
          utf8.encode('session=fixture'),
        );
        await controller.initialize();
        expect(controller.ready, isTrue, reason: controller.engineError);
        controller.setting('directory', out.path);
        final task = await controller.add(
          '$base/slow.bin',
          DownloadOptions(directory: out.path, connections: 4),
          kind: TaskKind.file,
        );
        await until(() => task.progress.received > 0, task: task);
        await controller.pause(task);
        expect(task.status, TaskStatus.paused);
        await controller.shutdown();
        controller = DownloadController(
          TaskStore(p.join(data.path, 'tasks.sqlite')),
          data.path,
          engines,
          enableBrowser: false,
        );
        await controller.initialize();
        final resumed = controller.tasks.single;
        expect(resumed.status, TaskStatus.paused);
        await controller.resume(resumed);
        await until(
          () => resumed.status == TaskStatus.completed,
          task: resumed,
        );
        expect(
          sha256.convert(await File(resumed.output!).readAsBytes()),
          sha256.convert(content),
        );
        expect(ranges.any((s) => !s.startsWith('bytes=0-')), isTrue);
        final collision = await controller.add(
          '$base/no-range.bin',
          DownloadOptions(directory: out.path, connections: 1),
          kind: TaskKind.file,
          title: p.basename(resumed.output!),
        );
        await until(
          () => collision.status == TaskStatus.completed,
          task: collision,
        );
        expect(collision.output, isNot(resumed.output));
        expect(await File(resumed.output!).length(), content.length);
        for (final path in ['unknown.bin', 'retry.bin']) {
          final extra = await controller.add(
            '$base/$path',
            DownloadOptions(directory: out.path),
            kind: TaskKind.file,
          );
          await until(() => extra.status == TaskStatus.completed, task: extra);
          expect(
            sha256.convert(await File(extra.output!).readAsBytes()),
            sha256.convert(content),
          );
        }
        expect(transientFailures, greaterThanOrEqualTo(3));

        final ff = await Process.run(engines.binary('ffmpeg'), [
          '-hide_banner',
          '-loglevel',
          'error',
          '-f',
          'lavfi',
          '-i',
          'testsrc=size=160x90:rate=15',
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=440',
          '-t',
          '3',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          '-c:a',
          'aac',
          '-shortest',
          p.join(media.path, 'fixture.mp4'),
        ]);
        expect(ff.exitCode, 0, reason: '${ff.stderr}');
        final hls = await Process.run(engines.binary('ffmpeg'), [
          '-hide_banner',
          '-loglevel',
          'error',
          '-i',
          p.join(media.path, 'fixture.mp4'),
          '-c',
          'copy',
          '-hls_time',
          '1',
          '-hls_list_size',
          '0',
          p.join(media.path, 'fixture.m3u8'),
        ]);
        expect(hls.exitCode, 0, reason: '${hls.stderr}');
        final dash = await Process.run(engines.binary('ffmpeg'), [
          '-hide_banner',
          '-loglevel',
          'error',
          '-i',
          p.join(media.path, 'fixture.mp4'),
          '-map',
          '0:v',
          '-map',
          '0:a',
          '-c',
          'copy',
          '-f',
          'dash',
          p.join(media.path, 'fixture.mpd'),
        ], workingDirectory: media.path);
        expect(dash.exitCode, 0, reason: '${dash.stderr}');
        for (final extension in ['mp4', 'm3u8', 'mpd']) {
          final source = '$base/media/fixture.$extension';
          final info = await controller.videos.inspect(
            source,
            'inspect-$extension',
          );
          expect(info.formats, isNotEmpty);
          final video = await controller.add(
            source,
            DownloadOptions(directory: out.path),
            kind: TaskKind.video,
            title: info.title,
          );
          await until(
            () => video.status == TaskStatus.completed,
            task: video,
            seconds: 60,
          );
          final probe = await Process.run(engines.binary('ffprobe'), [
            '-v',
            'error',
            '-show_entries',
            'format=duration',
            '-of',
            'json',
            video.output!,
          ]);
          expect(probe.exitCode, 0, reason: '$extension: ${probe.stderr}');
          expect(
            double.parse(jsonDecode(probe.stdout)['format']['duration']),
            greaterThan(2.5),
          );
        }
        final audio = await controller.add(
          '$base/media/fixture.mp4',
          DownloadOptions(directory: out.path, audioOnly: true),
          kind: TaskKind.video,
        );
        await until(
          () => audio.status == TaskStatus.completed,
          task: audio,
          seconds: 60,
        );
        expect(p.extension(audio.output!), '.mp3');
        await File(
          p.join(media.path, 'broken.mp4'),
        ).writeAsString('invalid media fixture');
        final broken = await controller.add(
          '$base/media/broken.mp4',
          DownloadOptions(directory: out.path, audioOnly: true),
          kind: TaskKind.video,
        );
        await until(() => broken.status == TaskStatus.failed, seconds: 45);
        expect(broken.published, isFalse);
        expect(broken.output, isNull);
        final combined = [...first, ...second];
        final hashes = <int>[];
        for (var i = 0; i < combined.length; i += 16384) {
          hashes.addAll(
            sha1
                .convert(
                  combined.sublist(i, (i + 16384).clamp(0, combined.length)),
                )
                .bytes,
          );
        }
        final torrent = File(p.join(root.path, 'fixture.torrent'));
        await torrent.writeAsBytes(
          bencode({
            'url-list': '$base/seed/',
            'info': {
              'name': 'bundle',
              'piece length': 16384,
              'pieces': hashes,
              'files': [
                {
                  'length': first.length,
                  'path': ['first.bin'],
                },
                {
                  'length': second.length,
                  'path': ['second.bin'],
                },
              ],
            },
          }),
        );
        final bt = await controller.add(
          torrent.path,
          DownloadOptions(directory: out.path),
          kind: TaskKind.torrent,
        );
        await until(() => bt.status == TaskStatus.awaitingSelection, task: bt);
        expect(bt.files.length, 2);
        expect(bt.progress.received, 0);
        await controller.chooseFiles(bt, [2]);
        await until(
          () => bt.status == TaskStatus.completed,
          task: bt,
          seconds: 60,
        );
        expect(
          sha256.convert(await File(bt.output!).readAsBytes()),
          sha256.convert(second),
        );
        expect(
          File(p.join(out.path, 'bundle', 'first.bin')).existsSync(),
          isFalse,
        );

        // A real, isolated local peer supplies BEP 9 magnet metadata and pieces.
        final magnetInfo = <String, dynamic>{
          'name': 'magnetbundle',
          'private': 1,
          'piece length': 16384,
          'pieces': hashes,
          'files': [
            {
              'length': first.length,
              'path': ['first.bin'],
            },
            {
              'length': second.length,
              'path': ['second.bin'],
            },
          ],
        };
        final seedDirectory = Directory(p.join(media.path, 'magnetbundle'));
        await seedDirectory.create();
        await File(p.join(seedDirectory.path, 'first.bin')).writeAsBytes(first);
        await File(
          p.join(seedDirectory.path, 'second.bin'),
        ).writeAsBytes(second);
        final magnetTorrent = File(p.join(root.path, 'magnet.torrent'));
        await magnetTorrent.writeAsBytes(
          bencode({'announce': '$base/announce', 'info': magnetInfo}),
        );
        final seedSocket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        seedPort = seedSocket.port;
        await seedSocket.close();
        seeder = await ManagedProcess.start(engines.binary('aria2c'), [
          '--no-conf',
          '--dir=${media.path}',
          '--listen-port=$seedPort',
          '--enable-dht=false',
          '--enable-dht6=false',
          '--bt-enable-lpd=false',
          '--check-integrity=true',
          '--seed-time=10',
          '--seed-ratio=100',
          '--console-log-level=error',
          '--summary-interval=0',
          magnetTorrent.path,
        ]);
        seeder.process.stdout.drain<void>();
        seeder.process.stderr.drain<void>();
        final magnet = await controller.add(
          'magnet:?xt=urn:btih:${sha1.convert(bencode(magnetInfo))}&tr=${Uri.encodeComponent('$base/announce')}&dn=magnetbundle',
          DownloadOptions(directory: out.path),
          kind: TaskKind.torrent,
        );
        await until(
          () => magnet.status == TaskStatus.awaitingSelection,
          task: magnet,
          seconds: 60,
        );
        expect(magnet.files.length, 2);
        expect(magnet.filesConfirmed, isFalse);
        await controller.chooseFiles(magnet, [1]);
        await until(
          () => magnet.status == TaskStatus.completed,
          task: magnet,
          seconds: 60,
        );
        expect(
          sha256.convert(await File(magnet.output!).readAsBytes()),
          sha256.convert(first),
        );
        expect(
          File(p.join(out.path, 'magnetbundle', 'second.bin')).existsSync(),
          isFalse,
        );
        await seeder.stop();
        await seeder.exitCode;
        seeder = null;

        const request = 'integration-handoff-123';
        final prepared = await controller.browserRequest({
          'protocolVersion': 1,
          'requestId': request,
          'action': 'prepare',
          'method': 'GET',
          'url': '$base/handoff.bin',
          'filename': 'handoff.bin',
        });
        expect(prepared['ok'], isTrue);
        final duplicate = await controller.browserRequest({
          'protocolVersion': 1,
          'requestId': request,
          'action': 'prepare',
          'method': 'GET',
          'url': '$base/handoff.bin',
        });
        expect(duplicate['taskId'], prepared['taskId']);
        final committed = await controller.browserRequest({
          'protocolVersion': 1,
          'requestId': request,
          'action': 'commit',
        });
        expect(committed['ok'], isTrue);
        final duplicateAlias = await controller.browserRequest({
          'protocolVersion': 1,
          'requestId': 'integration-alias-123',
          'action': 'prepare',
          'method': 'GET',
          'url': '$base/handoff.bin',
        });
        expect(duplicateAlias['taskId'], prepared['taskId']);
        final aliasCommit = await controller.browserRequest({
          'protocolVersion': 1,
          'requestId': 'integration-alias-123',
          'action': 'commit',
        });
        expect(aliasCommit['ok'], isTrue);
        await controller.browserRequest({
          'protocolVersion': 1,
          'requestId': 'integration-alias-123',
          'action': 'abort',
        });
        expect(
          controller.tasks.firstWhere((t) => t.id == prepared['taskId']).status,
          isNot(TaskStatus.canceled),
        );
        final rejected = await controller.browserRequest({
          'protocolVersion': 1,
          'requestId': 'integration-failed-123',
          'action': 'prepare',
          'method': 'GET',
          'url': '$base/blocked',
        });
        expect(rejected['ok'], isFalse);
        final cookieFile = File(p.join(root.path, 'cookies.txt'));
        await cookieFile.writeAsString(
          '# Netscape HTTP Cookie File\n.example.com\tTRUE\t/\tFALSE\t0\ttest\tvalue\n',
        );
        await controller.cookies.import('example.com', cookieFile.path);
        expect(controller.cookies.keyFor('https://notexample.com'), isNull);
        final plain = await controller.cookies.materialize(
          'https://www.example.com',
        );
        expect(await plain!.readAsString(), contains('test\tvalue'));
        await plain.delete();
        final recurring = await controller.add(
          '$base/scheduled.bin',
          DownloadOptions(directory: out.path),
          kind: TaskKind.file,
          schedule: Schedule(
            DateTime.now().add(const Duration(days: 1)),
            repeat: RepeatRule.daily,
          ),
        );
        await controller.runScheduled(recurring);
        expect(recurring.status, TaskStatus.scheduled);
        expect(recurring.schedule!.next.isAfter(DateTime.now()), isTrue);
        final scheduledChild = controller.tasks.first;
        await until(
          () => scheduledChild.status == TaskStatus.completed,
          task: scheduledChild,
        );
        final snapshot = GlobalKey();
        controller.focus(bt.id);
        controller.setting('theme', 'dark');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [downloadsProvider.overrideWith((ref) => controller)],
            child: RepaintBoundary(key: snapshot, child: const VdmApp()),
          ),
        );
        for (final theme in ['dark', 'light']) {
          controller.setting('theme', theme);
          // Pump intermediate frames as Material's text styles also animate.
          for (var frame = 0; frame < 16; frame++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          final image =
              await (snapshot.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = Directory(
            p.join(
              const String.fromEnvironment(
                'VDM_ARTIFACTS',
                defaultValue: '../artifacts',
              ),
              'screenshots',
            ),
          );
          await output.create(recursive: true);
          await File(
            p.join(output.path, '$theme-local-downloads.png'),
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        }
      } finally {
        await seeder?.stop();
        await controller.shutdown();
        await server.close(force: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
