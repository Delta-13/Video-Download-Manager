# 归档文件

这里保留已停用或被替代的文件，不作为当前开发入口。文件移动时保留内容，历史源码快照不继续维护。

历史源码、打包配置和图标继续纳入版本管理；`Releases/`、`resources/ffplay.exe` 与 Python 缓存仅在本机保留，由 Git 忽略，新克隆不会包含这些产物。运行所需的 `src/ffmpeg`、`src/ffmpeg.exe`、`src/ffprobe.exe` 同样需要在本地自行准备。

当前稳定版入口是仓库根目录下的 `src/1.12.1_win.py`（Windows）和 `src/1.12.2_mac.py`（macOS）；实验性 alpha 入口是 `Version-2/main.py`，尚未发布为 2.0。启动与打包命令见[主 README](../README.md)。

## 2026-11-06 整理清单

路径均相对于仓库根目录。

| 原路径 | 归档路径 | 原因 |
|---|---|---|
| `Releases/` | `archive/Releases/` | 1.1 历史安装包及完整分发目录，与当前稳定源码版本不同 |
| `Version-2/test.py` | `archive/Version-2/test.py` | 只添加示例任务的早期界面原型，当前程序不引用 |
| `src/ffplay.exe` | `archive/resources/ffplay.exe` | 当前下载及打包流程不使用的播放工具 |
| `src/icon.ico` | `archive/resources/icon.ico` | 当前打包使用 `src/icon_hd.ico`，不引用此图标 |
| 已在 `archive/` 根目录的 `*.py`、`*.spec` | 原位置保留 | 历史版本源码与打包配置，包括已被 1.12.2 替代的 `1.12.1_mac.py` |

Python 缓存若存在，归入 `archive/cache/{src,Version-2,tests}/__pycache__/`，仍由 Git 忽略；缓存可自动再生成，无需恢复。当前运行所需的 FFmpeg、FFprobe 和 `icon_hd.ico` 保留在 `src/`。

## 恢复

1. 按表中路径将所需文件移回原位置，先确认目标不存在，避免覆盖当前文件。
2. 恢复历史安装包时，整体移动 `archive/Releases/` 为仓库根目录的 `Releases/`，保留 `.app`、`_internal/` 等内部布局；Windows 不能只复制其中的 `.exe`。
3. 如要运行历史源码，先核对它的旧依赖与资源路径；旧 `.spec` 可能引用原始开发机器的路径。归档不会自动修复这些历史配置。

归档目录内的许可证、作者及版权文本随文件一并保留。
