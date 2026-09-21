# AI 字幕 2.1 验收记录

日期：2026-09-22。分支：`codex/ai-subtitle-translation`。Windows x64，Flutter 3.47.5 / Dart 3.13.4。参考仓库与接入说明见 [AI-Subtitles.md](AI-Subtitles.md)。

## 自动验证

- Flutter 单元/组件测试 35 项：包括原下载核心和界面回归、新增 SRT/VTT 时间码、双语导出、模型结果编号校验、端点边界、在线请求结构/认证、HTTP 503 重试、错误脱敏、不跟随重定向、请求中取消、批次续传、Ollama 云模型过滤。
- 明暗主题下分别检查 100%、150%、200% 字体缩放，窄内容区域 724 px，新增设置/导出对话框和 Loading 禁用态；修复了 200% 时格式控件溢出。截图在 `artifacts/screenshots-subtitles/`。这属于组件渲染与文字缩放测试，不等同于所有显示器 DPI 的人工验收。
- 复用工业主题对比度测试：普通文字/次文字/强调文字 ≥ 4.5:1，必要边界 ≥ 3:1，覆盖玻璃合成与选中背景；新控件使用同一套令牌、本地 SVG、点击光标，面板动画 250/150 ms 并尊重减少动画设置。
- Python 原版本回归 5 项、浏览器扩展协议 4 项通过。

## 真实 Windows 字幕集成

`desktop/integration_test/subtitles_test.dart` 使用临时 SQLite、真实 Windows DPAPI、FFmpeg 和 NativeBridge 的独占发布，覆盖：

- 在线兼容协议通过回环 HTTP 服务验证；密钥加密、地址变化后清除密钥、重启恢复。
- SRT/VTT/ASS 原文/双语导出后重新读取；重复导出原文件字节不变，新增文件自动编号；ASS 时间码按百分之一秒舍入。
- 本机 Ollama `qwen2.5:3b`（Q4_K_M）真实翻译，模型摘要 `357c53fb659c5076de1d65ccb0b397446227b71a42be9d1603d46168015c9e4b`。小模型使用普通 JSON 模式出现结构错误后，改为 JSON Schema 约束，再经完整编号验证通过。测试确认工作链路，不作为译文质量评分；仍需校对。
- whisper.cpp v1.9.2 CPU + 多语言 ggml-tiny，使用官方 `samples/jfk.wav` 完成本地音轨转换、转写、Ollama 翻译和双语 SRT 导出。
- 操作结束后临时目录为空。完整结果在 `artifacts/subtitle-integration.json`（测试正文仅使用夹具与官方样例）。

实际模型测试需显式指定路径；普通 CI 不会下载模型或调用付费云端：

```powershell
cd desktop
../.tools/flutter/bin/flutter.bat test integration_test/subtitles_test.dart -d windows --no-pub `
  --dart-define=VDM_OLLAMA_MODEL=qwen2.5:3b `
  --dart-define=VDM_WHISPER_EXE=D:\Models\whisper\Release\whisper-cli.exe `
  --dart-define=VDM_WHISPER_MODEL=D:\Models\whisper\ggml-tiny.bin `
  --dart-define=VDM_WHISPER_AUDIO=D:\Fixtures\jfk.wav
```

## 边界

没有云端 API 密钥，未向真实收费服务发送字幕；不声称所有 OpenAI 兼容服务均已验证。音视频不上传。Ollama 和 Whisper 模型属于可选本地依赖，不随主安装包预装。历史 2.0 任务没有新增的字幕路径字段时，可手动导入已经下载的字幕。

`flutter analyze --no-pub` 无问题。既有 `integration_test/downloads_test.dart` 真实 Windows 下载回归通过（HTTP 续传、视频、HLS、Torrent、DPAPI、浏览器交接）；两个原生集成测试均通过，结束后未观察到 vdm / aria2c / ffmpeg / whisper-cli 遗留进程。

2.1.0 安装包（约 144 MiB）与便携 ZIP（约 163 MiB）构建成功，保留 2.0.0 制品。`scripts/smoke-package.ps1 -ReportName portable-runtime-2.1.json` 在 PATH 仅含 Windows 系统目录的环境中通过：五个随包引擎、DPAPI、SQLite、aria2 RPC 均正常，报告 `ok: true`。校验值见 `artifacts/SHA256SUMS.txt`。

Windows 全新系统安装/卸载、签名及商店发行不在此次已验证范围内。安装包未签名。
