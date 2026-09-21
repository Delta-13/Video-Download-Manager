import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'design.dart';

class NewTaskDialog extends StatefulWidget {
  final DownloadController controller;
  const NewTaskDialog(this.controller, {super.key});
  @override
  State<NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<NewTaskDialog> {
  final urls = TextEditingController();
  late final directory = TextEditingController(
    text: widget.controller.directory,
  );
  late final options = widget.controller.defaults();
  final inspection = 'inspect-${const Uuid().v4()}';
  final results = <({String source, TaskKind kind, VideoInfo? info})>[];
  final selected = <int>{};
  bool busy = false, adding = false, scheduled = false;
  TaskKind? overrideKind;
  String? error;
  DateTime date = DateTime.now().add(const Duration(hours: 1));
  RepeatRule repeat = RepeatRule.once;
  @override
  void dispose() {
    widget.controller.videos.stop(inspection);
    urls.dispose();
    directory.dispose();
    super.dispose();
  }

  Future<void> inspect() async {
    setState(() {
      busy = true;
      error = null;
      results.clear();
      selected.clear();
    });
    try {
      final inputs = urls.text
          .split(RegExp(r'[\r\n]+'))
          .where((s) => s.trim().isNotEmpty)
          .toSet();
      if (inputs.isEmpty) {
        throw const FormatException('请粘贴一个或多个链接，每行一个');
      }
      for (final input in inputs) {
        final source = validateSource(input, allowTorrentFile: true);
        final kind = overrideKind ?? detectKind(source);
        if (kind == TaskKind.video) {
          final info = await widget.controller.videos.inspect(
            source,
            inspection,
          );
          if (!mounted) {
            return;
          }
          if (info.collection) {
            for (final entry in info.entries) {
              var link = entry.url;
              if (!link.startsWith('http') &&
                  entry.raw['ie_key'] == 'Youtube') {
                link = 'https://www.youtube.com/watch?v=${entry.raw['id']}';
              }
              if (Uri.tryParse(link)?.hasAuthority == true) {
                results.add((source: link, kind: kind, info: entry));
              }
            }
          } else {
            results.add((source: source, kind: kind, info: info));
          }
        } else {
          results.add((source: source, kind: kind, info: null));
        }
      }
      if (results.isEmpty) {
        throw const FormatException('未找到可下载条目。请尝试单条视频链接。');
      }
      selected.addAll(List.generate(results.length, (i) => i));
    } catch (e) {
      if (mounted) {
        error = e is FormatException
            ? e.message
            : e is StateError
            ? e.message.toString()
            : '解析失败，请检查链接与网络。';
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> add() async {
    setState(() {
      adding = true;
      error = null;
    });
    try {
      options.directory = directory.text;
      if (scheduled && !date.isAfter(DateTime.now())) {
        throw const FormatException('计划时间必须晚于当前时间');
      }
      await widget.controller.validateDirectory(options.directory);
      for (final i in selected.toList()..sort()) {
        final row = results[i];
        await widget.controller.add(
          row.source,
          options,
          kind: row.kind,
          title: row.info?.title,
          identity: row.info?.identity,
          schedule: scheduled ? Schedule(date, repeat: repeat) : null,
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          adding = false;
          error = e is FormatException ? e.message : '无法创建任务，请检查下载目录。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final info = results.length == 1 ? results.first.info : null;
    final heights =
        info?.formats
            .map((f) => f['height'])
            .whereType<num>()
            .map((n) => n.toInt())
            .toSet()
            .toList() ??
        <int>[];
    heights.sort((a, b) => b.compareTo(a));
    final languages =
        info?.formats
            .map((f) => f['language'])
            .whereType<String>()
            .toSet()
            .toList() ??
        <String>[];
    final formats =
        info?.formats
            .where((f) => f['vcodec'] != 'none' && f['format_id'] != null)
            .toList() ??
        [];
    return Dialog(
      child: SizedBox(
        width: 760,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height - 64,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
                child: Row(
                  children: [
                    VIcon('plus', color: c.accent),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '新建下载任务',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ActionIcon(
                      'close',
                      '关闭',
                      adding ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: urls,
                        maxLines: 3,
                        enabled: !busy && !adding,
                        decoration: const InputDecoration(
                          labelText: '网页、文件或磁力链接',
                          hintText: '粘贴链接，每行一个',
                        ),
                        onChanged: (_) {
                          if (results.isNotEmpty) {
                            setState(() => results.clear());
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<TaskKind?>(
                              isExpanded: true,
                              initialValue: overrideKind,
                              decoration: const InputDecoration(
                                labelText: '任务类型',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('自动识别'),
                                ),
                                DropdownMenuItem(
                                  value: TaskKind.video,
                                  child: Text('视频网页'),
                                ),
                                DropdownMenuItem(
                                  value: TaskKind.file,
                                  child: Text('普通文件'),
                                ),
                                DropdownMenuItem(
                                  value: TaskKind.torrent,
                                  child: Text('Torrent / 磁力'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() {
                                      overrideKind = v;
                                      results.clear();
                                    }),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    final f = await openFile(
                                      acceptedTypeGroups: const [
                                        XTypeGroup(
                                          label: 'Torrent',
                                          extensions: ['torrent'],
                                        ),
                                      ],
                                    );
                                    if (f != null && mounted) {
                                      setState(() {
                                        urls.text = f.path;
                                        overrideKind = TaskKind.torrent;
                                        results.clear();
                                      });
                                    }
                                  },
                            icon: const VIcon('folder'),
                            label: const Text('导入种子'),
                          ),
                          BusyButton(
                            busy: busy,
                            text: '解析链接',
                            busyText: '正在解析',
                            onPressed: widget.controller.ready ? inspect : null,
                          ),
                          if (busy)
                            TextButton(
                              onPressed: () async {
                                await widget.controller.videos.stop(inspection);
                              },
                              child: const Text('取消解析'),
                            ),
                        ],
                      ),
                      if (busy) ...[
                        const SizedBox(height: 20),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(
                          '正在读取网站信息，大型播放列表可能需要较长时间。',
                          style: TextStyle(color: c.secondary, fontSize: 12),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        SelectableText(
                          error!,
                          style: TextStyle(color: c.accent),
                        ),
                      ],
                      if (results.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          '已解析 ${results.length} 项 · 已选择 ${selected.length} 项',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: c.border),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: results.length,
                            itemBuilder: (context, i) => CheckboxListTile(
                              value: selected.contains(i),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              title: Text(
                                results[i].info?.title ?? results[i].source,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onChanged: adding
                                  ? null
                                  : (v) => setState(() {
                                      if (v == true) {
                                        selected.add(i);
                                      } else {
                                        selected.remove(i);
                                      }
                                    }),
                            ),
                          ),
                        ),
                        if (results.any((r) => r.kind == TaskKind.video)) ...[
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: 190,
                                child: DropdownButtonFormField<int?>(
                                  initialValue: options.height,
                                  decoration: const InputDecoration(
                                    labelText: '最高分辨率',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('最佳画质'),
                                    ),
                                    ...((heights.isEmpty
                                            ? [2160, 1440, 1080, 720, 480]
                                            : heights)
                                        .map(
                                          (h) => DropdownMenuItem(
                                            value: h,
                                            child: Text('${h}p'),
                                          ),
                                        )),
                                  ],
                                  onChanged: (v) => setState(() {
                                    options.height = v;
                                    options.formatId = null;
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: 190,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: options.audioLanguage,
                                  decoration: const InputDecoration(
                                    labelText: '音轨语言',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('默认音轨'),
                                    ),
                                    ...languages.map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => options.audioLanguage = v),
                                ),
                              ),
                              SizedBox(
                                width: 190,
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('仅音频 MP3'),
                                  value: options.audioOnly,
                                  onChanged: (v) =>
                                      setState(() => options.audioOnly = v!),
                                ),
                              ),
                            ],
                          ),
                          if (formats.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String?>(
                              initialValue: options.formatId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '视频格式',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('按分辨率自动选择并合并音频'),
                                ),
                                ...formats.map((f) {
                                  final value =
                                      '${f['format_id']}${f['acodec'] == 'none' ? '+ba' : ''}';
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      '${f['height'] ?? '未知'}p · ${f['ext']} · ${f['vcodec']} · ${f['format_id']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: options.audioOnly
                                  ? null
                                  : (v) => setState(() => options.formatId = v),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: 300,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: null,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '字幕',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('不下载字幕'),
                                    ),
                                    ...?info?.subtitles.keys.map(
                                      (s) => DropdownMenuItem(
                                        value: 'manual:$s',
                                        child: Text('$s · 原生字幕'),
                                      ),
                                    ),
                                    ...?info?.automaticCaptions.keys.map(
                                      (s) => DropdownMenuItem(
                                        value: 'auto:$s',
                                        child: Text('$s · 自动字幕'),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    options.subtitle = v?.split(':').last;
                                    options.automaticSubtitle =
                                        v?.startsWith('auto:') ?? false;
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: 130,
                                child: DropdownButtonFormField<String>(
                                  initialValue: options.subtitleFormat,
                                  decoration: const InputDecoration(
                                    labelText: '字幕格式',
                                  ),
                                  items: ['srt', 'vtt', 'ass']
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s.toUpperCase()),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => options.subtitleFormat = v!,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (results.any((r) => r.kind == TaskKind.torrent)) ...[
                          const SizedBox(height: 16),
                          Text(
                            '添加后获取种子元数据，在任务详情中勾选文件后开始下载。',
                            style: TextStyle(color: c.secondary),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            children: [
                              SizedBox(
                                width: 240,
                                child: DropdownButtonFormField<int>(
                                  initialValue: options.seedMinutes,
                                  decoration: const InputDecoration(
                                    labelText: '下载完成后做种',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 0,
                                      child: Text('停止做种'),
                                    ),
                                    DropdownMenuItem(
                                      value: 30,
                                      child: Text('最多 30 分钟'),
                                    ),
                                    DropdownMenuItem(
                                      value: 120,
                                      child: Text('最多 2 小时'),
                                    ),
                                  ],
                                  onChanged: (v) => options.seedMinutes = v!,
                                ),
                              ),
                              SizedBox(
                                width: 190,
                                child: DropdownButtonFormField<double>(
                                  initialValue: options.seedRatio,
                                  decoration: const InputDecoration(
                                    labelText: '做种分享率上限',
                                  ),
                                  items: [1.0, 2.0, 3.0]
                                      .map(
                                        (v) => DropdownMenuItem(
                                          value: v,
                                          child: Text('$v'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => options.seedRatio = v!,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: directory,
                              decoration: const InputDecoration(
                                labelText: '保存到',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ActionIcon('folder', '选择下载目录', () async {
                            final path = await getDirectoryPath();
                            if (path != null) {
                              directory.text = path;
                            }
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('计划下载'),
                        subtitle: const Text('应用驻留托盘时按本机时间执行'),
                        value: scheduled,
                        onChanged: (v) => setState(() => scheduled = v!),
                      ),
                      if (scheduled)
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              icon: const VIcon('clock'),
                              label: Text(
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                              ),
                              onPressed: () async {
                                final day = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 3650),
                                  ),
                                );
                                if (day == null || !context.mounted) {
                                  return;
                                }
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(date),
                                );
                                if (time != null && mounted) {
                                  setState(
                                    () => date = DateTime(
                                      day.year,
                                      day.month,
                                      day.day,
                                      time.hour,
                                      time.minute,
                                    ),
                                  );
                                }
                              },
                            ),
                            SizedBox(
                              width: 140,
                              child: DropdownButtonFormField<RepeatRule>(
                                initialValue: repeat,
                                items: const [
                                  DropdownMenuItem(
                                    value: RepeatRule.once,
                                    child: Text('仅一次'),
                                  ),
                                  DropdownMenuItem(
                                    value: RepeatRule.daily,
                                    child: Text('每天'),
                                  ),
                                  DropdownMenuItem(
                                    value: RepeatRule.weekly,
                                    child: Text('每周'),
                                  ),
                                ],
                                onChanged: (v) => setState(() => repeat = v!),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: adding ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    BusyButton(
                      busy: adding,
                      text: scheduled ? '创建计划' : '加入下载队列',
                      busyText: '正在添加',
                      onPressed:
                          !busy && selected.isNotEmpty && results.isNotEmpty
                          ? add
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
