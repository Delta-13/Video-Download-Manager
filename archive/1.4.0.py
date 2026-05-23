import tkinter as tk
from tkinter import filedialog, messagebox
from tkinter import ttk
import threading
import os
import re
from yt_dlp import YoutubeDL

class YtdlpGUI:
    def __init__(self, master):
        self.master = master
        self.master.title("Yt-dlp GUI")

        # 视频URL输入
        self.url_label = tk.Label(master, text="视频URL:")
        self.url_label.grid(row=0, column=0, padx=5, pady=5, sticky="e")

        self.url_entry = tk.Entry(master, width=50)
        self.url_entry.grid(row=0, column=1, padx=5, pady=5)

        # 下载目录
        self.path_label = tk.Label(master, text="下载目录:")
        self.path_label.grid(row=1, column=0, padx=5, pady=5, sticky="e")

        self.path_var = tk.StringVar()
        self.path_entry = tk.Entry(master, textvariable=self.path_var, width=50)
        self.path_entry.grid(row=1, column=1, padx=5, pady=5)

        self.browse_button = tk.Button(master, text="浏览", command=self.browse_path)
        self.browse_button.grid(row=1, column=2, padx=5, pady=5)

        # 扫描链接按钮
        self.scan_button = tk.Button(master, text="扫描链接", command=self.start_scan_thread)
        self.scan_button.grid(row=2, column=0, padx=5, pady=5, sticky='e')

        # 开始下载按钮
        self.download_button = tk.Button(master, text="开始下载", command=self.start_download_thread)
        self.download_button.grid(row=2, column=1, padx=5, pady=5, sticky='w')

        # 格式选择下拉框
        self.format_label = tk.Label(master, text="选择格式:")
        self.format_label.grid(row=3, column=0, padx=5, pady=5, sticky='e')

        self.format_var = tk.StringVar()
        self.format_combobox = ttk.Combobox(master, textvariable=self.format_var, state="readonly", width=47)
        self.format_combobox.grid(row=3, column=1, padx=5, pady=5)

        # 只下载音频选项
        self.audio_only_var = tk.BooleanVar()
        self.audio_only_check = tk.Checkbutton(master, text="只下载音频", variable=self.audio_only_var, command=self.on_audio_only_check)
        self.audio_only_check.grid(row=4, column=0, padx=5, pady=5, sticky='e')

        # 下载字幕选项
        self.subtitles_var = tk.BooleanVar()
        self.subtitles_check = tk.Checkbutton(master, text="下载字幕", variable=self.subtitles_var)
        self.subtitles_check.grid(row=4, column=1, padx=5, pady=5, sticky='w')

        # 输出显示框
        self.output_text = tk.Text(master, height=15, width=60)
        self.output_text.grid(row=5, column=0, columnspan=3, padx=5, pady=5)

        self.scrollbar = tk.Scrollbar(master, command=self.output_text.yview)
        self.output_text.configure(yscrollcommand=self.scrollbar.set)
        self.scrollbar.grid(row=5, column=3, sticky='n'+'s')

        # 进度条
        self.progress = ttk.Progressbar(master, orient='horizontal', length=400, mode='determinate')
        self.progress.grid(row=6, column=0, columnspan=3, padx=5, pady=5)
        self.progress['maximum'] = 100

        # 当前视频格式信息
        self.current_formats = []

    def browse_path(self):
        directory = filedialog.askdirectory()
        if directory:
            self.path_var.set(directory)

    def start_scan_thread(self):
        t = threading.Thread(target=self.scan_formats)
        t.start()

    def scan_formats(self):
        url = self.url_entry.get().strip()
        if not url:
            messagebox.showerror("错误", "请输入视频URL!")
            return

        self.log_output("正在扫描可用格式...\n")

        # 使用yt-dlp的API获取视频信息
        try:
            # 不下载，只获取信息
            with YoutubeDL({'quiet': True, 'no_warnings': True}) as ydl:
                info = ydl.extract_info(url, download=False)
                formats = info.get('formats', [])
                self.current_formats = formats

                format_options = []
                for f in formats:
                    fid = f.get('format_id', '')
                    ext = f.get('ext', '')
                    width = f.get('width')
                    height = f.get('height')
                    resolution = f"{width}x{height}" if width and height else f.get('resolution', 'N/A')
                    acodec = f.get('acodec', 'none')
                    vcodec = f.get('vcodec', 'none')

                    if vcodec == 'none' and acodec != 'none':
                        desc = f"{fid} - {ext} (audio only)"
                    elif acodec == 'none' and vcodec != 'none':
                        desc = f"{fid} - {ext} {resolution}"
                    else:
                        desc = f"{fid} - {ext} {resolution}"

                    format_options.append(desc)

                if format_options:
                    self.format_combobox['values'] = format_options
                    self.format_var.set(format_options[0])
                    self.log_output("扫描完成，请选择格式。\n")
                else:
                    self.log_output("未找到可用格式。\n")

        except Exception as e:
            self.log_output(f"扫描出错: {e}\n")

    def start_download_thread(self):
        t = threading.Thread(target=self.download_video)
        t.start()

    def download_video(self):
        url = self.url_entry.get().strip()
        out_path = self.path_var.get().strip()

        if not url:
            messagebox.showerror("错误", "请输入视频URL!")
            return
        if not out_path:
            messagebox.showerror("错误", "请选择下载目录!")
            return

        # 设置下载选项
        ydl_opts = {
            'outtmpl': os.path.join(out_path, '%(title)s.%(ext)s'),
            'progress_hooks': [self.my_hook],
        }

        # 字幕选项
        if self.subtitles_var.get():
            ydl_opts['writesubtitles'] = True
            ydl_opts['allsubtitles'] = True

        if self.audio_only_var.get():
            # 只下载音频
            ydl_opts['format'] = 'bestaudio/best'
        else:
            chosen = self.format_var.get().strip()
            if chosen:
                format_id = chosen.split()[0]
                ydl_opts['format'] = format_id
            else:
                ydl_opts['format'] = 'bestvideo+bestaudio/best'
                ydl_opts['merge_output_format'] = 'mp4'

        self.log_output("开始下载...\n")
        self.set_progress(0)

        try:
            with YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])
            self.log_output("下载完成！\n")
            self.set_progress(100)
        except Exception as e:
            self.log_output(f"下载过程中出现错误: {e}\n")

    def my_hook(self, d):
        if d['status'] == 'downloading':
            downloaded = d.get('downloaded_bytes', 0)
            total = d.get('total_bytes', 0) or d.get('total_bytes_estimated', 0)
            if total > 0:
                percent = downloaded / total * 100
                self.set_progress(percent)
                # 在GUI中可选添加实时信息
            else:
                # 无法确定总大小时不刷新百分比
                pass
        elif d['status'] == 'finished':
            self.log_output("合并文件中...\n")

    def on_audio_only_check(self):
        if self.audio_only_var.get():
            self.format_combobox.config(state="disabled")
        else:
            self.format_combobox.config(state="readonly")

    def set_progress(self, value):
        self.progress['value'] = value
        self.master.update_idletasks()

    def log_output(self, message):
        self.output_text.insert(tk.END, message)
        self.output_text.see(tk.END)

if __name__ == "__main__":
    root = tk.Tk()
    app = YtdlpGUI(root)
    root.mainloop()