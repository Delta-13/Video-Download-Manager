import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:vdm/core/engines.dart';
import 'package:vdm/core/store.dart';
import 'package:vdm/subtitles/document.dart';
import 'package:vdm/subtitles/translator.dart';
import 'package:vdm/subtitles/workspace.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native subtitle persistence, DPAPI, exclusive exports, FFmpeg and optional real models',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('VDM 字幕集成测试'))),
        ),
      );
      final root = await Directory.systemTemp.createTemp(
        'vdm-subtitle-integration-',
      );
      final database = p.join(root.path, 'state.sqlite');
      var store = TaskStore(database);
      var workspace = SubtitleWorkspace(
        store,
        EnginePaths.discover(),
        root.path,
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = 'http://127.0.0.1:${server.port}/v1';
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(
          request.headers.value('authorization'),
          'Bearer integration-secret',
        );
        final entries =
            jsonDecode(body['messages'][1]['content'])['subtitles'] as List;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'translations': entries
                        .map(
                          (e) => {
                            'id': e['id'],
                            'text': e['id'] == 0 ? '你好，欢迎。' : '字幕保留原来的时间轴。',
                          },
                        )
                        .toList(),
                  }),
                },
              },
            ],
          }),
        );
        await request.response.close();
      });
      final report = <String, dynamic>{
        'version': '2.1.0',
        'checks': <String, dynamic>{},
      };
      final checks = report['checks'] as Map<String, dynamic>;
      try {
        final input = File(p.join(root.path, 'sample.srt'));
        await input.writeAsString(
          '1\n00:00:01,025 --> 00:00:03,500\nHello and welcome.\n\n2\n00:00:04,000 --> 00:00:06,200\nThe subtitles preserve the original timeline.\n',
        );
        await workspace.saveConfig(
          TranslationConfig(local: false, endpoint: base, model: 'fixture'),
          apiKey: 'integration-secret',
          whisperExe: '',
          modelPath: '',
          language: 'auto',
        );
        expect(
          store.setting('subtitleApiKey', ''),
          isNot(contains('integration-secret')),
        );
        expect(
          store.setting('subtitleConfig', {}).toString(),
          isNot(contains('integration-secret')),
        );
        await workspace.importFile(input.path);
        expect(workspace.error, isNull);
        expect(workspace.document!.cues.length, 2);
        await workspace.translate();
        expect(workspace.error, isNull);
        expect(workspace.document!.translated, 2);
        checks['dpapiAndCompatibleApi'] = true;
        final id = workspace.jobId;
        await workspace.shutdown();
        workspace.dispose();
        store.close();
        store = TaskStore(database);
        workspace = SubtitleWorkspace(store, EnginePaths.discover(), root.path);
        expect(workspace.jobId, id);
        expect(workspace.document!.translated, 2);
        checks['restartRecovery'] = true;
        for (final format in ['srt', 'vtt', 'ass']) {
          await workspace.export(root.path, format: format, bilingual: true);
          expect(workspace.error, isNull);
          final first = workspace.lastExport!;
          final bytes = await File(first).readAsBytes();
          await workspace.export(root.path, format: format, bilingual: true);
          expect(workspace.error, isNull);
          expect(workspace.lastExport, isNot(first));
          expect(await File(first).readAsBytes(), bytes);
          await workspace.importFile(first);
          expect(workspace.error, isNull);
          expect(
            workspace.document!.cues.first.start,
            format == 'ass' ? 1030 : 1025,
          ); // ASS uses centiseconds.
          expect(workspace.document!.cues.first.text, contains('你好'));
          // Re-open original translated record before the next format.
          workspace.openJob(id!);
        }
        checks['srtVttAssAndNoOverwrite'] = true;
        await workspace.saveConfig(
          TranslationConfig(
            local: false,
            endpoint: '$base/changed',
            model: 'fixture',
          ),
          whisperExe: '',
          modelPath: '',
          language: 'auto',
        );
        expect(workspace.hasKey, false);
        checks['keyBoundToEndpoint'] = true;
        const localModel = String.fromEnvironment('VDM_OLLAMA_MODEL');
        if (localModel.isNotEmpty) {
          await workspace.saveConfig(
            const TranslationConfig(model: localModel, batchSize: 2),
            whisperExe: '',
            modelPath: '',
            language: 'auto',
          );
          await workspace.translate();
          expect(workspace.error, isNull);
          expect(workspace.document!.translated, 2);
          for (final cue in workspace.document!.cues) {
            expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(cue.translation!), true);
          }
          checks['ollama'] = {
            'model': localModel,
            'translations': workspace.document!.cues
                .map((c) => c.translation)
                .toList(),
          };
        }
        const whisperExe = String.fromEnvironment('VDM_WHISPER_EXE');
        const whisperModel = String.fromEnvironment('VDM_WHISPER_MODEL');
        const audio = String.fromEnvironment('VDM_WHISPER_AUDIO');
        if (whisperExe.isNotEmpty &&
            whisperModel.isNotEmpty &&
            audio.isNotEmpty) {
          await workspace.saveConfig(
            const TranslationConfig(model: localModel),
            whisperExe: whisperExe,
            modelPath: whisperModel,
            language: 'en',
          );
          await workspace.importFile(audio);
          expect(workspace.error, isNull);
          expect(workspace.document!.cues, isNotEmpty);
          final text = workspace.document!.cues
              .map((c) => c.text)
              .join(' ')
              .toLowerCase();
          expect(text, contains('country'));
          await workspace.export(
            root.path,
            format: 'srt',
            bilingual: false,
            original: true,
          );
          expect(workspace.error, isNull);
          checks['whisper'] = {
            'cues': workspace.document!.cues.length,
            'transcript': text,
          };
          if (localModel.isNotEmpty) {
            await workspace.translate();
            expect(workspace.error, isNull);
            expect(
              workspace.document!.translated,
              workspace.document!.cues.length,
            );
            await workspace.export(root.path, format: 'srt', bilingual: true);
            expect(workspace.error, isNull);
            final bilingual = SubtitleDocument.parse(
              'result.srt',
              await File(workspace.lastExport!).readAsString(),
            );
            expect(
              bilingual.cues.first.text.toLowerCase(),
              contains('country'),
            );
            expect(
              RegExp(r'[\u4e00-\u9fff]').hasMatch(bilingual.cues.first.text),
              true,
            );
            checks['audioToBilingualSubtitles'] = true;
          }
        }
        expect(
          Directory(p.join(root.path, 'subtitle-temp')).listSync(),
          isEmpty,
        );
        checks['temporaryCleanup'] = true;
        report['ok'] = true;
      } finally {
        await workspace.shutdown();
        workspace.dispose();
        store.close();
        await server.close(force: true);
        const reportPath = String.fromEnvironment('VDM_SUBTITLE_REPORT');
        if (reportPath.isNotEmpty) {
          await File(
            reportPath,
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
        }
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
