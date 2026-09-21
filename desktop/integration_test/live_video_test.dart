import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:vdm/core/controller.dart';
import 'package:vdm/core/engines.dart';
import 'package:vdm/core/models.dart';
import 'package:vdm/core/store.dart';

/// Opt-in live acceptance test. No URL, account or media title is committed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const source = String.fromEnvironment('VDM_TEST_URL');
  testWidgets(
    'user-provided live video through the application adapters',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('正在执行公网下载验收'))),
        ),
      );
      final base = Directory(
        const String.fromEnvironment(
          'VDM_ARTIFACTS',
          defaultValue: '../artifacts',
        ),
      );
      await base.create(recursive: true);
      final root = await Directory(
        p.join(base.absolute.path, 'live-tests'),
      ).create(recursive: true);
      final run = await root.createTemp('acceptance-');
      final outputs = await Directory(p.join(run.path, 'downloads')).create();
      final paths = EnginePaths.discover();
      final controller = DownloadController(
        TaskStore(p.join(run.path, 'tasks.sqlite')),
        run.path,
        paths,
        enableBrowser: false,
      );
      final report = <String, dynamic>{
        'checkedAt': DateTime.now().toUtc().toIso8601String(),
        'host': Uri.parse(source).host,
        'sourceSha256': sha256.convert(utf8.encode(source)).toString(),
        'engines': paths.versions,
        'cookiesSupplied': false,
        'requestedMaximumHeight': 360,
        'metadata': 'not_started',
        'download': 'not_started',
      };
      final statuses = <String>[];
      var success = false;
      try {
        await controller.initialize();
        if (!controller.ready) throw StateError(controller.engineError!);
        report['metadata'] = 'started';
        final info = await controller.videos
            .inspect(source, 'live-inspection')
            .timeout(const Duration(seconds: 100));
        report['metadata'] = 'passed';
        report['formatCount'] = info.formats.length;
        report['videoFormatCount'] = info.videoFormats.length;
        report['hasTitle'] = info.title.isNotEmpty;
        report['heights'] = info.videoHeights;
        final task = await controller.add(
          source,
          DownloadOptions(directory: outputs.path, height: 360),
          kind: TaskKind.video,
          identity: info.identity,
          title: info.title,
        );
        report['download'] = 'started';
        final deadline = DateTime.now().add(const Duration(minutes: 5));
        var observedBytes = 0;
        while (task.status != TaskStatus.completed) {
          if (!statuses.contains(task.status.name)) {
            statuses.add(task.status.name);
          }
          if (task.progress.received > observedBytes) {
            observedBytes = task.progress.received;
          }
          if (task.status == TaskStatus.failed) throw StateError(task.error!);
          if (DateTime.now().isAfter(deadline)) {
            throw TimeoutException('Live download exceeded five minutes');
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        statuses.add(TaskStatus.completed.name);
        final output = File(task.output!);
        report['bytes'] = await output.length();
        report['sha256'] = (await sha256.bind(output.openRead()).first)
            .toString();
        report['observedProgressBytes'] = observedBytes;
        final probe = await Process.run(paths.binary('ffprobe'), [
          '-v',
          'error',
          '-show_entries',
          'format=duration:stream=codec_type,codec_name,width,height',
          '-of',
          'json',
          output.path,
        ]);
        if (probe.exitCode != 0) {
          throw StateError('Final media failed ffprobe validation');
        }
        final media = jsonDecode(probe.stdout as String) as Map;
        report['media'] = media;
        if (double.parse(media['format']['duration']) <= 0 ||
            !(media['streams'] as List).any(
              (s) => s['codec_type'] == 'video',
            )) {
          throw StateError('Final output has no playable video stream');
        }
        report['download'] = 'passed';
        success = true;
      } catch (error) {
        if (report['metadata'] == 'started') report['metadata'] = 'failed';
        if (report['download'] == 'started') report['download'] = 'failed';
        report['error'] = error is StateError
            ? error.message
            : classifyError(error.toString());
      } finally {
        report['observedStates'] = statuses;
        report['ok'] = success;
        await controller.shutdown();
        await File(
          p.join(base.absolute.path, 'live-video-result.json'),
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      }
      expect(success, isTrue, reason: report['error']?.toString());
    },
    skip: source.isEmpty,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
