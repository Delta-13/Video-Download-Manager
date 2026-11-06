# CLAUDE_PROGRESS.md

## 2026-11-06：忽略构建产物

- 已核对当前跟踪产物：历史分发目录 11321 个文件，以及 `src/ffmpeg`、`src/ffmpeg.exe`、`src/ffprobe.exe`、`archive/resources/ffplay.exe` 共 4 个工具。
- `.gitignore` 补齐任意层级构建目录、PyInstaller 产物、可执行文件、动态库、分发包、无扩展名本地工具和生成的根目录 `VDM-Version2.spec`；源码、维护中的 spec 和图标仍跟踪。
- 本次仅取消产物的本地 Git 跟踪，保留磁盘内容，不重写历史；README 与归档说明同步说明新克隆需自行提供 FFmpeg。
- 用户要求未经允许不得执行与远程仓库关联的操作；本次不执行 push、fetch、pull、远程配置或 GitHub 仓库操作。GitHub 清理方法仅作说明，官方文档查询不连接本仓库的 Git 远程端点。
- 验证通过：20 个产物忽略样例、12 个源码/spec/图标保留样例；11325 个本地索引删除条目与预期逐项一致，全部文件仍在磁盘；5 项现有 unittest 通过。已有 IDE 设置的跟踪状态保持不变。
- 本次仅本地提交；远端当前文件、历史 blob 和 LFS 存储均未更改。未运行 GUI、真实下载或打包，也未执行历史重写或清理磁盘产物。

## 2026-11-06：仓库索引与归档整理

- 已核对：当前稳定源码为 Windows 1.12.1、macOS 1.12.2；Version-2 是独立的 PySide6 alpha，最高本地 Git tag 是 v1.9.0，旧分发包为 1.1。
- 已使用 Codebase Memory 和 GitNexus 检查结构及引用；GitNexus 强制重建成功，原型 `MainWindow` 影响评估 LOW，直接引用仅来自文档，未识别到受影响流程；源码搜索未发现生产依赖。
- 已整体迁移 `Releases/` → `archive/Releases/`，原型 → `archive/Version-2/test.py`，未使用的播放工具和图标 → `archive/resources/`；Python 缓存归入 Git 忽略的 `archive/cache/`。本次范围取代下方历史任务中“不动 Releases”的约束。
- 11324 个跟踪文件全部为 Git `R100` 原样重命名，blob ID 不变；逐个核对工作区与 Git 原始内容：11322 个直接一致、1 个仅为 Git 检出换行差异、1 个 LFS 文件 SHA-256 一致；15 个保留的活动文件内容不变。最初的迁移前 SHA-256 清单随一次性临时目录清理，最终采用 Git 原始内容验证，结果保存在忽略的 `.gitnexus/archive-move-manifest.json`。
- 迁移前后 `python -B -m unittest discover -s tests -v` 各 5 项通过；11 个活动 Python/spec 文件语法、24 个本地文档链接、必需资源和 LFS 路径检查通过；GitNexus `detect_changes(scope="all")` 风险 low，活动源码无修改。
- 两个索引已排除 `archive/` 并重建：GitNexus 212 节点、326 关系、9 社区、0 流程；Codebase Memory 689 节点、2071 关系。GitNexus 没有识别出执行流程，因此归档判断同时依赖源码搜索与内容核对。
- 本次为一个本地整理提交，不推送。未运行 GUI、真实网络下载、旧安装包或跨平台打包。

## 2026-09-28：Version-2 开发文档

| File | Status | Commit | Notes |
|---|---|---|---|
| `README.md`、`CODE_GUIDE.md` | done | 本提交 | 补齐双平台启动、PyInstaller 打包、产物位置、模块职责、Qt 信号调用链与已知限制 |
| `PLANS.md` | done | 本提交 | 记录本次文档范围与验证结果 |

本次仅修改文档。本机 Python 3.13.13 可用，但未安装 PySide6/PyInstaller；完整 GUI、打包与 macOS 实机验证不作为已通过项目记录。

验证结果：`python -m unittest discover -s tests -v` 的 5 项测试通过；README 的 7 段 PowerShell 命令语法检查通过；两份文档的本地链接、锚点、代码围栏与构建输入路径检查通过；`src/ffmpeg.exe -version`、`src/ffprobe.exe -version` 均成功。限定到本次文档的 `git diff --check` 通过。

提交范围为上述文档及本进度文件，不包含构建产物或源码修改。全仓库 Git 检查会触发 LFS 临时目录写入，而当前 `.git` 默认只读；审查状态时使用一次性禁用 LFS filter 的只读命令，不更改仓库配置。

2026-09-29：用户提供作者信息并明确要求设为全局 Git 配置；已配置并验证生效身份，解除此前 `Author identity unknown` 的提交阻塞。本次文档作为一个本地提交完成，不推送。

## File status

| File | Status | Commit | Notes |
|---|---|---|---|
| `readme.md` → `README.md` | done | `f601a8d` | git mv，大小写规范化 |
| `claude.md` → `CLAUDE.md` | done | `f601a8d` | OS 两步改名，新增到仓库 |
| `1.0.0.py` … `1.11.1-beta.py` → `archive/` | done | `f2744e9` | 16 个 .py + 3 个 .spec，**字节级不变** |
| `1.12.0.py` → `archive/1.12.0.py` | done | `f2744e9` | 同上 |
| `1.12.1_win.py` → `src/1.12.1_win.py` | done | `2f477f7` | git mv |
| `1.12.1_win.spec` → `src/1.12.1_win.spec` | done | `2f477f7` | git mv |
| `1.12.2_mac.py` → `src/1.12.2_mac.py` | done | `2f477f7` | git mv |
| `1.12.2_mac.spec` → `src/1.12.2_mac.spec` | done | `2f477f7` | git mv |
| `requirements.txt` | done | `552974f` | 新增：yt-dlp、ttkthemes，PySide6 列为可选 |
| `.gitignore` | done | `552974f` | 追加 `__pycache__/`、venv、IDE 等规则 |
| `README.md`（内容更新） | done | `5d9f99e` | 加 Markdown 标题、安装、目录结构、修正 ffmpeg 路径说明 |
| `src/1.12.1_win.py`（ffmpeg 检查） | done | `f7dfe60` | 加存在性校验 |
| `src/1.12.2_mac.py`（ffmpeg 路径修复） | done | `f7dfe60` | 修 `os.path.join` 吞参 bug + 存在性校验 |
| `src/*.py`（URL 校验） | done | `c5e256b` | `_is_valid_http_url`，三处调用 |
| `src/*.py`（输出目录校验） | done | `5eb802d` | `_validate_output_dir`（存在/是目录/可写） |
| `src/*.py`（超时/重试） | done | `b25e7d6` | `_NETWORK_OPTS` 常量，三处展开 |
| `src/*.py`（错误分类） | done | `28fee4d` | `DownloadError` + `Exception` 分别处理 |
| `src/*.py`（安全文件名/防覆盖） | done | `09f2b09` | win: `windowsfilenames=True`；两端: `nooverwrites=True` |
| `src/*.py`（UI 死分支） | done | `731474f` | `on_subtitles_check` 重构 |
| `src/*.py`（日志时间戳） | done | `daf6a9f` | `log_output` 加 `[HH:MM:SS]` |
| `Version-2/mainwindow.py` | done | `54b69c7` | URL 校验 + 目录校验（存在/可写）+ 剪贴板收紧 |
| `Version-2/downloader.py` | done | `d798648` | `socket_timeout`/`retries`/`fragment_retries`/`nooverwrites` |
| `PLANS.md` / `CLAUDE_PROGRESS.md` | done | `17152d4` | 初版收尾文档 |
| `1.12.1_mac.py` → `archive/1.12.1_mac.py` | done | `e542a4f` | 补救：初次勘察遗漏的旧 mac 版本 |
| `ffmpeg`/`ffmpeg.exe`/`ffplay.exe`/`ffprobe.exe` → `src/` | done | `035c6ab` | 补救：保持脚本同目录关系（共 ~326MB）|
| `icon.ico`/`icon_hd.ico` → `src/` | done | `035c6ab` | 补救：spec 文件以相对路径引用 `icon_hd.ico` |
| `PLANS.md` / `CLAUDE_PROGRESS.md` 二次更新 | in-progress | 本提交 | 记录补救变更 |

## Current assumptions

- 现有 GUI 行为应保持不变（窗口标题、控件文案、字幕语言筛选名单原样保留）。
- 不向 remote push 任何提交。
- 改动尽量小、可独立 revert。
- 不引入新的运行时依赖（`requirements.txt` 仅声明现有需求）。
- `archive/` 下的历史快照视为只读冻结副本，不应再编辑。
- `Releases/` 完全不动（含数千 tcl/tk 内部文件，纯打包产物）。

## Completed work

| Step | Result |
|---|---|
| 仓库结构勘察 | Completed（识别出 13+ 版本号脚本、Releases 打包产物、Version-2 alpha） |
| 文档规范化（大小写） | Completed |
| 历史脚本归档 | Completed（19 个文件冻结迁移到 `archive/`） |
| 稳定脚本入 `src/` | Completed（4 个文件，含 .spec） |
| 依赖清单 / `.gitignore` 升级 | Completed |
| README 重写 | Completed（加 Markdown 标题、安装、目录结构、修正 ffmpeg 说明） |
| `src/` 安全加固 8 个 commit | Completed |
| `Version-2/` 安全加固 2 个 commit | Completed |

## Verification

- 2026-05 的维护批次中，每个 `src/` / `Version-2/` 代码改动均通过 `python -m py_compile` 语法自检；该批次未执行 push。此处不再记录会随推送变化的 ahead 数量。
- 每个 commit 前都用 `git diff --stat` 和 `git status` 确认仅目标文件被改、无非预期文件混入、`Releases/` 未动。
- 2026-08 新增标准库 `unittest` 回归测试，覆盖 URL 与下载目录校验；运行命令为 `python -m unittest discover -s tests -v`。

## Remaining work

- 无剩余 todos。如后续需要：
  - 把 `src/` 中重复的 win/mac 共用代码提取为模块（需评估单文件分发的便利性 vs DRY 收益）。
  - 为 Version-2 alpha 补 `DownloadError` 分类与日志时间戳，对齐 `src/` 体验。
  - 升级 `requirements.txt` 中 yt-dlp 的下限版本。

## 风险与已知偏差

- ffmpeg 路径已从"仓库根"改为"脚本同目录（即 `src/`）"，仓库内的 `ffmpeg.exe`/`ffplay.exe`/`ffprobe.exe`/`ffmpeg` 也已通过补救 commit `035c6ab` 同步迁入 `src/`，所以用户开箱即可用。
- `archive/` 下脚本未做安全加固——按用户在计划阶段的明确决定（"freeze_archive" 选项），它们作为版本快照保留原状。
- Version-2 仍为 alpha；除 URL/目录校验和网络容错外，下载前现会校验可用的 FFmpeg 路径。
- 初次仓库勘察因工具限制未列出 ffmpeg 二进制和 `1.12.1_mac.py`，已通过补救 commit `e542a4f`、`035c6ab` 修正；建议下次开始任务时优先使用 `git ls-files` 而不是 glob。
