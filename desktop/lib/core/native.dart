import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class NativeBridge {
  static const channel = MethodChannel('io.vdm/native');
  static Future<void> attach(int pid) async =>
      channel.invokeMethod('attachProcess', {'pid': pid});
  static Future<void> terminate(int pid) async =>
      channel.invokeMethod('terminateProcess', {'pid': pid});
  static Future<void> release(int pid) async =>
      channel.invokeMethod('releaseProcess', {'pid': pid});
  static Future<Uint8List> protect(Uint8List data) async =>
      (await channel.invokeMethod<Uint8List>('protect', data))!;
  static Future<Uint8List> unprotect(Uint8List data) async =>
      (await channel.invokeMethod<Uint8List>('unprotect', data))!;
  static Future<void> restrictFile(String path) async =>
      channel.invokeMethod('restrictFile', path);
  static Future<bool> moveExclusive(String from, String to) async =>
      (await channel.invokeMethod<bool>('moveExclusive', {
        'from': from,
        'to': to,
      }))!;
  static Future<void> startInbox(String directory) async =>
      channel.invokeMethod('startInbox', directory);
  static Future<void> registerBrowser(String extensionId) async =>
      channel.invokeMethod('registerBrowser', extensionId);
  static Future<String> publish(String source, String directory) async {
    await Directory(directory).create(recursive: true);
    final base = p.basenameWithoutExtension(source);
    final ext = p.extension(source);
    for (var i = 0; i < 10000; i++) {
      final dest = p.join(directory, '$base${i == 0 ? '' : ' ($i)'}$ext');
      if (await moveExclusive(source, dest)) {
        return dest;
      }
    }
    throw const FileSystemException('Too many conflicting filenames');
  }
}
