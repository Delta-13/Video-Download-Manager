import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vdm/core/engines.dart';
import 'package:vdm/core/store.dart';
import 'package:vdm/subtitles/document.dart';
import 'package:vdm/subtitles/workspace.dart';
import 'package:vdm/ui/design.dart';
import 'package:vdm/ui/subtitles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('JetBrains Mono')
          ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf')))
        .load();
    await (FontLoader('Sarasa Mono SC')
          ..addFont(rootBundle.load('assets/fonts/SarasaMonoSC-Regular.ttf')))
        .load();
  });
  for (final dark in [true, false]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'subtitle workspace ${dark ? 'dark' : 'light'} $scale narrow, settings and loading',
        (tester) async {
          tester.view.physicalSize = Size(scale == 1 ? 1240 : 724, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = TaskStore(':memory:');
          final w = SubtitleWorkspace(
            store,
            EnginePaths('engines'),
            Directory.systemTemp.path,
          );
          w.document = SubtitleDocument('fixture.srt', [
            SubtitleCue(
              1025,
              3500,
              'Test fixture: Hello and welcome.',
              translation: '测试夹具：你好，欢迎。',
            ),
            SubtitleCue(4000, 6200, 'The translation preserves the timeline.'),
          ]);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: industrialTheme(dark),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: RepaintBoundary(key: boundary, child: SubtitlePage(w)),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final folder = Directory('../artifacts/screenshots-subtitles')
              ..createSync(recursive: true);
            File(
              '${folder.path}/${dark ? 'dark' : 'light'}-$scale.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
          await tester.tap(find.text('校对').first);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '已校对的译文');
          await tester.tap(find.text('保存'));
          await tester.pumpAndSettle();
          expect(w.document!.cues.first.translation, '已校对的译文');
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('翻译设置'));
          await tester.pumpAndSettle();
          expect(find.text('AI 字幕设置'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('导出…'));
          await tester.pumpAndSettle();
          expect(find.text('仅导出原文'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          w.busy = true;
          w.stage = '正在翻译 · 1/2';
          await tester.pumpWidget(
            MaterialApp(
              theme: industrialTheme(dark),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SubtitlePage(w, key: const ValueKey('busy')),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('停止处理'), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, '翻译设置'),
                )
                .onPressed,
            isNull,
          );
          expect(tester.takeException(), isNull);
          w.busy = false;
          await tester.pumpWidget(const SizedBox.shrink());
          w.dispose();
          store.close();
        },
      );
    }
  }
}
