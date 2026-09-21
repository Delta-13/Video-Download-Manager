# VDM 2.0.0 验收记录

日期：2026-09-22。源码、Windows x64 安装包、便携 ZIP 和可加载的 Chrome/Edge 扩展均已生成。以下区分已执行测试与仍需目标环境验收的项目，不把解析器存在视为网站下载成功。

## 构建与制品

- Flutter 3.47.5 / Dart 3.13.4；Visual Studio 2022 C++ / Windows SDK 10.0.26100.0。
- yt-dlp 2026.08.19、aria2 1.37.0、FFmpeg/ffprobe 9.0.2、Deno 2.9.7；官方 yt-dlp Windows 可执行包附带 EJS 组件，调用本地 Deno。
- `desktop/pubspec.lock` 固定 Dart 依赖；`desktop/assets.lock.json` 与 `desktop/toolchain.lock.json` 记录来源、版本和 SHA-256。启动时校验引擎摘要。
- `artifacts/VDM-2.0.0-windows-x64-setup.exe`：当前用户安装，未签名。
- `artifacts/VDM-2.0.0-windows-x64.zip`：完整便携目录，包含应用、本地字体/图标、引擎、VC++ DLL、许可与扩展。
- `artifacts/VDM-2.0.0-browser-extension.zip`：Manifest V3 可加载扩展，未上架商店。
- `artifacts/VDM-2.0.0-source.zip`：新版源码与构建材料，不含可重新校验下载的工具链/引擎二进制。完整仓库继续保留 Python 稳定版、PySide6 实验版与历史发布目录。
- 制品 SHA-256 见 `artifacts/SHA256SUMS.txt`。

## 已执行的检查

| 检查 | 结果与证据 |
|---|---|
| Flutter 静态检查 | `flutter analyze --no-pub`，无问题 |
| Flutter 单元/组件测试 | 16 项通过：输入、Windows 文件名、SQLite、计划边界、引擎参数、进度、脱敏、对比度、双主题、文字缩放、窄窗口与新建流程 |
| Chrome/Edge 交接协议单元测试 | 4 项通过：POST/blob/未知请求拒绝、确认后取消浏览器任务、准备/提交失败恢复 |
| Python 稳定版回归 | 5 项通过；旧应用源码未改动 |
| Windows 原生集成 | `integration_test/downloads_test.dart` 通过；真实运行内置 yt-dlp、aria2、FFmpeg，使用本地生成的数据与媒体 |
| HTTP 文件 | Range 暂停、应用退出/重建后续传，SHA-256 一致；无 Range 新下载、未知大小、503 重试、重名追加编号且原文件不变 |
| 视频 | HTTP MP4、HLS、DASH 音视频分离与合并，ffprobe 时长验证；MP3 转换；无效媒体转换失败不会标记完成/发布文件 |
| BitTorrent | 本地多文件 .torrent + webseed，选择单个文件下载并校验；未选文件不发布 |
| 磁力 | 本地独立 aria2 做种进程 + HTTP tracker，真实取得磁力元数据、等待用户选文件、经 BT 下载并校验 |
| 计划 | 每日模板手动执行生成独立任务，模板保留并更新下次时间；单次/每日/每周日期运算有单元测试 |
| Cookies | DPAPI 加/解密往返、按站点过滤、临时文件受限权限、删除与域名边界 |
| 本机接管服务 | GET 探测、持久化确认、收到首个字节后提交；相同请求/同 URL 不重复建任务，重复请求撤销不取消原任务；403 保留浏览器下载 |
| Native Messaging 可执行程序 | 真正调用打包后的 C++ host：长度前缀、中文 JSON 往返、超长输入拒绝；测试临时修改的 Inbox 注册表值已恢复 |
| 便携运行 | 从其他工作目录启动，PATH 仅含 Windows/System32；5 个引擎版本查询、摘要校验、SQLite、DPAPI、aria2 RPC 均通过 |
| 安装与卸载 | 未签名安装包静默安装至独立测试目录，运行同样的隔离 PATH 检查，随后卸载并确认应用程序被移除 |
| 进程退出 | 集成与包检查结束后确认无测试启动的 vdm/aria2/yt-dlp/FFmpeg/Deno 遗留进程；应用使用根 Job Object 与任务 Job Object 管理子进程树 |

日志与机器可读结果保存在 `artifacts/build-release.log`、`integration-tests.log`、`portable-runtime.json`、`installed-runtime.json`、`native-host-checks.json`、`install-smoke.log`、`uninstall-smoke.log`。这些是本次本机执行证据，不是干净虚拟机测试结果。

## 界面复核

使用 `frontend-design` 工业方向：方正轮廓、1 px 分隔、JetBrains Mono / 更纱等宽 SC、本地 SVG、单一琥珀强调。玻璃限于侧栏/顶部/详情，任务行使用不透明底色。没有伪造下载速度或任务。

- 对深浅内容底色、玻璃 94% 不透明叠加黑/白极限底色及选中背景计算 WCAG 对比度：正文/次文字/操作色 ≥4.5:1，必要边界 ≥3:1；强调按钮文字 ≥4.5:1。低对比装饰分隔线不承担控件边界识别。
- 输入框、按钮、自定义导航和任务行有键盘焦点；交互控件使用点击光标，禁用按钮恢复基础光标，异步提交禁用并显示 Loading，解析可取消。
- 按钮与悬停 150 ms，选择与主题 200 ms，对话框/窄窗详情展开 250 ms。自定义过渡尊重减少动画设置。
- 组件测试覆盖两种主题 × 100%/150%/200% **文字缩放**，以及 800 px 窄窗口。它们不等同于逐档修改 Windows 显示缩放的实机验收。
- 已查看真实本地下载任务的明暗截图及空态截图。`artifacts/screenshots/dark-local-downloads.png` 和 `light-local-downloads.png` 展示真实测试任务；其中 `broken` 是用于验证失败处理的无效媒体夹具。

## 四站点验证状态

| 站点 | 本次证据 | 未完成项 |
|---|---|---|
| YouTube | 锁定版本含解析器；公开 Big Buck Bunny 视频元数据解析通过 | 未执行完整公网站点媒体下载 |
| Instagram | 锁定版本含解析器 | 未提供可访问的单条验收 URL/Cookies，未实测解析与下载；不承诺账号主页整页下载 |
| X | 锁定版本含 Twitter/X 解析器 | 未提供验收 URL，未实测解析与下载 |
| Pornhub | 用户提供的 `cn.pornhub.com` 单条链接已通过实际解析和完整下载；4 个画质档位，无 Cookies | 此结果仅覆盖本次链接和当前网络环境 |

证据：`artifacts/site-checks.json`，可运行 `python scripts/check_sites.py` 重查公开元数据。没有把未测试情况归类为上游故障或应用故障。登录、地区、限流和上游变化需针对具体链接分别判断。

### 用户链接补充验收

2026-09-22，使用锁定的 yt-dlp 2026.08.19，通过应用真实 `VideoRunner` / `DownloadController` 执行用户提供的 Pornhub 链接。未提供或导入 Cookies，未改变安装包或下载引擎。

- 解析成功：240p、480p、720p、1080p 共 4 个格式，返回真实标题。
- 本次测试设定最高 360p，实际选择可用的 240p；最终为 426×240 H.264 视频 + AAC 音频，时长 291.633333 秒。
- 完整下载 13,731,409 字节；SHA-256：`bddce4025a1258110308fa761fb0f23d0f603effa176c66d9f019275b21b3568`。
- 观察到排队、解析、下载、后处理和完成；最终文件通过 ffprobe 校验，退出后没有残留测试引擎进程。
- 证据：`artifacts/live-video-result.json` 与 `artifacts/live-video-test.log`；不在源码或报告中保存用户 URL、媒体标题或账号信息。

新增可选的 `desktop/integration_test/live_video_test.dart`。仅在显式传入 `--dart-define=VDM_TEST_URL=...` 时执行；默认跳过，不让普通 CI 自动访问公网站点。源码 ZIP 随本次记录更新，安装包无需变更。

## 尚待目标环境验收

- 无开发工具的干净 Windows 10/11 x64 虚拟机安装/卸载与完整下载；当前做了隔离 PATH 检查，但宿主本身装有开发工具。
- 真正加载到 Chrome/Edge 后的页面发送、右键、接管失败回退、浏览器重启/扩展 worker 被终止等实机流程；当前验证协议与 C++ 通道，不宣称浏览器全链路已验收。
- Windows 显示缩放 100%/150%/200%、跨显示器拖动、屏幕阅读器与系统减少动画设置的实机复核。
- 托盘鼠标菜单、休眠/唤醒、真实断网、签名媒体 URL 过期、磁盘耗尽和受限目录、FFmpeg 合并进程中断等长期/故障场景。现有自动检查覆盖相邻路径，但不替代这些故障注入。
- 完整公网四站点下载矩阵。批量条目使用站点解析器提供的真实数据；具体频道/账号能否列出仍取决于 yt-dlp。

上述未验收项影响“完整发布验收通过”的结论；本次交付是可构建、可运行并具有真实本地引擎验证的 2.0.0 实现。
