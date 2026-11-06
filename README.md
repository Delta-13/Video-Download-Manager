# 视频下载管理器 (Video Download Manager)

一款基于 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 的 tkinter 图形界面下载器。当前最新稳定源码为 **Windows 1.12.1**（`src/1.12.1_win.py`）和 **macOS 1.12.2**（`src/1.12.2_mac.py`）。`Version-2/` 是 alpha 重写，尚未发布为 2.0。整理时本地最高 Git tag 为 `v1.9.0`，1.1 历史安装包在本机 `archive/Releases/` 保留但不再纳入 Git，两者均不代表最新源码版本。

## 软件功能概述

该软件支持以下功能：

1. **视频下载**：可选择视频分辨率并下载高质量的视频文件。
2. **音频下载**：支持仅下载音频并自动转换为 MP3 格式。
3. **字幕下载**：可选择指定语言的字幕并下载，支持多种字幕格式转换（如 SRT, VTT, ASS）。
4. **界面优化**：支持 DPI 感知与自适应缩放，所有界面字体采用微软雅黑/宋体，视觉效果清晰美观。

## 运行环境

- 操作系统：Windows 10/11 或 macOS（Apple Silicon / Intel）
- Python 3.9 或以上版本
- 运行库：
  - `tkinter`（Python 内置）
  - `ttkthemes` 用于优化界面风格
  - `yt-dlp` 视频下载核心
- 必要文件：
  - **Windows 平台**：自行准备 `ffmpeg.exe` 和 `ffprobe.exe`，放置在脚本所在目录（即 `src/`）下；这些二进制文件已忽略，新克隆不会包含。
  - **macOS 平台**：通过 Homebrew 安装 `ffmpeg`（`brew install ffmpeg`，默认路径为 `/opt/homebrew/bin/ffmpeg`）。

## 安装

```bash
# 1) 克隆仓库
git clone https://github.com/<your-account>/Video-Download-Manager.git
cd Video-Download-Manager

# 2) （推荐）创建虚拟环境
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS:
source .venv/bin/activate

# 3) 安装依赖
pip install -r requirements.txt
```

## 从源码运行

```bash
# Windows
python src/1.12.1_win.py

# macOS
python src/1.12.2_mac.py
```

> 提示：Windows 用户请确保 `ffmpeg.exe` 已经放置在 `src/` 目录下；macOS 用户请确保已通过 Homebrew 安装 ffmpeg。

## 仓库目录结构

```
Video-Download-Manager/
├── README.md           # 本说明文件
├── CODE_GUIDE.md       # 代码结构、调用流程与修改入口
├── CLAUDE.md           # 维护协作约定（供 AI/协作者参考）
├── requirements.txt    # Python 依赖
├── src/                # 当前稳定版（建议从这里运行）
│   ├── 1.12.1_win.py   # Windows 主程序
│   ├── 1.12.2_mac.py   # macOS 主程序
│   └── *.spec          # PyInstaller 打包配置
├── tests/              # 无外部依赖的回归测试
├── Version-2/          # 基于 PySide6 的实验性重写（alpha，开发中）
│   └── main.py         # alpha 入口
└── archive/            # 历史文件；迁移清单与恢复方式见 archive/README.md
    ├── *.py / *.spec   # 历史源码与打包配置
    ├── Releases/       # 本地保留的 1.1 历史打包产物（Git 忽略）
    ├── Version-2/      # 已停用的界面原型 test.py
    └── resources/      # 闲置资源；ffplay.exe 仅本地保留，icon.ico 仍跟踪
```

## 功能与操作指南

### 1. 软件主界面

主界面布局如下：

- **输入区域**：
  - 视频 URL：输入要下载的视频链接。
  - 下载目录：选择保存视频、音频及字幕的文件夹。
  - 浏览按钮：通过弹出文件夹选择窗口指定下载路径。
- **按钮区域**：
  - 扫描链接：获取指定链接的视频信息。
  - 扫描字幕：扫描可用字幕语言。
  - 开始下载：根据选择的设置开始下载任务。
- **格式选择区域**：
  - 分辨率：选择所需的视频分辨率。
  - 字幕语言：选择要下载的字幕语言及是否为自动生成字幕。
  - 字幕格式：选择字幕的导出格式（SRT、VTT、ASS）。
- **选项区域**：
  - 只下载音频 (MP3)：勾选后只下载音频并自动转换为 MP3。
  - 下载字幕：勾选后启用字幕下载功能。
- **日志区域**：实时显示下载进度和结果信息，包括文件路径和文件大小。
- **进度条**：实时显示下载的百分比进度。

### 2. 软件功能操作

#### 1) 视频下载

1. 在 **视频 URL** 输入框中输入目标视频链接（如 YouTube 链接）。
2. 点击 **扫描链接**：
   - 软件会显示可用分辨率选项，如 1920p, 1080p, 720p 等。
   - 若未检测到分辨率，日志区域会提示 "未找到可用的视频分辨率格式"。
3. 从 **选择分辨率** 下拉框中选择所需的分辨率。
4. 确保 **只下载音频 (MP3)** 未勾选。
5. 点击 **开始下载**：
   - 视频和音频会自动合并为 `.mp4` 格式，并保存至指定目录。

#### 2) 音频下载

1. 在 **视频 URL** 输入框中输入目标视频链接。
2. 勾选 **只下载音频 (MP3)**，无需选择分辨率。
3. 点击 **开始下载**：
   - 软件会下载音频并自动转换为 MP3 格式，保存至指定目录。

#### 3) 字幕下载

1. 勾选 **下载字幕**。
2. 点击 **扫描字幕**：
   - 在 **选择字幕语言** 下拉框中会显示可用字幕语言（如 English, 简体中文, 日语）。
   - 若无可用字幕，日志区域会提示 "未找到指定语言的字幕"。
3. 从 **选择字幕语言** 下拉框中选择字幕语言。
4. 从 **字幕格式** 下拉框中选择所需的字幕格式（如 SRT）。
5. 点击 **开始下载**：
   - 下载的视频文件会附带对应的字幕文件，字幕文件名与视频文件一致。

#### 4) 下载进度与结果

- 下载过程中，进度条会实时显示下载进度。
- 下载完成后，日志区域显示文件的保存路径和大小。
  - 示例：`文件路径: C:\path\to\video.mp4 文件大小: 531.40 MB`

## 注意事项

1. **DPI 缩放问题**：
   - 软件已支持 Windows 系统的 DPI 感知功能，若界面仍然模糊，请确保系统显示设置中的缩放比例为常见值（如 100%、125%、150%）。
   - 在源码中通过 `ctypes` 调用 Windows API 设置 `SetProcessDpiAwareness(1)` 和 scaling 调整缩放。
2. **分辨率选择限制**：
   - 若选择了不存在的分辨率，软件会自动选择最接近的分辨率进行下载。
3. **字幕支持语言**：
   - 当前仅支持以下语言字幕：简体中文 (Chinese Simplified)、英语 (English)、日语 (Japanese)、俄语 (Russian)、德语 (German)、法语 (French)。
4. **ffmpeg 依赖**：
   - **Windows**：请将 `ffmpeg.exe` 放置在 `src/` 目录下，与脚本同级，否则字幕转换和音视频合并功能将无法正常运行。
   - **macOS**：请通过 `brew install ffmpeg` 安装，脚本默认查找 `/opt/homebrew/bin/ffmpeg`。
5. **多线程下载**：
   - 软件支持多线程操作，避免界面卡顿，但请勿同时进行多个下载任务，以免影响下载速度。

## 问题排查

1. **视频无法下载**：
   - 检查网络连接是否稳定。
   - 检查视频 URL 是否可访问，某些受版权保护的视频可能无法下载。
2. **字幕语言不可用**：
   - 检查字幕是否为 YouTube 提供的原生字幕或自动生成字幕。
   - 使用 **扫描字幕** 功能获取最新的字幕信息。
3. **音频转换失败**：
   - 确保 `ffmpeg.exe` / `ffmpeg` 已正确配置（参见 "ffmpeg 依赖"）。
   - 检查日志输出的错误信息。

## 软件更新计划

未来功能：

- 添加批量下载功能。
- 支持更多视频网站。
- 优化字幕语言筛选功能。
- 提供更加详细的错误日志。

## 关于 Version-2 与历史版本

- [`Version-2/`](Version-2/) 是基于 PySide6 的实验性重写，目前仍是 alpha 阶段，未稳定，尚未发布为 2.0。运行前请额外安装 `PySide6`；开始下载时会查找 `src/` 中的 FFmpeg 或系统 `PATH`，找不到时不会创建下载任务。
- [`archive/`](archive/) 保留历史源码（含旧版 `1.12.1_mac.py`）、1.1 安装包、旧界面原型及闲置资源，仅作归档保留，不再维护。迁移清单与恢复方式见 [`archive/README.md`](archive/README.md)。

### Version-2 从源码启动

以下命令均在**仓库根目录**执行。入口是 `Version-2/main.py`；旧界面原型已移至 [`archive/Version-2/test.py`](archive/Version-2/test.py)，不会执行真实下载。建议使用 Python 3.11 或以上版本；当前 yt-dlp 的 Python 支持范围见[上游依赖说明](https://github.com/yt-dlp/yt-dlp#dependencies)。

1. 创建虚拟环境（已有 `.venv` 时跳过）。

   Windows PowerShell：

   ```powershell
   python -m venv .venv
   ```

   macOS 终端：

   ```bash
   python3 -m venv .venv
   ```

2. 安装运行依赖。下面直接调用虚拟环境解释器，无需激活环境。

   Windows PowerShell：

   ```powershell
   .\.venv\Scripts\python.exe -m pip install -r requirements.txt "PySide6>=6.6.0"
   ```

   macOS 终端：

   ```bash
   ./.venv/bin/python -m pip install -r requirements.txt 'PySide6>=6.6.0'
   ```

3. 准备 FFmpeg，并确认它能执行。

   Windows 请自行准备实际可执行的 `ffmpeg.exe`、`ffprobe.exe` 并放入 `src/`。它们与构建产物均由 Git 忽略，新克隆不会自动获得；本次取消跟踪保留已有本地副本。

   ```powershell
   .\src\ffmpeg.exe -version
   .\src\ffprobe.exe -version
   ```

   macOS 可通过 Homebrew 安装：

   ```bash
   brew install ffmpeg
   ffmpeg -version
   ffprobe -version
   ```

   Version-2 优先查找随源码或程序分发的 FFmpeg，最后才查找 `PATH`。macOS 上若存在 `src/ffmpeg`，还需运行 `./src/ffmpeg -version` 检查它；如果与本机架构不兼容或无法执行，需替换为可运行的版本。仅在 `PATH` 安装另一个版本不会覆盖优先命中的文件。完整查找顺序见[代码说明](CODE_GUIDE.md#ffmpeg-查找与打包)。

4. 启动应用。

   Windows PowerShell：

   ```powershell
   .\.venv\Scripts\python.exe Version-2/main.py
   ```

   macOS 终端：

   ```bash
   ./.venv/bin/python Version-2/main.py
   ```

   出现 `Yt-dlp GUI` 窗口即表示 GUI 已启动。选择一个现有且可写的下载目录，填入视频 URL，再点击“开始下载”。该版本直接创建下载任务，没有稳定版的“扫描链接”步骤。

### Version-2 打包

以下命令使用 PyInstaller 6 的目录分发模式（`--onedir`），并把 FFmpeg、FFprobe 一起带入包内。**Windows 包在 Windows 上构建，macOS 包在 macOS 上构建**；使用与目标机器架构匹配的 Python 和 FFmpeg。参数含义见 [PyInstaller 使用文档](https://pyinstaller.org/en/stable/usage.html)。

1. 完成上面的依赖安装与 FFmpeg 检查后，在同一虚拟环境安装打包工具。

   Windows PowerShell：

   ```powershell
   .\.venv\Scripts\python.exe -m pip install "PyInstaller>=6,<7"
   ```

   macOS 终端：

   ```bash
   ./.venv/bin/python -m pip install 'PyInstaller>=6,<7'
   ```

2. 在仓库根目录执行对应平台的打包命令。

   Windows PowerShell（行末反引号后不要加空格）：

   ```powershell
   .\.venv\Scripts\python.exe -m PyInstaller --clean --onedir --windowed --name VDM-Version2 `
     --add-binary "src/ffmpeg.exe:." `
     --add-binary "src/ffprobe.exe:." `
     Version-2/main.py
   ```

   macOS 终端（使用前一步 Homebrew 安装的程序）：

   ```bash
   ./.venv/bin/python -m PyInstaller --clean --onedir --windowed --name VDM-Version2 \
     --add-binary "$(command -v ffmpeg):." \
     --add-binary "$(command -v ffprobe):." \
     Version-2/main.py
   ```

   `--add-binary` 把这两个程序收集到包内，Version-2 的 `find_ffmpeg_location()` 能找到打包资源目录。Qt 与 Python 依赖由 PyInstaller 的导入分析和 hooks 收集。

3. 启动生成的程序。

   Windows PowerShell：

   ```powershell
   .\dist\VDM-Version2\VDM-Version2.exe
   ```

   macOS 终端：

   ```bash
   open dist/VDM-Version2.app
   ```

   Windows 分发整个 `dist/VDM-Version2/` 文件夹（包括 `_internal/`），不能只复制 `.exe`；macOS 分发 `dist/VDM-Version2.app`。`build/` 是中间产物，根目录的 `VDM-Version2.spec` 是本次生成的打包配置；`src/*.spec` 只对应 tkinter 稳定版。

4. 检查分发包。

   将分发目录或 `.app` 复制到仓库外，确认窗口、偏好设置和一次实际下载可用；音视频合并及字幕转换也需按使用场景检查。若双击后直接退出，可把构建命令中的 `--windowed` 改为 `--console` 后重建，并从终端运行以查看报错。macOS 正式分发所需的签名和公证不包含在上述开发构建流程中。

这些命令已按源码路径与 PyInstaller 文档核对；本次文档更新未执行完整打包或 macOS 实机验证。构建成功也不代表所有网站均可下载；站点所需的额外依赖请参考 [yt-dlp 依赖说明](https://github.com/yt-dlp/yt-dlp#dependencies)。

## 代码说明

参见 [CODE_GUIDE.md](CODE_GUIDE.md)：包含稳定版与 Version-2 的模块职责、下载调用流程、配置保存方式、已知限制及常见修改入口。

## 验证

无需额外测试依赖，可运行：

```bash
python -m unittest discover -s tests -v
```

## 作者声明

本软件基于 yt-dlp 开源库开发，仅供学习与研究使用，请勿用于非法用途。

版权所有：2024
