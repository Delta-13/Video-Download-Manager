# VDM 2.1 · AI 字幕

## 使用流程

1. 打开左栏 **字幕翻译**，导入 UTF-8 SRT、WebVTT、ASS/SSA 或音视频。已完成的视频任务详情也有 **翻译字幕**：有字幕时直接导入，多语言字幕会让你选择；没有字幕时对视频执行本地转写。
2. 在 **翻译设置** 中配置在线 API / 本地 Ollama、模型、原文语言、目标语言和批次。原文默认自动识别，目标默认简体中文。
3. 点击 **开始翻译**。每批完整校验后保存到 SQLite；可停止处理、切换下载页面或收起到托盘。退出应用会停止处理，重新打开后从字幕记录中选择并继续。
4. 对照原文与译文，点击 **校对** 修订。完成后导出译文或双语 SRT/VTT/ASS；原文可单独导出。同名文件自动编号，不覆盖文件。

更换模型、端点、语言或批次后再次开始，会重新翻译当前记录。要保留旧译文，先导出或重新导入原文件创建另一条记录。移除记录只删除应用内记录，不删除原始文件或导出文件。

SRT/VTT 保留毫秒时间码；ASS 本身采用百分之一秒，转换会有最多约 5 ms 舍入。样式、位置和说话人标记扁平化为文字，不保留原 ASS 排版特效。单个字幕最大 20 MiB，编码需为 UTF-8。

## 本地翻译：Ollama

从 [Ollama 官方站点](https://ollama.com/download/windows) 安装并启动服务，下载适合本机的模型。已实测 `qwen2.5:3b`；VDM 不内置或自动下载大模型。

```powershell
ollama pull qwen2.5:3b
```

基础地址填写 `http://127.0.0.1:11434`，点击 **读取本地模型** 后选择。VDM 只接受环回地址，过滤云端模型描述及 `:cloud` / `-cloud` 名称，要求模型出现在已安装列表中。应使用官方本机部署，不要把代理到远程的服务伪装成本地。

每批默认 8 条，同时限制约 6,000 字符正文；小模型建议 2–8 条。使用 JSON Schema 约束输出，并再次校验字幕编号、条数和非空内容。翻译质量需人工校对；字幕中的提示语作为待翻译数据处理。

## 在线翻译：兼容 API

服务需支持 **Chat Completions** 和 `response_format: {"type":"json_object"}`。填写基础地址、服务商提供的模型 ID 和密钥。例如 DeepSeek 基础地址 `https://api.deepseek.com/v1`。VDM 不绑定服务商，不包含免费额度。[JSON 输出说明](https://api-docs.deepseek.com/guides/json_mode/)

开始前工作台显示接收正文的主机。只发送字幕文本和语言指令，不上传音视频。远程地址必须使用 HTTPS；允许 HTTP 环回地址用于自建兼容服务，不跟随 HTTP 重定向。

密钥使用 Windows DPAPI 加密，仅当前 Windows 用户可解密，不进入普通配置或日志。输入留空保留密钥；修改基础地址清除旧密钥，也可手动删除。字幕正文及时间码保存在应用支持目录的 SQLite，不做内容加密。

限流、服务器错误、断线、超时和格式错误会有限重试；认证错误直接提示。响应上限 4 MiB，单次请求最长 5 分钟；失败批次不写入部分结果，已完成批次保留。停止会关闭请求，服务商可能仍按已处理请求计费。

在线协议通过本地可控服务测试。没有付费云端凭据，因此没有把真实云端翻译记为已验证；兼容性以服务商模型接口为准。

## 无字幕音视频：可选 whisper.cpp

已有字幕的翻译无需 Whisper。音视频转写复用 FFmpeg 提取 16 kHz 单声道 WAV，再调用 whisper.cpp CPU CLI。在设置中选择官方 EXE 与多语言 GGML 模型；保留 EXE 同目录的 DLL。

源码、安装版和便携版都提供准备脚本，固定 whisper.cpp **v1.9.2** 和 tiny 多语言模型，校验 SHA-256：

```powershell
./scripts/setup-whisper.ps1 -WithTinyModel
```

默认放在 `optional/whisper/`，脚本输出应填入设置的路径。也可用 `-Destination 'D:\Models\whisper'` 指定目录。Tiny 约 75 MiB，适合验证流程；正式转写可从 [whisper.cpp 官方说明](https://github.com/ggml-org/whisper.cpp) 选择更大多语言模型。`.en` 模型仅适合英文。转写语言使用 `auto`、`en`、`zh`、`ja` 等代码。

始终本地转写原文，不使用 Whisper 的仅译成英语模式。FFmpeg/Whisper 使用 Windows Job Object 管理；停止/退出终止其进程树，正常结束或取消后清理临时文件。异常退出留下的 `subtitle-temp` 可在完全退出应用后清理。

可选下载不包含在主安装包中，按上游许可使用：

| 文件 | 固定来源 | SHA-256 |
|---|---|---|
| whisper-bin-x64.zip | ggml-org/whisper.cpp v1.9.2 官方 release | `49dcc16de826f20bd53d44f947a1ae49dfa81f86cad67a64d80820cb192d674a` |
| ggml-tiny.bin | ggerganov/whisper.cpp HF revision `5359861c739e955e79d9a303bcbc70fb988958b1` | `be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21` |

## 接入方式与参考来源

阅读了 [Delta-13/Transcript_Translate](https://github.com/Delta-13/Transcript_Translate) 的 main.py、README 和环境文件，版本 `5d434c5400c7a5ef44fc0becb085c1fe8286fbc1`。其流程使用 Tkinter、MoviePy、whisper_timestamped 和 Transformers 本地模型，提取音轨、逐段转写/翻译并输出 SRT，没有现成在线接口；阅读时未发现许可证文件。

VDM 参考流程独立实现，没有复制代码或模型。Dart HTTP 适配器、Ollama、可选 whisper.cpp 能复用现有 Flutter、SQLite、FFmpeg 和 Windows 进程管理，避免增加 Python/PyTorch 运行时。旧应用及 2.0.0 制品保留。

代码位于 `desktop/lib/subtitles/` 和 `desktop/lib/ui/subtitles.dart`；下载任务新增已发布字幕路径。接口依据：[Ollama Chat](https://docs.ollama.com/api/chat)、[Ollama 模型列表](https://docs.ollama.com/api/tags)。
