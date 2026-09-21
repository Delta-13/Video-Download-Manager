import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'controller.dart';
import 'engines.dart';
import 'native.dart';
import 'store.dart';

/// Explicit, offline package verification. Never runs during a normal launch.
Future<int> verifyRuntime(String reportPath) async {
  final root = await Directory.systemTemp.createTemp('vdm-runtime-check-');
  final paths = EnginePaths.discover();
  final report = <String, dynamic>{
    'version': '2.0.0',
    'executable': Platform.resolvedExecutable,
    'checks': <String, dynamic>{},
  };
  final checks = report['checks'] as Map<String, dynamic>;
  DownloadController? controller;
  try {
    checks['missingEngines'] = paths.missing;
    if (paths.missing.isNotEmpty) {
      throw StateError('Missing bundled engines');
    }
    for (final name in ['yt-dlp', 'aria2c', 'ffmpeg', 'ffprobe', 'deno']) {
      final result = await Process.run(paths.binary(name), [
        name.startsWith('ff') ? '-version' : '--version',
      ]);
      checks[name] = {
        'exitCode': result.exitCode,
        'version': result.stdout.toString().split('\n').first.trim(),
      };
      if (result.exitCode != 0) {
        throw StateError('$name failed');
      }
    }
    final input = utf8.encode('vdm-offline-runtime-check');
    final protected = await NativeBridge.protect(input);
    checks['dpapi'] =
        utf8.decode(await NativeBridge.unprotect(protected)) ==
        utf8.decode(input);
    controller = DownloadController(
      TaskStore(p.join(root.path, 'check.sqlite')),
      root.path,
      paths,
      enableBrowser: false,
    );
    await controller.initialize();
    checks['aria2Rpc'] = controller.ready;
    checks['sqlite'] = controller.store.load().isEmpty;
    if (!controller.ready) {
      throw StateError(controller.engineError!);
    }
    report['ok'] = true;
  } catch (error) {
    report['ok'] = false;
    report['error'] = error.toString();
  } finally {
    await controller?.shutdown();
  }
  await File(
    reportPath,
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  return report['ok'] == true ? 0 : 1;
}
