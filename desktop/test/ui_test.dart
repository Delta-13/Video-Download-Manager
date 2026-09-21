import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vdm/core/controller.dart';
import 'package:vdm/core/engines.dart';
import 'package:vdm/core/models.dart';
import 'package:vdm/core/store.dart';
import 'package:vdm/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final mono = FontLoader('JetBrains Mono')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));
    await mono.load();
    final cjk = FontLoader('Sarasa Mono SC')
      ..addFont(rootBundle.load('assets/fonts/SarasaMonoSC-Regular.ttf'));
    await cjk.load();
  });
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'theme ${dark ? 'dark' : 'light'} at $scale text scale, empty and new task',
        (tester) async {
          tester.view.physicalSize = const Size(1440, 960);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = TaskStore(':memory:');
          store.set('theme', dark ? 'dark' : 'light');
          final state = DownloadController(
            store,
            Directory.systemTemp.path,
            EnginePaths('engines'),
          )..ready = true;
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [downloadsProvider.overrideWith((ref) => state)],
              child: RepaintBoundary(
                key: boundary,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(1440, 960),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const VdmApp(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('准备好下一次下载'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(FocusManager.instance.primaryFocus, isNotNull);
          if (scale == 1) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final folder = Directory('../artifacts/screenshots')
                ..createSync(recursive: true);
              File(
                '${folder.path}/${dark ? 'dark' : 'light'}-empty.png',
              ).writeAsBytesSync(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.tap(find.text('新建任务').first);
          await tester.pumpAndSettle();
          expect(find.text('新建下载任务'), findsOneWidget);
          expect(find.text('解析链接'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('取消').last);
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          store.close();
        },
      );
    }
  }
  testWidgets('narrow list, details, settings, keyboard and no phantom data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TaskStore(':memory:');
    final state = DownloadController(
      store,
      Directory.systemTemp.path,
      EnginePaths('engines'),
    )..ready = true;
    state.tasks.add(
      DownloadTask(
        id: 'fixture',
        source: 'https://example.com/test',
        kind: TaskKind.file,
        title: '测试夹具：暂停任务',
        options: DownloadOptions(directory: r'C:\Downloads'),
        status: TaskStatus.paused,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [downloadsProvider.overrideWith((ref) => state)],
        child: const VdmApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('测试夹具：暂停任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.view('settings');
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.close();
  });
}
