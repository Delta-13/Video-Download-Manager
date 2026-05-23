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
        self.format_label = tk.Label(master, text="选择分辨率:")
        self.format_label.grid(row=3, column=0, padx=5, pady=5, sticky='e')

        self.format_var = tk.StringVar()
        self.format_combobox = ttk.Combobox(master, textvariable=self.format_var, state="readonly", width=47)
        self.format_combobox.grid(row=3, column=1, padx=5, pady=5)

        # 只下载音频选项
        self.audio_only_var = tk.BooleanVar()
        self.audio_only_check = tk.Checkbutton(master, text="只下载音频(MP3)", variable=self.audio_only_var, command=self.on_audio_only_check)
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

        # 存储可用分辨率列表
        self.available_resolutions = []

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

        try:
            with YoutubeDL({'quiet': True, 'no_warnings': True}) as ydl:
                info = ydl.extract_info(url, download=False)
                formats = info.get('formats', [])

                # 提取唯一分辨率
                resolution_set = set()
                # 格式中通常有 height,width信息，对于视频选择时以height为主判断清晰度
                for f in formats:
                    if f.get('vcodec', 'none') != 'none' and f.get('height') and f.get('acodec') is not None:
                        resolution_set.add(f['height'])

                # 将分辨率排序并转换成如 "720p" 字串
                self.available_resolutions = sorted(list(resolution_set))
                res_options = [f"{h}p" for h in self.available_resolutions]

                if res_options:
                    self.format_combobox['values'] = res_options
                    self.format_var.set(res_options[0])
                    self.log_output("扫描完成，请选择分辨率。\n")
                else:
                    self.log_output("未找到可用的视频分辨率格式。\n")

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

        ydl_opts = {
            'outtmpl': os.path.join(out_path, '%(title)s.%(ext)s'),
            'progress_hooks': [self.my_hook],
        }

        # 字幕选项
        if self.subtitles_var.get():
            ydl_opts['writesubtitles'] = True
            ydl_opts['allsubtitles'] = True

        if self.audio_only_var.get():
            # 只下载最佳音频并转码为mp3
            ydl_opts['format'] = 'bestaudio/best'
            ydl_opts['postprocessors'] = [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '192',
            }]
        else:
            # 用户选择了分辨率
            chosen = self.format_var.get().strip()
            if chosen and chosen.endswith('p'):
                height = chosen.replace('p', '')
                # 尝试选择对应分辨率的最佳视频和音频
                # 格式表达式说明:
                # bv[height=XXX]: 匹配指定分辨率高度的视频流
                # +ba: 添加最佳音频流
                # /best: 如果找不到刚好匹配的分辨率，则回退至默认最佳视频+音频
                ydl_opts['format'] = f"bv[height={height}]+ba/best"
            else:
                # 未选择或无效时默认最佳画质音质
                ydl_opts['format'] = 'bestvideo+bestaudio/best'

            # 若最终合成需要统一格式
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
        # 下载进度回调函数
        if d['status'] == 'downloading':
            downloaded = d.get('downloaded_bytes', 0)
            total = d.get('total_bytes', 0) or d.get('total_bytes_estimated', 0)
            if total > 0:
                percent = downloaded / total * 100
                # 在下载线程中更新UI，需要保证线程安全
                self.master.after(0, self.set_progress, percent)
        elif d['status'] == 'finished':
            self.master.after(0, self.log_output, "合并文件中...\n")

    def on_audio_only_check(self):
        # 当选择只下载音频时禁用分辨率选择
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