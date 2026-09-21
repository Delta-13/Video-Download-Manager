import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../core/engines.dart';
import '../core/native.dart';
import '../core/store.dart';
import 'document.dart';
import 'translator.dart';

class SubtitleWorkspace extends ChangeNotifier {
  final TaskStore store;
  final EnginePaths engines;
  final String dataDirectory;
  SubtitleDocument? document;
  String? jobId, error, lastExport;
  String stage = '导入字幕，或使用本地模型从音视频生成字幕';
  bool busy = false, _canceled = false;
  SubtitleTranslator? _translator;
  ManagedProcess? _process;
  Future<void>? _operation;
  SubtitleWorkspace(this.store, this.engines, this.dataDirectory) {
    store.db.execute(
      'CREATE TABLE IF NOT EXISTS subtitle_jobs (id TEXT PRIMARY KEY, updated TEXT NOT NULL, data TEXT NOT NULL)',
    );
    final jobs = history;
    if (jobs.isNotEmpty) openJob(jobs.first.$1);
  }
  TranslationConfig get config => TranslationConfig.fromJson(
    Map<String, dynamic>.from(
      store.setting('subtitleConfig', <String, dynamic>{}),
    ),
  );
  bool get hasKey => store.setting('subtitleApiKey', '') != '';
  String get whisperExecutable => store.setting('whisperExecutable', '');
  String get whisperModel => store.setting('whisperModel', '');
  String get whisperLanguage => store.setting('whisperLanguage', 'auto');
  List<(String, String)> get history => store.db
      .select(
        "SELECT id, json_extract(data, '\$.source') AS source FROM subtitle_jobs ORDER BY updated DESC",
      )
      .map((r) => (r['id'] as String, p.basename(r['source'] as String)))
      .toList();

  Future<void> saveConfig(
    TranslationConfig value, {
    String? apiKey,
    bool deleteKey = false,
    required String whisperExe,
    required String modelPath,
    required String language,
  }) async {
    if (busy) return;
    value.uri(value.local ? 'api/chat' : 'chat/completions');
    if (value.targetLanguage.isEmpty ||
        value.batchSize < 1 ||
        value.batchSize > 32) {
      throw const SubtitleFailure('请填写目标语言；每批字幕数量需为 1–32。');
    }
    // A saved credential is bound to its service, never reused at a new endpoint.
    String? protected;
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      protected = base64Encode(
        await NativeBridge.protect(
          Uint8List.fromList(utf8.encode(apiKey.trim())),
        ),
      );
    }
    if (deleteKey || config.endpoint != value.endpoint) {
      store.set('subtitleApiKey', '');
    }
    if (protected != null && !deleteKey) store.set('subtitleApiKey', protected);
    store.set('subtitleConfig', value.toJson());
    store.set('whisperExecutable', whisperExe.trim());
    store.set('whisperModel', modelPath.trim());
    store.set(
      'whisperLanguage',
      language.trim().isEmpty ? 'auto' : language.trim(),
    );
    notifyListeners();
  }

  void openJob(String id) {
    if (busy) return;
    final rows = store.db.select('SELECT data FROM subtitle_jobs WHERE id=?', [
      id,
    ]);
    if (rows.isEmpty) return;
    jobId = id;
    document = SubtitleDocument.fromJson(jsonDecode(rows.first['data']));
    error = null;
    lastExport = null;
    stage = '已恢复 · ${document!.translated}/${document!.cues.length} 条译文';
    notifyListeners();
  }

  void removeCurrent() {
    if (busy || jobId == null) return;
    store.db.execute('DELETE FROM subtitle_jobs WHERE id=?', [jobId]);
    jobId = null;
    document = null;
    lastExport = null;
    error = null;
    stage = '已移除字幕记录，原始文件和导出文件保留';
    notifyListeners();
  }

  void _save() {
    if (document != null && jobId != null) {
      store.db.execute('INSERT OR REPLACE INTO subtitle_jobs VALUES (?,?,?)', [
        jobId,
        DateTime.now().toIso8601String(),
        jsonEncode(document!.toJson()),
      ]);
    }
    notifyListeners();
  }

  void edit(int index, String translation) {
    if (busy || document == null) return;
    document!.cues[index].translation = translation.trim().isEmpty
        ? null
        : translation.trim();
    _save();
  }

  void _check() {
    if (_canceled) throw SubtitleCanceled();
  }

  void _stage(String value) {
    stage = value;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() body) async {
    if (busy) return;
    busy = true;
    _canceled = false;
    error = null;
    notifyListeners();
    final done = Completer<void>();
    _operation = done.future;
    try {
      await body();
    } catch (e) {
      if (_canceled || e is SubtitleCanceled) {
        stage = '已停止 · 已保存的译文可继续';
      } else {
        error = switch (e) {
          SubtitleFailure() => e.message,
          FormatException() => '字幕或模型响应格式无效。请检查文件编码，或减小批次后重试。',
          FileSystemException() => '文件操作失败，请检查文件是否存在、目录权限和可用磁盘空间。',
          _ => '字幕处理失败，请检查模型配置和服务状态。已保存的译文保留。',
        };
        stage = '处理未完成';
      }
    } finally {
      busy = false;
      _translator = null;
      _process = null;
      done.complete();
      _operation = null;
      notifyListeners();
    }
  }

  Future<void> cancel() async {
    _canceled = true;
    _translator?.cancel();
    await _process?.stop();
    await _operation;
  }

  Future<void> shutdown() async {
    await cancel();
  }

  Future<void> _command(
    String executable,
    List<String> args,
    String failure,
  ) async {
    _check();
    final process = await ManagedProcess.start(executable, args);
    _process = process;
    // Drain both pipes without exposing paths, transcripts or credentials in logs.
    final stdout = process.process.stdout.drain<void>();
    final stderr = process.process.stderr.drain<void>();
    if (_canceled) await process.stop();
    final code = await process.exitCode;
    await Future.wait([stdout, stderr]);
    _process = null;
    _check();
    if (code != 0) throw SubtitleFailure(failure);
  }

  Future<void> importFile(String path) => _run(() async {
    _stage('正在读取字幕');
    final source = File(path);
    if (!await source.exists()) throw const SubtitleFailure('所选文件不存在。');
    final temp = await Directory(
      p.join(dataDirectory, 'subtitle-temp'),
    ).create(recursive: true);
    final work = await temp.createTemp('import-');
    try {
      String subtitlePath = path;
      final ext = p.extension(path).toLowerCase();
      if (ext == '.ass' || ext == '.ssa') {
        subtitlePath = p.join(work.path, 'normalized.srt');
        await _command(engines.binary('ffmpeg'), [
          '-nostdin',
          '-v',
          'error',
          '-i',
          path,
          '-map',
          '0:s:0',
          subtitlePath,
        ], 'ASS 字幕转换失败。');
      } else if (!['.srt', '.vtt'].contains(ext)) {
        if (!await File(whisperExecutable).exists() ||
            !await File(whisperModel).exists()) {
          throw const SubtitleFailure(
            '音视频转写需要本地 whisper.cpp。请在翻译设置中选择 whisper-cli.exe 和多语言 GGML 模型。',
          );
        }
        final wav = p.join(work.path, 'audio.wav');
        _stage('正在提取音轨 · FFmpeg');
        await _command(engines.binary('ffmpeg'), [
          '-nostdin',
          '-v',
          'error',
          '-i',
          path,
          '-vn',
          '-ac',
          '1',
          '-ar',
          '16000',
          '-c:a',
          'pcm_s16le',
          wav,
        ], '音轨提取失败，请确认文件含有可解码的音频。');
        _stage('正在本地转写 · whisper.cpp，较长音频可能需要数分钟');
        final prefix = p.join(work.path, 'transcript');
        await _command(whisperExecutable, [
          '-m',
          whisperModel,
          '-f',
          wav,
          '-l',
          whisperLanguage,
          '-osrt',
          '-of',
          prefix,
          '-ng',
        ], '本地转写失败，请检查 whisper.cpp、语言代码和模型是否匹配。');
        subtitlePath = '$prefix.srt';
      }
      _check();
      if (await File(subtitlePath).length() > 20 * 1024 * 1024) {
        throw const SubtitleFailure('字幕文件超过 20 MiB，请分段导入。');
      }
      final next = SubtitleDocument.parse(
        path,
        await File(subtitlePath).readAsString(),
      );
      _check();
      jobId = const Uuid().v4();
      document = next;
      lastExport = null;
      _stage('已载入 ${next.cues.length} 条字幕');
      _save();
    } finally {
      await work.delete(recursive: true);
    }
  });

  Future<void> translate() => _run(() async {
    if (document == null) throw const SubtitleFailure('请先导入字幕。');
    final current = config;
    String? key;
    if (!current.local && hasKey) {
      key = utf8.decode(
        await NativeBridge.unprotect(
          base64Decode(store.setting('subtitleApiKey', '')),
        ),
      );
    }
    _translator = SubtitleTranslator();
    if (current.local) {
      _stage('正在检查本地模型');
      final available = await _translator!.localModels(current);
      final model = current.model.contains(':')
          ? current.model
          : '${current.model}:latest';
      if (!available.contains(current.model) && !available.contains(model)) {
        throw const SubtitleFailure('Ollama 中未找到此本地模型。请先下载模型，再检查模型名称。');
      }
    }
    await _translator!.translate(
      document!,
      current,
      apiKey: key,
      onProgress: _stage,
      checkpoint: _save,
    );
  });

  Future<void> export(
    String directory, {
    required String format,
    required bool bilingual,
    bool original = false,
  }) => _run(() async {
    if (document == null) return;
    _stage('正在导出字幕');
    final root = await Directory(
      p.join(dataDirectory, 'subtitle-temp'),
    ).create(recursive: true);
    final work = await root.createTemp('export-');
    try {
      final name =
          '${p.basenameWithoutExtension(document!.source)}.${original
              ? 'original'
              : bilingual
              ? 'bilingual'
              : 'translated'}';
      var output = File(
        p.join(work.path, '$name.${format == 'ass' ? 'srt' : format}'),
      );
      await output.writeAsString(
        document!.render(
          bilingual: bilingual,
          original: original,
          format: format,
        ),
        flush: true,
      );
      if (format == 'ass') {
        final converted = p.join(work.path, '$name.ass');
        await _command(engines.binary('ffmpeg'), [
          '-nostdin',
          '-v',
          'error',
          '-i',
          output.path,
          converted,
        ], 'ASS 导出失败。');
        output = File(converted);
      }
      _check();
      lastExport = await NativeBridge.publish(output.path, directory);
      _stage('字幕已导出');
    } finally {
      await work.delete(recursive: true);
    }
  });
}
