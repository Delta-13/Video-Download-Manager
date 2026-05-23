# CLAUDE_PROGRESS.md

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

- 每个 `src/` / `Version-2/` 代码改动均通过 `python -m py_compile` 语法自检。
- 每个 commit 前都用 `git diff --stat` 和 `git status` 确认仅目标文件被改、无非预期文件混入、`Releases/` 未动。
- **未执行** `git push`，分支 `main` 比 `origin/main` 领先 15 个本地 commit。
- 仓库无 lint/test 套件可运行；如需引入 pytest/ruff，请单独立项（CLAUDE.md 要求若无 test/lint，需在本文件说明，此处已说明）。

## Remaining work

- 无剩余 todos。如后续需要：
  - 把 `src/` 中重复的 win/mac 共用代码提取为模块（需评估单文件分发的便利性 vs DRY 收益）。
  - 为 Version-2 alpha 补 `DownloadError` 分类与日志时间戳，对齐 `src/` 体验。
  - 引入 pytest 单元测试覆盖 `_is_valid_http_url` 与 `_validate_output_dir`。
  - 升级 `requirements.txt` 中 yt-dlp 的下限版本。
  - 评估 `Thumbs.db`（22KB 系统垃圾）是否要 `git rm --cached` 并加入 `.gitignore`，本次未动以遵守"无明确请求不删文件"原则。
  - 评估根目录已跟踪的 `Version-2/__pycache__/*.pyc`（Python 字节码）是否要清掉。

## 风险与已知偏差

- ffmpeg 路径已从"仓库根"改为"脚本同目录（即 `src/`）"，仓库内的 `ffmpeg.exe`/`ffplay.exe`/`ffprobe.exe`/`ffmpeg` 也已通过补救 commit `035c6ab` 同步迁入 `src/`，所以用户开箱即可用。
- `archive/` 下脚本未做安全加固——按用户在计划阶段的明确决定（"freeze_archive" 选项），它们作为版本快照保留原状。
- Version-2 仍为 alpha，本次仅加最小化的 URL/目录校验和网络容错，未对其 UI 流程做更深改动。
- 初次仓库勘察因工具限制未列出 ffmpeg 二进制和 `1.12.1_mac.py`，已通过补救 commit `e542a4f`、`035c6ab` 修正；建议下次开始任务时优先使用 `git ls-files` 而不是 glob。
