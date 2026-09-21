# Video Download Manager 2.0

Windows 10/11 x64. Install the setup package, or extract the complete portable ZIP
and run `vdm.exe`. Keep the DLLs, data/ and engines/ next to the executable.
Python, Flutter, Motrix and separately installed download tools are not required.
The current release is unsigned.

## 下载视频与文件

点击“新建任务”，粘贴网页 URL（多条时每行一个），点击“解析链接”。
勾选条目、选择画质/音轨/字幕或 MP3，然后选择目录并加入队列。
支持 YouTube、Instagram、X、Pornhub 及 yt-dlp 能解析的其他站点；网站
自身限制和上游解析器故障会影响实际可用性。频道与账号列表跟随 yt-dlp
支持范围，不支持的主页请改用单条视频链接。

自动识别不正确时选择“视频网页”或“普通文件”。HTTP 多连接依赖服务器
支持 Range；流媒体使用原生分片下载。默认 3 个并行任务、8 个 HTTP 连接、
4 个视频分片，在设置中可调整，新设置应用于新任务。

需要登录时，设置 → 站点 Cookies → 填写域名并导入自己的 Netscape
cookies.txt。Cookies 使用 Windows DPAPI 加密，只能由当前 Windows
账号解密；应用不读取浏览器个人资料。只保存匹配该域名的 Cookie。

## Torrent 与磁力链接

粘贴 magnet 链接或导入 .torrent。元数据就绪后，打开任务详情，勾选文件
并点击“下载所选文件”。元数据获取时间取决于种子和网络状况。
完成后默认停止做种；新建任务时可选择做种时长及分享率上限。
做种期间文件位于任务临时目录，做种结束后发布到目标目录。

## 暂停、恢复与计划

视频暂停会停止该任务的下载进程并保留临时文件，恢复时重新解析网页。
支持续传的来源继续下载；不支持续传时，详情提供“重新下载”。合并或转换
阶段只能取消。任务下载完毕但尚未合并时，不会显示完成。

关闭窗口会收起到托盘并继续执行；托盘 → 退出会暂停未完成任务并退出。
再次启动后手动恢复任务。计划支持单次、每日和每周，按本机时间执行；
彻底退出或电脑休眠时不执行，错过的任务需要点击“立即执行”。

下载文件重名时自动追加编号；清除临时文件仅作用于目标目录下 `.vdm`
对应任务文件夹。请勿在任务进行中手动修改此文件夹。

## Chrome / Edge 扩展

1. 打开 `chrome://extensions` 或 `edge://extensions`，开启扩展开发者模式。
2. 点击“加载已解压的扩展程序”，选择随包提供的 `browser-extension`。
3. 复制扩展 ID，在 VDM 设置 → 浏览器扩展中粘贴并点击“连接浏览器”。
4. 点击扩展“发送当前页面”，或使用网页/链接右键菜单。
5. 如需接管普通文件，在扩展弹窗中单独开启并授予 HTTP/HTTPS 权限。

接管只处理观察到的 GET 下载，先暂停浏览器下载；VDM 收到数据后才取消
浏览器任务。无法独立访问的认证文件、POST、blob 和未识别请求保留在浏览器。
扩展未上架商店；移动应用目录后需要重新注册。

## 外观、数据与许可

设置支持跟随系统、明暗主题和降低透明度。支持 Ctrl+N 新建任务、键盘
焦点导航和系统文字缩放。数据保存于 Windows 用户的应用支持目录，任务
与设置使用 SQLite；卸载保留下载内容及用户数据。

内置版本与 SHA-256 见 assets.lock.json，开源许可证与上游源码链接见 legal/。
引擎随应用版本更新，不在后台自动替换。
