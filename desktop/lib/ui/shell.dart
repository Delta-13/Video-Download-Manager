import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import '../core/controller.dart';
import '../core/models.dart';
import 'design.dart';
import 'new_task.dart';
import 'settings.dart';

class DownloadShell extends ConsumerWidget {
  const DownloadShell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(downloadsProvider);
    final colors = Palette.of(context);
    void add() => unawaited(
      showDialog(
        context: context,
        animationStyle: AnimationStyle(
          duration: motion(context, 250),
          reverseDuration: motion(context, 150),
        ),
        barrierDismissible: false,
        builder: (_) => NewTaskDialog(controller),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): add,
      },
      child: Scaffold(
        body: CustomPaint(
          painter: IndustrialBackdrop(colors),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final small = bounds.maxWidth < 1080;
              return Row(
                children: [
                  SizedBox(
                    width: small ? 76 : 224,
                    child: _Sidebar(controller, compact: small),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Glass(
                          reduced: controller.reduceTransparency,
                          padding: const EdgeInsets.fromLTRB(28, 22, 24, 22),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.filter == 'settings'
                                          ? '偏好设置'
                                          : '下载任务',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      controller.filter == 'settings'
                                          ? '外观、下载与浏览器连接'
                                          : '${controller.tasks.where((t) => t.status.active).length} 项正在进行 · ${controller.tasks.length} 项任务',
                                      style: TextStyle(
                                        color: colors.secondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: controller.ready ? add : null,
                                icon: VIcon('plus', color: colors.onAccent),
                                label: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('新建任务'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (controller.engineError != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: colors.accent),
                              ),
                            ),
                            child: Text(
                              controller.engineError!,
                              style: TextStyle(color: colors.accent),
                            ),
                          ),
                        Expanded(
                          child: controller.filter == 'settings'
                              ? SettingsPage(controller)
                              : Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.fromLTRB(
                                              24,
                                              18,
                                              20,
                                              18,
                                            ),
                                            child: Wrap(
                                              alignment:
                                                  WrapAlignment.spaceBetween,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 16,
                                              runSpacing: 12,
                                              children: [
                                                SizedBox(
                                                  width: small ? 220 : 280,
                                                  child: TextField(
                                                    onChanged: controller.find,
                                                    decoration: InputDecoration(
                                                      hintText: '搜索任务或站点',
                                                      prefixIcon: const Padding(
                                                        padding: EdgeInsets.all(
                                                          12,
                                                        ),
                                                        child: VIcon('search'),
                                                      ),
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (controller
                                                        .selected
                                                        .isNotEmpty)
                                                      Text(
                                                        '已选 ${controller.selected.length}',
                                                        style: TextStyle(
                                                          color:
                                                              colors.secondary,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ActionIcon(
                                                      'pause',
                                                      controller
                                                              .selected
                                                              .isEmpty
                                                          ? '全部暂停'
                                                          : '暂停所选',
                                                      () => _action(
                                                        context,
                                                        controller.bulk(true),
                                                      ),
                                                    ),
                                                    ActionIcon(
                                                      'play',
                                                      controller
                                                              .selected
                                                              .isEmpty
                                                          ? '恢复暂停任务'
                                                          : '恢复所选',
                                                      () => _action(
                                                        context,
                                                        controller.bulk(false),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Divider(),
                                          Expanded(
                                            child: controller.visible.isEmpty
                                                ? _Empty(controller, add)
                                                : ListView.separated(
                                                    itemCount: controller
                                                        .visible
                                                        .length,
                                                    separatorBuilder: (_, _) =>
                                                        const Divider(),
                                                    itemBuilder: (context, i) {
                                                      final task =
                                                          controller.visible[i];
                                                      return _TaskRow(
                                                        task,
                                                        controller,
                                                        onOpen: () {
                                                          controller.focus(
                                                            task.id,
                                                          );
                                                          if (small) {
                                                            showModalBottomSheet(
                                                              context: context,
                                                              sheetAnimationStyle:
                                                                  AnimationStyle(
                                                                    duration:
                                                                        motion(
                                                                          context,
                                                                          250,
                                                                        ),
                                                                    reverseDuration:
                                                                        motion(
                                                                          context,
                                                                          200,
                                                                        ),
                                                                  ),
                                                              isScrollControlled:
                                                                  true,
                                                              shape:
                                                                  const RoundedRectangleBorder(),
                                                              builder: (_) => SizedBox(
                                                                height:
                                                                    MediaQuery.sizeOf(
                                                                      context,
                                                                    ).height *
                                                                    .8,
                                                                child: ListenableBuilder(
                                                                  listenable:
                                                                      controller,
                                                                  builder: (_, _) =>
                                                                      TaskDetails(
                                                                        task,
                                                                        controller,
                                                                      ),
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        },
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!small && controller.detail != null)
                                      SizedBox(
                                        width: 330,
                                        child: Glass(
                                          reduced:
                                              controller.reduceTransparency,
                                          child: TaskDetails(
                                            controller.detail!,
                                            controller,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: colors.border.withValues(alpha: .35),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              VIcon('download', size: 14, color: colors.accent),
                              const SizedBox(width: 8),
                              Text(
                                '${bytesLabel(controller.totalSpeed)}/s',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const Spacer(),
                              Text(
                                controller.ready
                                    ? '下载引擎就绪'
                                    : controller.initializing
                                    ? '正在准备下载引擎…'
                                    : '下载引擎未就绪',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

void _action(BuildContext context, Future<void> action) {
  action.catchError((Object e) {
    if (context.mounted) {
      showMessage(context, e);
    }
  });
}

class _Sidebar extends StatelessWidget {
  final DownloadController controller;
  final bool compact;
  const _Sidebar(this.controller, {required this.compact});
  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    const entries = [
      ('all', 'all', '全部任务'),
      ('active', 'download', '正在下载'),
      ('paused', 'pause', '已暂停'),
      ('completed', 'check', '已完成'),
      ('failed', 'error', '失败'),
      ('scheduled', 'clock', '计划任务'),
    ];
    return Glass(
      reduced: controller.reduceTransparency,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 24,
              30,
              compact ? 16 : 24,
              32,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  color: c.accent,
                  alignment: Alignment.center,
                  child: VIcon('download', color: c.onAccent, size: 23),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VDM',
                        style: TextStyle(
                          fontSize: 24,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('2.0.0', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ...entries.map((e) => _nav(context, e.$1, e.$2, e.$3)),
          const Spacer(),
          _nav(context, 'settings', 'settings', '设置'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _nav(BuildContext context, String id, String icon, String label) {
    final c = Palette.of(context);
    final selected = controller.filter == id;
    final count = switch (id) {
      'all' => controller.tasks.length,
      'active' =>
        controller.tasks
            .where(
              (t) =>
                  t.status.active ||
                  t.status == TaskStatus.queued ||
                  t.status == TaskStatus.awaitingSelection ||
                  t.status == TaskStatus.seeding,
            )
            .length,
      'paused' =>
        controller.tasks.where((t) => t.status == TaskStatus.paused).length,
      'completed' =>
        controller.tasks.where((t) => t.status == TaskStatus.completed).length,
      'failed' =>
        controller.tasks.where((t) => t.status == TaskStatus.failed).length,
      'scheduled' =>
        controller.tasks.where((t) => t.status == TaskStatus.scheduled).length,
      _ => 0,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
      child: Tooltip(
        message: compact ? label : '',
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: KeyboardFrame(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                hoverDuration: motion(context, 150),
                mouseCursor: SystemMouseCursors.click,
                onTap: () => controller.view(id),
                child: AnimatedContainer(
                  duration: motion(context, 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 15 : 14,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? c.accent.withValues(alpha: .1)
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: selected ? c.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      VIcon(
                        icon,
                        color: selected ? c.accent : c.secondary,
                        size: 18,
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected ? c.accent : c.text,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (id != 'settings')
                          Text(
                            '$count',
                            style: TextStyle(color: c.secondary, fontSize: 11),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final DownloadController controller;
  final VoidCallback add;
  const _Empty(this.controller, this.add);
  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: c.border)),
              child: VIcon('download', size: 34, color: c.accent),
            ),
            const SizedBox(height: 24),
            Text(
              controller.tasks.isEmpty ? '准备好下一次下载' : '没有匹配的任务',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Text(
              controller.tasks.isEmpty
                  ? '粘贴视频网页、文件或磁力链接。\n视频、文件与 Torrent，在同一处管理。'
                  : '尝试更改筛选条件或搜索内容。',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.secondary, height: 1.8, fontSize: 13),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: controller.ready ? add : null,
              icon: const VIcon('plus'),
              label: const Text('新建任务'),
            ),
            const SizedBox(height: 18),
            Text(
              'YouTube / Instagram / X / Pornhub',
              style: TextStyle(color: c.secondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final DownloadTask task;
  final DownloadController controller;
  final VoidCallback onOpen;
  const _TaskRow(this.task, this.controller, {required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final active = controller.focused == task.id;
    return KeyboardFrame(
      child: Material(
        color: active ? c.accent.withValues(alpha: .06) : c.surface,
        child: InkWell(
          hoverDuration: motion(context, 150),
          mouseCursor: SystemMouseCursors.click,
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 20, 18, 20),
            child: Row(
              children: [
                Checkbox(
                  value: controller.selected.contains(task.id),
                  onChanged: (v) => controller.select(task.id, v!),
                ),
                Container(
                  width: 42,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border.withValues(alpha: .5)),
                  ),
                  alignment: Alignment.center,
                  child: VIcon(task.kind.name, color: c.secondary),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            task.status.label,
                            style: TextStyle(
                              color:
                                  task.status == TaskStatus.failed ||
                                      task.status.active ||
                                      task.status ==
                                          TaskStatus.awaitingSelection
                                  ? c.accent
                                  : c.secondary,
                              fontSize: 11,
                            ),
                          ),
                          if (task.host.isNotEmpty)
                            Text(
                              task.host,
                              style: TextStyle(
                                color: c.secondary,
                                fontSize: 11,
                              ),
                            ),
                          if (task.status == TaskStatus.downloading)
                            Text(
                              '${bytesLabel(task.progress.speed)}/s',
                              style: TextStyle(
                                color: c.secondary,
                                fontSize: 11,
                              ),
                            ),
                          if (task.schedule?.missed == true)
                            Text(
                              '已错过执行时间',
                              style: TextStyle(color: c.accent, fontSize: 11),
                            ),
                        ],
                      ),
                      if (task.status == TaskStatus.downloading ||
                          task.status == TaskStatus.merging ||
                          task.status == TaskStatus.converting ||
                          task.status == TaskStatus.resolving) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: task.status == TaskStatus.downloading
                              ? task.progress.fraction
                              : null,
                          semanticsLabel: '${task.title} 下载进度',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${bytesLabel(task.progress.received)} / ${task.progress.total > 0 ? bytesLabel(task.progress.total) : '大小未知'}',
                          style: TextStyle(color: c.secondary, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (task.canPause)
                  ActionIcon(
                    'pause',
                    '暂停下载',
                    () => _action(context, controller.pause(task)),
                  )
                else if (task.canResume)
                  ActionIcon(
                    task.status == TaskStatus.failed ? 'retry' : 'play',
                    '继续下载',
                    () => _action(context, controller.resume(task)),
                  )
                else if (task.status == TaskStatus.completed)
                  const VIcon('check', size: 18)
                else
                  ActionIcon('arrow', '查看任务', onOpen),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskDetails extends StatefulWidget {
  final DownloadTask task;
  final DownloadController controller;
  const TaskDetails(this.task, this.controller, {super.key});
  @override
  State<TaskDetails> createState() => _TaskDetailsState();
}

class _TaskDetailsState extends State<TaskDetails> {
  Set<int> selected = {};
  String? selectedId;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final c = Palette.of(context);
    final controller = widget.controller;
    if (selectedId != t.id && t.files.isNotEmpty) {
      selectedId = t.id;
      selected = t.files.map((f) => f.index).toSet();
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '任务详情',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            ActionIcon('close', '收起详情', () => controller.focus(null)),
          ],
        ),
        const SizedBox(height: 28),
        VIcon(t.kind.name, size: 44, color: c.accent),
        const SizedBox(height: 20),
        SelectableText(
          t.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        Text(t.status.label, style: TextStyle(color: c.accent)),
        const SizedBox(height: 24),
        _field('来源', t.host.isEmpty ? 'BitTorrent' : t.host),
        _field('已下载', bytesLabel(t.progress.received)),
        _field(
          '大小',
          t.progress.total > 0 ? bytesLabel(t.progress.total) : '未知',
        ),
        if (t.kind != TaskKind.video)
          _field('连接数', '${t.progress.connections}'),
        if (t.progress.eta != null) _field('剩余时间', '${t.progress.eta} 秒'),
        if (t.kind == TaskKind.torrent) ...[
          _field('上传速度', '${bytesLabel(t.progress.uploadSpeed)}/s'),
          _field('分享率', t.progress.ratio.toStringAsFixed(2)),
        ],
        _field('保存到', t.options.directory),
        if (t.schedule != null)
          _field('下次执行', t.schedule!.next.toString().substring(0, 16)),
        if (t.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              t.error!,
              style: TextStyle(color: c.accent, height: 1.7),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (t.canPause)
              OutlinedButton.icon(
                onPressed: () => _action(context, controller.pause(t)),
                icon: const VIcon('pause'),
                label: const Text('暂停'),
              ),
            if (t.canResume)
              OutlinedButton.icon(
                onPressed: () => _action(context, controller.resume(t)),
                icon: const VIcon('play'),
                label: const Text('继续'),
              ),
            if (t.status == TaskStatus.scheduled)
              OutlinedButton(
                onPressed: () => _action(context, controller.runScheduled(t)),
                child: const Text('立即执行'),
              ),
            if (t.status != TaskStatus.completed &&
                t.status != TaskStatus.canceled)
              TextButton(
                onPressed: () => _action(context, controller.cancel(t)),
                child: const Text('取消任务'),
              ),
            if (t.status == TaskStatus.failed ||
                t.status == TaskStatus.paused ||
                t.status == TaskStatus.canceled)
              TextButton(
                onPressed: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('重新下载此任务？'),
                      content: const Text('删除此任务的未完成临时文件并从头下载。已完成的文件会保留。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('重新下载'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true && context.mounted) {
                    _action(context, controller.restart(t));
                  }
                },
                child: const Text('重新下载'),
              ),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.directory(
                  t.output == null ? t.options.directory : p.dirname(t.output!),
                  windows: true,
                ),
              ),
              icon: const VIcon('folder'),
              label: const Text('打开目录'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: t.source));
                if (context.mounted) {
                  showMessage(context, '链接已复制');
                }
              },
              child: const Text('复制链接'),
            ),
          ],
        ),
        if (t.files.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          Text(
            '文件 (${t.files.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._fileTree(t, controller),
          if (t.status == TaskStatus.awaitingSelection)
            BusyButton(
              busy: busy,
              text: '下载所选文件',
              busyText: '正在应用',
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await controller.chooseFiles(t, selected.toList());
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, e);
                        }
                      } finally {
                        if (mounted) {
                          setState(() => busy = false);
                        }
                      }
                    },
            ),
        ],
      ],
    );
  }

  List<Widget> _fileTree(DownloadTask task, DownloadController controller) {
    final rows = <Widget>[];
    final directories = <String>{};
    final files = task.files.toList()..sort((a, b) => a.path.compareTo(b.path));
    final editable = task.status == TaskStatus.awaitingSelection && !busy;
    for (final file in files) {
      final relative = p.relative(file.path, from: controller.tempFor(task));
      final parts = p.split(relative);
      for (var depth = 0; depth < parts.length - 1; depth++) {
        final path = p.joinAll(parts.take(depth + 1));
        if (!directories.add(path)) {
          continue;
        }
        final children = files
            .where(
              (f) => p.isWithin(p.join(controller.tempFor(task), path), f.path),
            )
            .toList();
        final count = children
            .where((f) => editable ? selected.contains(f.index) : f.selected)
            .length;
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: depth * 12),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              tristate: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Row(
                children: [
                  const VIcon('folder', size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      parts[depth],
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              value: count == 0
                  ? false
                  : count == children.length
                  ? true
                  : null,
              onChanged: !editable
                  ? null
                  : (_) => setState(() {
                      if (count == children.length) {
                        selected.removeAll(children.map((f) => f.index));
                      } else {
                        selected.addAll(children.map((f) => f.index));
                      }
                    }),
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(left: (parts.length - 1) * 12),
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(parts.last, style: const TextStyle(fontSize: 11)),
            subtitle: Text(
              bytesLabel(file.size),
              style: const TextStyle(fontSize: 10),
            ),
            value: editable ? selected.contains(file.index) : file.selected,
            onChanged: !editable
                ? null
                : (v) => setState(() {
                    if (v == true) {
                      selected.add(file.index);
                    } else {
                      selected.remove(file.index);
                    }
                  }),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Palette.of(context).secondary, fontSize: 11),
        ),
        const SizedBox(height: 5),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );
}
