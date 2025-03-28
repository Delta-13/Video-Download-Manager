# downloader.py
import os
from PySide6.QtCore import QThread, Signal
from yt_dlp import YoutubeDL

class DownloadThread(QThread):
    # 信号：进度百分比、速度字符串、剩余时间字符串
    progressChanged = Signal(int, str, str)
    # 下载完成信号
    downloadFinished = Signal()
    # 下载出错信号
    downloadError = Signal(str)

    def __init__(self, video_url, download_path, resolution, subtitle, parent=None):
        super().__init__(parent)
        self.video_url = video_url
        self.download_path = download_path
        self.resolution = resolution
        self.subtitle = subtitle

    def run(self):
        # 配置 yt-dlp 选项
        ydl_opts = {
            'outtmpl': os.path.join(self.download_path, '%(title)s.%(ext)s'),
            'progress_hooks': [self.my_hook],
            'noplaylist': True,           # 仅下载单个视频
            'quiet': True,
            'no_warnings': True,
        }

        # 根据分辨率设置格式
        if self.resolution.endswith('p'):
            try:
                height = int(self.resolution.replace('p', ''))
                ydl_opts['format'] = f"bv[height={height}]+ba/best"
            except ValueError:
                ydl_opts['format'] = 'bestvideo+bestaudio/best'
        else:
            ydl_opts['format'] = 'bestvideo+bestaudio/best'

        # 字幕选项：当不为“无字幕”时，下载字幕（此处只处理“中文”、“英文”两种）
        if self.subtitle != "无字幕":
            ydl_opts['writesubtitles'] = True
            lang_map = {"中文": "zh", "英文": "en"}
            lang = lang_map.get(self.subtitle, None)
            if lang:
                ydl_opts['subtitleslangs'] = [lang]
            # 转换字幕格式为 srt
            ydl_opts.setdefault('postprocessors', []).append({
                'key': 'FFmpegSubtitlesConvertor',
                'format': 'srt'
            })

        try:
            with YoutubeDL(ydl_opts) as ydl:
                ydl.download([self.video_url])
        except Exception as e:
            self.downloadError.emit(str(e))
            return

    def my_hook(self, d):
        # 此函数由 yt-dlp 在下载过程中回调
        if d['status'] == 'downloading':
            downloaded = d.get('downloaded_bytes', 0)
            total = d.get('total_bytes', 0) or d.get('total_bytes_estimated', 0)
            percent = int(downloaded / total * 100) if total else 0
            speed = d.get('speed', 0)
            eta = d.get('eta', 0)
            speed_str = f"{int(speed/1024)} KB/s" if speed else "0 KB/s"
            eta_str = f"{eta} s" if eta else "未知"
            self.progressChanged.emit(percent, speed_str, eta_str)
        elif d['status'] == 'finished':
            self.progressChanged.emit(100, "0 KB/s", "0 s")
            self.downloadFinished.emit()