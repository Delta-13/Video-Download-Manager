import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../subtitles/document.dart';
import '../subtitles/translator.dart';
import '../subtitles/workspace.dart';
import 'design.dart';

class SubtitlePage extends StatefulWidget {
  final SubtitleWorkspace workspace;
  const SubtitlePage(this.workspace, {super.key});
  @override
  State<SubtitlePage> createState() => _SubtitlePageState();
}

class _SubtitlePageState extends State<SubtitlePage> {
  String format = 'srt';
  bool bilingual = true;
  SubtitleWorkspace get w => widget.workspace;
  Future<void> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: '字幕或音视频',
          extensions: [
            'srt',
            'vtt',
            'ass',
            'ssa',
            'mp4',
            'mkv',
            'webm',
            'mov',
            'mp3',
            'wav',
            'm4a',
            'flac',
            'ogg',
          ],
        ),
      ],
    );
    if (file != null && mounted) await w.importFile(file.path);
  }

  Future<void> export({bool original = false}) async {
    final directory = await getDirectoryPath(confirmButtonText: '导出到此目录');
    if (directory != null && mounted) {
      await w.export(
        directory,
        format: format,
        bilingual: bilingual,
        original: original,
      );
    }
  }

  Future<void> exportDialog() async {
    final original = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle(
        duration: motion(context, 250),
        reverseDuration: motion(context, 150),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('导出字幕'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: format,
                  icon: const VIcon('chevron-down'),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '格式'),
                  items: ['srt', 'vtt', 'ass']
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => update(() => format = v!),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: bilingual,
                  title: const Text('包含原文（双语）'),
                  onChanged: (v) => update(() => bilingual = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('仅导出原文'),
            ),
            FilledButton(
              onPressed: w.document!.translated == w.document!.cues.length
                  ? () => Navigator.pop(context, false)
                  : null,
              child: const Text('导出译文'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    if (original != null) await export(original: original);
  }

  Future<void> edit(int index) async {
    final cue = w.document!.cues[index];
    final result = await showDialog<String>(
      context: context,
      animationStyle: AnimationStyle(
        duration: motion(context, 250),
        reverseDuration: motion(context, 150),
      ),
      builder: (context) => _CueEditor(cue, index),
    );
    if (result != null) w.edit(index, result);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: w,
    builder: (context, _) {
      final c = Palette.of(context), doc = w.document, config = w.config;
      final jobs = w.history;
      return ColoredBox(
        color: c.surface,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: w.busy ? null : pick,
                          icon: const VIcon('folder'),
                          label: const Text('导入字幕 / 音视频'),
                        ),
                        OutlinedButton.icon(
                          onPressed: w.busy
                              ? null
                              : () => showSubtitleSettings(context, w),
                          icon: const VIcon('settings'),
                          label: const Text('翻译设置'),
                        ),
                        if (doc != null)
                          OutlinedButton.icon(
                            onPressed: w.busy ? null : exportDialog,
                            icon: const VIcon('download'),
                            label: const Text('导出…'),
                          ),
                        if (w.busy)
                          OutlinedButton.icon(
                            onPressed: () => unawaited(w.cancel()),
                            icon: const VIcon('close'),
                            label: const Text('停止处理'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: doc == null
                                ? null
                                : () => unawaited(w.translate()),
                            icon: VIcon('play', color: c.onAccent),
                            label: Text(
                              doc != null &&
                                      doc.translated > 0 &&
                                      doc.translated < doc.cues.length &&
                                      doc.translationKey == config.key
                                  ? '继续翻译'
                                  : '开始翻译',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${config.local ? '本地 Ollama' : '在线 API'} · ${config.model.isEmpty ? '尚未选择模型' : config.model} · ${config.targetLanguage}',
                      style: TextStyle(color: c.secondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      config.local
                          ? '使用本机已安装的模型。音视频转写始终在本地进行。'
                          : '开始翻译后，字幕正文将发送至 ${Uri.tryParse(config.endpoint)?.host ?? "所配置的服务"}。音视频文件不会上传。',
                      style: TextStyle(color: c.secondary, fontSize: 12),
                    ),
                    if (doc != null &&
                        doc.translationKey != null &&
                        doc.translationKey != config.key) ...[
                      const SizedBox(height: 8),
                      Text(
                        '设置已更改：再次开始会清除当前译文并重新翻译；可先导出已有结果。',
                        style: TextStyle(color: c.accent),
                      ),
                    ],
                    if (jobs.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        icon: const VIcon('chevron-down'),
                        key: ValueKey('${w.jobId}-${jobs.length}'),
                        initialValue: w.jobId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '字幕记录'),
                        items: [
                          for (var i = 0; i < jobs.length; i++)
                            DropdownMenuItem(
                              value: jobs[i].$1,
                              child: Text(
                                '${jobs.length - i}. ${jobs[i].$2}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: w.busy
                            ? null
                            : (id) {
                                if (id != null) w.openJob(id);
                              },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: c.border.withValues(alpha: .35)),
                      bottom: BorderSide(
                        color: c.border.withValues(alpha: .35),
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.error ?? w.stage,
                        style: TextStyle(
                          color: w.error != null ? c.accent : c.text,
                        ),
                      ),
                      if (w.busy) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          semanticsLabel: '字幕处理进度',
                          value: w.stage.contains('翻译') && doc != null
                              ? doc.translated / doc.cues.length
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (doc == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VIcon('subtitles', size: 42, color: c.accent),
                        const SizedBox(height: 20),
                        const Text(
                          '为视频补上另一种语言',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '导入 SRT、VTT、ASS；或用 whisper.cpp 转写音视频。\n保留原始时间轴，逐条校对，导出译文或双语字幕。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.secondary),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: doc.cues.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, i) {
                  final cue = doc.cues[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${i + 1}   ${timestamp(cue.start)} — ${timestamp(cue.end)}',
                                style: TextStyle(
                                  color: c.secondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: '校对此条译文',
                              child: TextButton(
                                onPressed: w.busy ? null : () => edit(i),
                                child: const Text('校对'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final original = SelectableText(
                              cue.text,
                              style: TextStyle(color: c.secondary, height: 1.6),
                            );
                            final translated = SelectableText(
                              cue.translation ?? '等待翻译',
                              style: TextStyle(
                                color: cue.translation == null
                                    ? c.secondary
                                    : c.text,
                                height: 1.6,
                              ),
                            );
                            return constraints.maxWidth > 850
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: original),
                                      const SizedBox(width: 32),
                                      Expanded(child: translated),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      original,
                                      const SizedBox(height: 10),
                                      translated,
                                    ],
                                  );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (doc != null)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(format),
                          icon: const VIcon('chevron-down'),
                          isExpanded: true,
                          initialValue: format,
                          decoration: const InputDecoration(labelText: '格式'),
                          items: ['srt', 'vtt', 'ass']
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: w.busy
                              ? null
                              : (v) => setState(() => format = v!),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: bilingual,
                            onChanged: w.busy
                                ? null
                                : (v) => setState(() => bilingual = v!),
                          ),
                          const Text('双语'),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: w.busy || doc.translated != doc.cues.length
                            ? null
                            : export,
                        icon: const VIcon('download'),
                        label: const Text('导出字幕'),
                      ),
                      TextButton(
                        onPressed: w.busy ? null : () => export(original: true),
                        child: const Text('导出原文'),
                      ),
                      TextButton(
                        onPressed: w.busy ? null : w.removeCurrent,
                        child: const Text('移除记录'),
                      ),
                      if (w.lastExport != null)
                        Tooltip(
                          message: w.lastExport!,
                          child: TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.directory(
                                p.dirname(w.lastExport!),
                                windows: true,
                              ),
                            ),
                            icon: const VIcon('folder'),
                            label: const Text('打开导出目录'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _CueEditor extends StatefulWidget {
  final SubtitleCue cue;
  final int index;
  const _CueEditor(this.cue, this.index);
  @override
  State<_CueEditor> createState() => _CueEditorState();
}

class _CueEditorState extends State<_CueEditor> {
  late final input = TextEditingController(text: widget.cue.translation ?? '');
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('校对字幕 ${widget.index + 1}'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(widget.cue.text),
            const SizedBox(height: 20),
            TextField(
              controller: input,
              minLines: 3,
              maxLines: 10,
              decoration: const InputDecoration(labelText: '译文'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, input.text),
        child: const Text('保存'),
      ),
    ],
  );
}

Future<void> showSubtitleSettings(
  BuildContext context,
  SubtitleWorkspace workspace,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  animationStyle: AnimationStyle(
    duration: motion(context, 250),
    reverseDuration: motion(context, 150),
  ),
  builder: (_) => _SubtitleSettings(workspace),
);

class _SubtitleSettings extends StatefulWidget {
  final SubtitleWorkspace workspace;
  const _SubtitleSettings(this.workspace);
  @override
  State<_SubtitleSettings> createState() => _SubtitleSettingsState();
}

class _SubtitleSettingsState extends State<_SubtitleSettings> {
  late bool local = widget.workspace.config.local;
  late final endpoint = TextEditingController(
    text: widget.workspace.config.endpoint,
  );
  late final model = TextEditingController(text: widget.workspace.config.model);
  late final target = TextEditingController(
    text: widget.workspace.config.targetLanguage,
  );
  late final source = TextEditingController(
    text: widget.workspace.config.sourceLanguage,
  );
  late final batch = TextEditingController(
    text: '${widget.workspace.config.batchSize}',
  );
  late final exe = TextEditingController(
    text: widget.workspace.whisperExecutable,
  );
  late final ggml = TextEditingController(text: widget.workspace.whisperModel);
  late final language = TextEditingController(
    text: widget.workspace.whisperLanguage,
  );
  final keyInput = TextEditingController();
  bool saving = false, checking = false, deleteKey = false;
  String? error;
  List<String> models = [];
  SubtitleTranslator? probe;
  TranslationConfig get config => TranslationConfig(
    local: local,
    endpoint: endpoint.text.trim(),
    model: model.text.trim(),
    targetLanguage: target.text.trim(),
    sourceLanguage: source.text.trim(),
    batchSize: int.tryParse(batch.text) ?? 0,
  );
  @override
  void dispose() {
    probe?.cancel();
    for (final c in [
      endpoint,
      model,
      target,
      source,
      batch,
      exe,
      ggml,
      language,
      keyInput,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.workspace.saveConfig(
        config,
        apiKey: keyInput.text,
        deleteKey: deleteKey,
        whisperExe: exe.text,
        modelPath: ggml.text,
        language: language.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is SubtitleFailure ? e.message : '无法保存设置或加密密钥，请重试。',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> checkModels() async {
    setState(() {
      checking = true;
      error = null;
      models = [];
    });
    probe = SubtitleTranslator(timeout: const Duration(seconds: 15));
    try {
      final result = await probe!.localModels(config);
      if (mounted) {
        setState(() {
          models = result;
          if (result.isEmpty) error = '没有本地模型。请先通过 Ollama 下载翻译模型。';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is SubtitleFailure ? e.message : '读取模型列表失败。');
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Widget field(
    TextEditingController input,
    String label, {
    String? hint,
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: input,
      enabled: !saving && !checking,
      obscureText: secret,
      autocorrect: false,
      enableSuggestions: !secret,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 3,
      ),
    ),
  );
  Widget pathField(
    TextEditingController input,
    String label,
    List<String> extensions,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: field(input, label)),
      const SizedBox(width: 8),
      Tooltip(
        message: '选择$label',
        child: IconButton(
          onPressed: saving || checking
              ? null
              : () async {
                  final file = await openFile(
                    acceptedTypeGroups: [
                      XTypeGroup(label: label, extensions: extensions),
                    ],
                  );
                  if (file != null && mounted) input.text = file.path;
                },
          icon: const VIcon('folder'),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('AI 字幕设置'),
    content: SizedBox(
      width: 660,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<bool>(
              icon: const VIcon('chevron-down'),
              isExpanded: true,
              initialValue: local,
              decoration: const InputDecoration(labelText: '翻译服务'),
              items: const [
                DropdownMenuItem(value: true, child: Text('本地 Ollama')),
                DropdownMenuItem(
                  value: false,
                  child: Text('在线 · OpenAI 兼容 API'),
                ),
              ],
              onChanged: saving || checking
                  ? null
                  : (v) => setState(() {
                      local = v!;
                      models = [];
                      model.clear();
                      endpoint.text = local
                          ? 'http://127.0.0.1:11434'
                          : 'https://api.deepseek.com/v1';
                    }),
            ),
            const SizedBox(height: 20),
            field(
              endpoint,
              '基础地址',
              hint: local
                  ? 'Ollama 本机地址；不使用云端模型。'
                  : '填写服务商的兼容 API 基础地址，通常以 /v1 结尾。需支持 Chat Completions 和 JSON 输出。',
            ),
            field(
              model,
              '模型名称',
              hint: local ? '填写已安装的模型名称，或从下方读取。' : '填写服务商提供的模型 ID。',
            ),
            if (local) ...[
              OutlinedButton(
                onPressed: saving || checking ? null : checkModels,
                child: Text(checking ? '正在读取…' : '读取本地模型'),
              ),
              if (checking)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              if (models.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: DropdownButtonFormField<String>(
                    icon: const VIcon('chevron-down'),
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '选择已安装模型'),
                    items: models
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) model.text = v;
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ] else ...[
              field(
                keyInput,
                'API 密钥',
                secret: true,
                hint: widget.workspace.hasKey
                    ? '密钥已加密保存；留空保留。更换服务地址会清除旧密钥。'
                    : '只在当前 Windows 用户下使用 DPAPI 加密保存。',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: deleteKey,
                onChanged: saving
                    ? null
                    : (v) => setState(() => deleteKey = v!),
                title: const Text('删除已保存的密钥'),
              ),
            ],
            field(source, '原文语言'),
            field(target, '目标语言'),
            field(batch, '每批字幕数量', hint: '1–32；较小批次适合本地小模型。中断后按已保存批次继续。'),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              '本地音视频转写 · 可选',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('仅在没有字幕时使用。选择官方 whisper.cpp 程序与多语言 GGML 模型；不会自动下载模型。'),
            const SizedBox(height: 20),
            pathField(exe, 'whisper-cli.exe', ['exe']),
            pathField(ggml, 'GGML 模型文件', ['bin']),
            field(language, '转写语言代码', hint: 'auto 自动识别；也可填写 en、zh、ja 等。'),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Palette.of(context).accent),
                ),
              ),
            if (saving) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: saving || checking ? null : save,
        child: Text(saving ? '正在保存…' : '保存设置'),
      ),
    ],
  );
}
