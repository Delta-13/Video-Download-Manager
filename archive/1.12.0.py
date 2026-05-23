import tkinter as tk
from tkinter import filedialog, messagebox
from tkinter import ttk
import threading
import os
import re
import sys
from yt_dlp import YoutubeDL
from ttkthemes import ThemedTk

# 定义全局字体变量
# 字体格式为 (字体名称, 字号, 可选样式)
# 例如: ("Microsoft YaHei", 10, "bold") 粗体
# ("Microsoft YaHei", 10, "italic") 斜体
# 若需使用其他中文字体，如黑体：("SimHei", 10)
# 楷体：("KaiTi", 10)
# 宋体：("SimSun", 10)
GLOBAL_FONT = ("SimSun", 10)

class YtdlpGUI:
    def __init__(self, master):
        self.master = master
        self.master.title("Video Download Manager")

        # 全局字体设置
        self.master.option_add("*Font", GLOBAL_FONT)
        # 若想针对按钮、复选框等控件单独指定字体：
        self.master.option_add("*TButton.Font", GLOBAL_FONT)
        self.master.option_add("*TCheckbutton.Font", GLOBAL_FONT)
        
        # 上方输入区域
        self.url_label = tk.Label(master, text="视频URL:")
        self.url_label.grid(row=0, column=0, padx=5, pady=5, sticky="e")

        self.url_entry = tk.Entry(master, width=50)
        self.url_entry.grid(row=0, column=1, padx=5, pady=5)

        self.path_label = tk.Label(master, text="下载目录:")
        self.path_label.grid(row=1, column=0, padx=5, pady=5, sticky="e")

        self.path_var = tk.StringVar()
        self.path_entry = tk.Entry(master, textvariable=self.path_var, width=50)
        self.path_entry.grid(row=1, column=1, padx=5, pady=5)

        self.browse_button = ttk.Button(master, text="浏览", command=self.browse_path)
        self.browse_button.grid(row=1, column=2, padx=5, pady=5)

        # 按钮行：扫描链接、扫描字幕、开始下载
        self.button_frame = tk.Frame(master)
        self.button_frame.grid(row=2, column=0, columnspan=3, pady=5)
        
        self.scan_link_button = ttk.Button(self.button_frame, text="扫描链接", command=self.start_scan_thread)
        self.scan_subs_button = ttk.Button(self.button_frame, text="扫描字幕", command=self.start_sub_scan_thread)
        self.download_button = ttk.Button(self.button_frame, text="开始下载", command=self.start_download_thread)

        self.scan_link_button.pack(side=tk.LEFT, padx=10)
        self.scan_subs_button.pack(side=tk.LEFT, padx=10)
        self.download_button.pack(side=tk.LEFT, padx=10)

        # 分辨率选择
        self.format_label = tk.Label(master, text="选择分辨率:")
        self.format_label.grid(row=3, column=0, padx=5, pady=5, sticky='e')

        self.format_var = tk.StringVar()
        self.format_combobox = ttk.Combobox(master, textvariable=self.format_var, state="readonly", width=47)
        self.format_combobox.grid(row=3, column=1, padx=5, pady=5)

        # 字幕选择(语言及格式)
        self.subtitle_label = tk.Label(master, text="选择字幕语言:")
        self.subtitle_label.grid(row=4, column=0, padx=5, pady=5, sticky='e')

        self.subtitle_var = tk.StringVar()
        self.subtitle_combobox = ttk.Combobox(master, textvariable=self.subtitle_var, state="disabled", width=20)
        self.subtitle_combobox.grid(row=4, column=1, padx=5, pady=5, sticky='w')

        self.subformat_var = tk.StringVar()
        self.subformat_combobox = ttk.Combobox(master, textvariable=self.subformat_var, state="disabled", width=20)
        self.subformat_combobox['values'] = ['srt', 'vtt', 'ass']
        self.subformat_combobox.set('srt')
        self.subformat_combobox.grid(row=4, column=1, padx=5, pady=5, sticky='e')

        # 中间放置 只下载音频(MP3) 和 下载字幕选项
        self.option_frame = tk.Frame(master)
        self.option_frame.grid(row=5, column=0, columnspan=3, pady=5)

        self.audio_only_var = tk.BooleanVar()
        self.audio_only_check = ttk.Checkbutton(self.option_frame, text="只下载音频(MP3)", variable=self.audio_only_var, command=self.on_audio_only_check)
        self.audio_only_check.pack(side=tk.LEFT, padx=20)

        self.subtitles_var = tk.BooleanVar()
        self.subtitles_check = ttk.Checkbutton(self.option_frame, text="下载字幕", variable=self.subtitles_var, command=self.on_subtitles_check)
        self.subtitles_check.pack(side=tk.LEFT, padx=20)

        # 输出显示框
        self.output_text = tk.Text(master, height=15, width=60)
        self.output_text.grid(row=6, column=0, columnspan=3, padx=5, pady=5)

        self.scrollbar = ttk.Scrollbar(master, command=self.output_text.yview)
        self.output_text.configure(yscrollcommand=self.scrollbar.set)
        self.scrollbar.grid(row=6, column=3, sticky='n'+'s')

        # 进度条
        self.progress = ttk.Progressbar(master, orient='horizontal', length=400, mode='determinate')
        self.progress.grid(row=7, column=0, columnspan=3, padx=5, pady=5)
        self.progress['maximum'] = 100

        # 数据存储
        self.available_resolutions = []
        self.available_subtitles = []
        
        self.ffmpeg_path = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "ffmpeg.exe")

        self.lang_map = {
            'en': 'English',
            'zh': 'Chinese (Simplified)',
            'zh-CN': 'Chinese (Simplified)',
            'zh-Hans': 'Chinese (Simplified)',
            'ja': 'Japanese',
            'ru': 'Russian',
            'de': 'German',
            'fr': 'French'
        }

        # 布局完成后锁定窗口大小
        master.update_idletasks()
        master.minsize(master.winfo_width(), master.winfo_height())
        master.resizable(False, False)

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

                resolution_set = set()
                for f in formats:
                    if f.get('vcodec', 'none') != 'none' and f.get('height'):
                        resolution_set.add(f['height'])

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

    def on_subtitles_check(self):
        if self.subtitles_var.get():
            self.scan_subs_button.config(state='normal')
        else:
            self.scan_subs_button.config(state='normal')
            self.subtitle_combobox.config(state='disabled')
            self.subformat_combobox.config(state='disabled')

    def start_sub_scan_thread(self):
        t = threading.Thread(target=self.scan_subtitles)
        t.start()

    def scan_subtitles(self):
        url = self.url_entry.get().strip()
        if not url:
            messagebox.showerror("错误", "请输入视频URL!")
            return

        if not self.subtitles_var.get():
            self.log_output("请先勾选下载字幕选项。\n")
            return

        self.log_output("正在扫描可用字幕...\n")
        try:
            with YoutubeDL({'quiet': True, 'no_warnings': True}) as ydl:
                info = ydl.extract_info(url, download=False)
                subs = info.get('subtitles', {})
                autosubs = info.get('automatic_captions', {})

                raw_subtitles = []
                for lang in subs.keys():
                    raw_subtitles.append((lang, 'normal'))
                for lang in autosubs.keys():
                    raw_subtitles.append((lang, 'auto'))

                filtered_subs = []
                for (lang, t) in raw_subtitles:
                    if lang in ['en', 'ja', 'ru', 'de', 'fr', 'zh', 'zh-CN', 'zh-Hans']:
                        display_lang = self.lang_map.get(lang, lang)
                        filtered_subs.append((lang, t, display_lang))

                if filtered_subs:
                    sub_options = [f"{display_lang} ({t})" for (lang, t, display_lang) in filtered_subs]
                    self.subtitle_combobox['values'] = sub_options
                    self.subtitle_combobox.config(state='readonly')
                    self.subtitle_combobox.set(sub_options[0])
                    self.subformat_combobox.config(state='readonly')
                    self.available_subtitles = filtered_subs
                    self.log_output("字幕扫描完成，请选择字幕语言和格式。\n")
                else:
                    self.log_output("未找到指定语言的字幕。\n")

        except Exception as e:
            self.log_output(f"字幕扫描出错: {e}\n")

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

        chosen_res = self.format_var.get().strip() if self.format_var.get() else ""
        if self.audio_only_var.get():
            outtmpl = '%(title)s.%(ext)s'
        else:
            if chosen_res and chosen_res.endswith('p'):
                outtmpl = '%(title)s.' + chosen_res + '.%(ext)s'
            else:
                outtmpl = '%(title)s.%(ext)s'

        ydl_opts = {
            'outtmpl': os.path.join(out_path, outtmpl),
            'progress_hooks': [self.my_hook],
            'ffmpeg_location': self.ffmpeg_path,
        }

        download_sub = self.subtitles_var.get()
        chosen_sub = self.subtitle_var.get().strip() if download_sub and self.subtitle_combobox['state'] != 'disabled' else None
        chosen_sub_format = self.subformat_var.get() if (download_sub and self.subformat_combobox['state'] != 'disabled') else None

        if self.audio_only_var.get():
            ydl_opts['format'] = 'bestaudio/best'
            ydl_opts['postprocessors'] = [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '192',
            }]
            if download_sub and chosen_sub:
                lang, stype = self.parse_sub_choice(chosen_sub)
                self.set_subtitle_opts(ydl_opts, lang, stype, chosen_sub_format)
        else:
            if chosen_res and chosen_res.endswith('p'):
                height = chosen_res.replace('p', '')
                ydl_opts['format'] = f"bv[height={height}]+ba/best"
            else:
                ydl_opts['format'] = 'bestvideo+bestaudio/best'
            ydl_opts['merge_output_format'] = 'mp4'

            if download_sub and chosen_sub:
                lang, stype = self.parse_sub_choice(chosen_sub)
                self.set_subtitle_opts(ydl_opts, lang, stype, chosen_sub_format)

        self.log_output("开始下载...\n")
        self.set_progress(0)

        try:
            with YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])
        except Exception as e:
            self.log_output(f"下载过程中出现错误: {e}\n")

    def parse_sub_choice(self, sub_choice_str):
        m = re.match(r'(.+?) \((normal|auto)\)', sub_choice_str)
        if m:
            display_lang = m.group(1)
            stype = m.group(2)
            for (lang, t, dlang_name) in self.available_subtitles:
                if dlang_name == display_lang and t == stype:
                    return lang, t
        return None, None

    def set_subtitle_opts(self, ydl_opts, lang, stype, subformat):
        if stype == 'normal':
            ydl_opts['writesubtitles'] = True
        else:
            ydl_opts['writeautomaticsub'] = True

        ydl_opts['subtitleslangs'] = [lang]
        if 'postprocessors' not in ydl_opts:
            ydl_opts['postprocessors'] = []
        ydl_opts['postprocessors'].append({
            'key': 'FFmpegSubtitlesConvertor',
            'format': subformat
        })

    def on_audio_only_check(self):
        if self.audio_only_var.get():
            self.format_combobox.config(state="disabled")
        else:
            self.format_combobox.config(state="readonly")

    def my_hook(self, d):
        if d['status'] == 'downloading':
            downloaded = d.get('downloaded_bytes', 0)
            total = d.get('total_bytes', 0) or d.get('total_bytes_estimated', 0)
            if total > 0:
                percent = downloaded / total * 100
                self.master.after(0, self.set_progress, percent)
                self.master.after(0, self.log_output, f"下载进度: {percent}%")
        elif d['status'] == 'finished':
            filename = d.get('filename')
            if filename and os.path.exists(filename):
                size_bytes = os.path.getsize(filename)
                size_mb = size_bytes / (1024*1024)
                self.master.after(0, self.log_output, "下载完成！\n")
                self.master.after(0, self.log_output, f"文件路径：{filename}\n文件大小：{size_mb:.2f} MB\n")
            self.master.after(0, self.set_progress, 100)

    def set_progress(self, value):
        self.progress['value'] = value
        self.master.update_idletasks()

    def log_output(self, message):
        self.output_text.insert(tk.END, message)
        self.output_text.see(tk.END)



if __name__ == "__main__":
    # 设置DPI感知和缩放，解决字体模糊问题（Windows下）
    # 请确保在import后执行下列代码
    if sys.platform.startswith('win'):
        import ctypes
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(1)
            ScaleFactor = ctypes.windll.shcore.GetScaleFactorForDevice(0)
            # 通常ScaleFactor是整数，如100,125,150... 通过除以75得到合适的scaling
            # 根据实际情况微调此值
        except:
            ScaleFactor = 100  # 如果获取失败则使用默认

    root = ThemedTk(theme="Breeze")
    if sys.platform.startswith('win'):
        root.tk.call('tk', 'scaling', ScaleFactor/75)

    app = YtdlpGUI(root)
    root.mainloop()