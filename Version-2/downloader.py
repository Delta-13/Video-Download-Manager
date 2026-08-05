# downloader.py
import os
from pathlib import Path
import shutil
import sys
from PySide6.QtCore import QThread, Signal
from yt_dlp import YoutubeDL


def find_ffmpeg_location():
    """Find a bundled or PATH-provided FFmpeg executable for yt-dlp."""
    executable = "ffmpeg.exe" if os.name == "nt" else "ffmpeg"
    module_dir = Path(__file__).resolve().parent
    candidates = [
        module_dir / executable,
        module_dir.parent / "src" / executable,
        Path(sys.executable).resolve().parent / executable,
    ]
    bundle_dir = getattr(sys, "_MEIPASS", None)
    if bundle_dir:
        candidates.append(Path(bundle_dir) / executable)

    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    return shutil.which(executable)


class DownloadThread(QThread):
    # 信号：进度百分比、速度字符串、剩余时间字符串
    progressChanged = Signal(int, str, str)
    # 下载完成信号
    downloadFinished = Signal()
    # 下载出错信号
    downloadError = Signal(str)

    def __init__(self, video_url, download_path, resolution, subtitle, ffmpeg_location, parent=None):
        super().__init__(parent)
        self.video_url = video_url
        self.download_path = download_path
        self.resolution = resolution
        self.subtitle = subtitle
        self.ffmpeg_location = ffmpeg_location

    def run(self):
        # 配置 yt-dlp 选项
        ydl_opts = {
            'outtmpl': os.path.join(self.download_path, '%(title)s.%(ext)s'),
            'progress_hooks': [self.my_hook],
            'noplaylist': True,           # 仅下载单个视频
            'quiet': True,
            'no_warnings': True,
            # 网络容错：超时与重试，避免长时间挂死
            'socket_timeout': 30,
            'retries': 5,
            'fragment_retries': 5,
            # 不静默覆盖已存在的同名文件
            'nooverwrites': True,
            # 视频合并、音频提取和字幕转换均需要 FFmpeg。
            'ffmpeg_location': self.ffmpeg_location,
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
