import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/native.dart';
import 'design.dart';

class SettingsPage extends StatefulWidget {
  final DownloadController controller;
  const SettingsPage(this.controller, {super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final domain = TextEditingController();
  final extension = TextEditingController();
  bool importing = false, registering = false;
  @override
  void dispose() {
    domain.dispose();
    extension.dispose();
    super.dispose();
  }

  Widget section(String icon, String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            VIcon(icon, color: Palette.of(context).accent),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = Palette.of(context);
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        section('settings', '外观', [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ThemeMode.values
                .map(
                  (m) => OutlinedButton(
                    onPressed: () => c.setting('theme', m.name),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: c.themeMode == m ? colors.accent : null,
                      foregroundColor: c.themeMode == m
                          ? colors.onAccent
                          : null,
                    ),
                    child: Text(
                      {
                        ThemeMode.system: '跟随系统',
                        ThemeMode.light: '浅色',
                        ThemeMode.dark: '深色',
                      }[m]!,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('降低透明度'),
            subtitle: const Text('使用不透明面板，减少模糊渲染'),
            value: c.reduceTransparency,
            onChanged: (v) => c.setting('reduceTransparency', v),
          ),
        ]),
        section('download', '下载', [
          Row(
            children: [
              Expanded(child: SelectableText(c.directory)),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () async {
                  final dir = await getDirectoryPath();
                  if (dir != null) {
                    c.setting('directory', dir);
                  }
                },
                child: const Text('更改保存目录'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _number('同时下载任务', 'concurrency', [
                1,
                2,
                3,
                4,
                5,
                8,
              ], c.concurrency),
              _number('HTTP 最大连接数', 'connections', [
                1,
                2,
                4,
                8,
                16,
              ], c.store.setting('connections', 8)),
              _number('视频分片并发', 'fragments', [
                1,
                2,
                4,
                8,
                16,
              ], c.store.setting('fragments', 4)),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<int>(
                  initialValue: c.store.setting('speedLimit', 0),
                  decoration: const InputDecoration(labelText: '每任务限速'),
                  items: [0, 1024 * 1024, 5 * 1024 * 1024, 10 * 1024 * 1024]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            v == 0 ? '不限速' : '${v ~/ (1024 * 1024)} MB/s',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => c.setting('speedLimit', v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '下载参数应用于新任务。关闭窗口后继续驻留托盘；从托盘退出会暂停未完成任务。',
            style: TextStyle(color: colors.secondary, fontSize: 12),
          ),
        ]),
        section('shield', '站点 Cookies', [
          Text(
            '公开链接直接下载。需要登录时，可导入本站点的 Netscape cookies.txt。内容使用 Windows 账户加密保存。',
            style: TextStyle(color: colors.secondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: domain,
                  decoration: const InputDecoration(
                    labelText: '站点域名',
                    hintText: 'youtube.com / instagram.com / x.com',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              BusyButton(
                busy: importing,
                text: '导入 Cookies',
                busyText: '正在导入',
                onPressed: () async {
                  final file = await openFile(
                    acceptedTypeGroups: const [
                      XTypeGroup(label: 'Cookies', extensions: ['txt']),
                    ],
                  );
                  if (file == null) {
                    return;
                  }
                  setState(() => importing = true);
                  try {
                    await c.cookies.import(domain.text, file.path);
                    if (context.mounted) {
                      showMessage(context, 'Cookies 已加密保存');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showMessage(context, e);
                    }
                  } finally {
                    if (mounted) {
                      setState(() => importing = false);
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...c.cookies.entries.keys.map(
            (host) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const VIcon('shield'),
              title: Text(host),
              trailing: TextButton(
                onPressed: () {
                  c.cookies.remove(host);
                  setState(() {});
                },
                child: const Text('删除'),
              ),
            ),
          ),
          if (c.cookies.entries.isEmpty)
            Text(
              '尚未导入站点登录信息',
              style: TextStyle(color: colors.secondary, fontSize: 12),
            ),
        ]),
        section('browser', '浏览器扩展', [
          Text(
            '在 Chrome 或 Edge 的扩展页面加载随安装包提供的 browser-extension 文件夹，复制扩展 ID 后连接。普通文件接管需要在扩展内单独开启。',
            style: TextStyle(color: colors.secondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: extension,
                  decoration: const InputDecoration(
                    labelText: '扩展 ID',
                    hintText: '32 位小写字母',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              BusyButton(
                busy: registering,
                text: '连接浏览器',
                busyText: '正在连接',
                onPressed: () async {
                  setState(() => registering = true);
                  try {
                    await NativeBridge.registerBrowser(extension.text.trim());
                    if (context.mounted) {
                      showMessage(context, 'Chrome / Edge 本机通信已注册');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      showMessage(context, '注册失败，请检查扩展 ID（32 位 a–p 字母）。');
                    }
                  } finally {
                    if (mounted) {
                      setState(() => registering = false);
                    }
                  }
                },
              ),
            ],
          ),
        ]),
        section('file', '下载引擎', [
          ...c.paths.versions.entries
              .where(
                (e) => ['yt-dlp', 'aria2', 'ffmpeg', 'deno'].contains(e.key),
              )
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 160, child: Text(e.key)),
                      Text(e.value, style: TextStyle(color: colors.secondary)),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Text(
            c.engineError ?? '引擎随应用内置，版本与校验清单一同发布。',
            style: TextStyle(
              color: c.engineError == null ? colors.secondary : colors.accent,
            ),
          ),
        ]),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Video Download Manager',
            applicationVersion: '2.0.0',
          ),
          child: const Text('开源许可与第三方声明'),
        ),
      ],
    );
  }

  Widget _number(String label, String key, List<int> values, int value) =>
      SizedBox(
        width: 210,
        child: DropdownButtonFormField<int>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: values
              .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
              .toList(),
          onChanged: (v) => widget.controller.setting(key, v),
        ),
      );
}
