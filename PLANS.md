# PLANS.md

## AI 字幕分支 · 2026-09

分支：`codex/ai-subtitle-translation`，基于已验收的 Flutter 2.0。参考 `Delta-13/Transcript_Translate` 的转写/翻译工作流（commit `5d434c5400c7a5ef44fc0becb085c1fe8286fbc1`），采用独立 Dart 实现，保持无需 Python 的主应用架构。

| Task | Status | Notes |
|---|---|---|
| 阅读参考仓库与当前字幕架构 | done | 原仓库为本地 Whisper + Transformers，未发现许可文件，不复制其实现 |
| 字幕解析、保留时间轴、双语导出 | done | SRT / VTT / ASS、校对、防覆盖；ASS 按格式精度舍入 |
| 在线兼容 API 与本地 Ollama | done | 自定义端点/模型、DPAPI、编号校验、JSON Schema、取消/重试 |
| 可选本地 whisper.cpp 转写 | done | 真实 tiny 模型完成音频 → 转写 → 本地翻译 → 双语字幕闭环 |
| Flutter 字幕工作台与下载任务入口 | done | 工业双主题、150–250 ms 动画、SVG、预览、SQLite 记录 |
| 自动测试、真实本地模型测试、构建与文档 | done | analyze、Flutter 35 项、Python 5 项、扩展 4 项、两组原生集成及真实模型通过；2.1.0 安装包/ZIP与便携运行检查完成 |

不修改旧 Python/PySide6 应用或历史安装包；新功能作为 2.1.0 构建，保留已交付的 2.0.0 制品。

## 2026-09 · 用户批准的 2.0 Flutter 实施

本次范围：新增 `desktop/`、`browser-extension/`、`scripts/`、`docs/` 和 Windows CI；更新根文档及忽略规则。沿用下方历史维护记录，新的产品行为和必要依赖以本次用户批准计划为准。

| Task | Status | Notes |
|---|---|---|
| Windows 工具链、固定引擎/字体来源与 SHA-256 | done | Flutter 3.47.5；锁定清单及运行时校验 |
| Flutter 双主题、任务模型、SQLite / Riverpod | done | SVG / 字体本地打包 |
| 视频 / 文件 / Torrent 下载闭环 | done | 真实引擎、本地数据校验 |
| Cookies / 托盘 / 计划 / 浏览器扩展 | done | Windows 原生桥接及扩展协议测试 |
| 回归测试、打包及独立运行检查 | done | 已执行范围与待验收项见 docs/verification-v2.md |
| 源码审查与本地提交 | done | 本地提交，不推送远端 |

保持 `src/`、`archive/`、`Version-2/`、`Releases/` 字节级不变。

## Goal

在不破坏既有用户行为的前提下：
1. 整理仓库结构，把 30+ 散落于根目录的版本号脚本/spec/文档收敛到清晰的 `src/`、`archive/`、`Version-2/`、`Releases/` 四个子目录。
2. 为最新稳定脚本（`src/1.12.1_win.py` 与 `src/1.12.2_mac.py`）以及 `Version-2/` alpha 重写补齐 URL 校验、输出目录校验、网络超时、重试、错误分类、日志时间戳等安全机制。
3. 补 `requirements.txt`，更新 `README.md` 让新用户能直接 `pip install -r requirements.txt` 后从源码运行。
4. 全程使用 `git mv` 保留历史，每个逻辑变更单独提交，**不推到远端**。

## Scope

### 允许编辑的文件 / 目录

- `README.md`（由原 `readme.md` 改名）
- `CLAUDE.md`（由原 `claude.md` 改名）
- 新增：`PLANS.md`、`CLAUDE_PROGRESS.md`、`requirements.txt`
- 新增目录：`src/`、`archive/`
- `src/1.12.1_win.py`、`src/1.12.2_mac.py`（在迁移后做代码改进）
- `src/1.12.1_win.spec`、`src/1.12.2_mac.spec`（仅 git mv，内容不变）
- `.gitignore`（仅追加规则）
- `Version-2/mainwindow.py`、`Version-2/downloader.py`（做对应安全改进）

### 仅 `git mv`，**字节级不变**的文件

- `archive/` 下所有历史脚本（`1.0.0.py` 到 `1.11.1-beta.py` + `1.12.0.py`）
- `archive/` 下所有历史 spec（`1.9.0.spec`、`1.9.0-win.spec`、`1.9.0-mac.spec`）

### 严禁触碰

- 整个 `Releases/` 目录（打包产物，含数千 tcl/tk 内部文件）
- `Version-2/main.py`、`Version-2/settingsdialog.py`、`Version-2/test.py`
- `Version-2/.gitattributes`
- 任何作者 / 版权 / License 文本

## Workflow

1. 检查目标文件当前内容。
2. 应用最小化改动（每个 commit 一个逻辑点）。
3. `python -m py_compile` 做语法自检。
4. `git diff --stat` 与 `git diff` 审查改动范围。
5. `git add` 仅修改的目标文件后 `git commit`。
6. 更新本文件与 `CLAUDE_PROGRESS.md`（最终一次性提交）。
7. **不执行 `git push`**。

## Task list

| Task | Status | Notes |
|---|---|---|
| Phase 1.1 重命名 `readme.md` / `claude.md` 为规范大小写 | done | commit `f601a8d` |
| Phase 1.2 `git mv` 历史脚本与 .spec 到 `archive/`（冻结） | done | commit `f2744e9`，19 个文件纯 rename |
| Phase 1.3 `git mv` 1.12.x 稳定脚本到 `src/` | done | commit `2f477f7`，4 个文件 |
| Phase 1.4 新增 `requirements.txt`、扩展 `.gitignore` | done | commit `552974f` |
| Phase 2 重写 `README.md`：安装/从源码运行/目录结构 | done | commit `5d9f99e` |
| Phase 3.1 修复 mac ffmpeg 路径 bug + 两端加 ffmpeg 存在性检查 | done | commit `f7dfe60` |
| Phase 3.2 加 `_is_valid_http_url` 助手，三处调用 | done | commit `c5e256b` |
| Phase 3.3 加 `_validate_output_dir` 助手 | done | commit `5eb802d` |
| Phase 3.4 为 yt-dlp 配置 `socket_timeout`/`retries`/`fragment_retries` | done | commit `b25e7d6` |
| Phase 3.5 区分 `DownloadError` 与通用 `Exception` | done | commit `28fee4d` |
| Phase 3.6 `windowsfilenames`（win） + `nooverwrites`（两端） | done | commit `09f2b09` |
| Phase 3.7 简化 `on_subtitles_check` 死分支 | done | commit `731474f` |
| Phase 3.8 `log_output` 加 `[HH:MM:SS]` 时间戳 | done | commit `daf6a9f` |
| Phase 4.1 Version-2 `mainwindow.py` 加 URL/目录校验 | done | commit `54b69c7` |
| Phase 4.2 Version-2 `downloader.py` 加超时/重试/防覆盖 | done | commit `d798648` |
| Phase 5 创建 `PLANS.md` / `CLAUDE_PROGRESS.md` | done | commit `17152d4` |
| 补救 A：归档遗漏的 `1.12.1_mac.py` | done | commit `e542a4f` |
| 补救 B：把 `ffmpeg*` 二进制和 `icon*.ico` git mv 到 `src/` 避免路径回归 | done | commit `035c6ab` |
| 补救 C：同步更新 `PLANS.md` / `CLAUDE_PROGRESS.md` | in-progress | 本提交 |

## Out of scope / 已记录但未做

- 不引入新外部依赖（仅 yt-dlp、ttkthemes 写进 requirements.txt；PySide6 列为可选注释）。
- 不改 CLI/GUI 用户可见行为（窗口标题、控件文案、字幕语言筛选名单保持不变）。
- 没有补单元测试（仓库本身无测试基础设施；新增测试框架超出本次最小改动原则）。
- 未引入 logging 模块（保留原有 Text 控件日志方案，仅加时间戳）。
- 未为 Version-2 增补 DownloadError 分类（alpha 阶段保持现状）。
