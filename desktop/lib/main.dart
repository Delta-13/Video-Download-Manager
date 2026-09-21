import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'core/controller.dart';
import 'core/diagnostics.dart';
import 'core/engines.dart';
import 'core/store.dart';
import 'ui/design.dart';
import 'ui/shell.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.length == 2 && args.first == '--verify-runtime') {
    exit(await verifyRuntime(args[1]));
  }
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(760, 620));
  await windowManager.setTitle('Video Download Manager 2');
  final data = await getApplicationSupportDirectory();
  await data.create(recursive: true);
  final store = TaskStore(p.join(data.path, 'vdm.sqlite'));
  final controller = DownloadController(
    store,
    data.path,
    EnginePaths.discover(),
  );
  runApp(
    ProviderScope(
      overrides: [downloadsProvider.overrideWith((ref) => controller)],
      child: const VdmApp(),
    ),
  );
  try {
    await controller.initialize();
    final tray = DesktopLifecycle(controller);
    await tray.initialize();
  } catch (e) {
    controller.engineError = '初始化失败，请检查安装目录与数据目录权限。';
    controller.initializing = false;
    controller.setting('lastStartupFailed', true);
  }
  LicenseRegistry.addLicense(() async* {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets().where(
      (s) => s.startsWith('assets/legal/') && s.endsWith('.txt'),
    )) {
      yield LicenseEntryWithLineBreaks([
        p.basename(asset),
      ], await rootBundle.loadString(asset));
    }
  });
}

class VdmApp extends ConsumerWidget {
  const VdmApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadsProvider);
    return MaterialApp(
      title: 'Video Download Manager 2',
      debugShowCheckedModeBanner: false,
      theme: industrialTheme(false),
      darkTheme: industrialTheme(true),
      themeMode: state.themeMode,
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 200),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const DownloadShell(),
    );
  }
}

class DesktopLifecycle with WindowListener, TrayListener {
  final DownloadController controller;
  bool quitting = false;
  DesktopLifecycle(this.controller);
  Future<void> initialize() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    final icon = p.join(
      p.dirname(Platform.resolvedExecutable),
      'data',
      'app_icon.ico',
    );
    await trayManager.setIcon(icon);
    await trayManager.setToolTip('Video Download Manager 2');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示窗口'),
          MenuItem.separator(),
          MenuItem(key: 'pause', label: '全部暂停'),
          MenuItem(key: 'resume', label: '恢复暂停任务'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: '退出'),
        ],
      ),
    );
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() async {
    if (!quitting) {
      await windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        onTrayIconMouseDown();
      case 'pause':
        await controller.bulk(true, all: true);
      case 'resume':
        await controller.bulk(false, all: true);
      case 'exit':
        if (quitting) {
          return;
        }
        quitting = true;
        await controller.shutdown();
        await trayManager.destroy();
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
    }
  }
}
