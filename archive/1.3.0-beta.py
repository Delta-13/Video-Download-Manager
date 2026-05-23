import tkinter as tk
from tkinter import filedialog, messagebox
from tkinter import ttk
import threading
import os
import subprocess
import json
import re

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

        # 存储当前视频格式数据的列表
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

        cmd = ["yt-dlp", "-J", url]
        try:
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            output, _ = process.communicate()
            if process.returncode != 0:
                self.log_output("扫描失败，请检查URL或网络状况。\n")
                return

            data = json.loads(output)
            formats = data.get('formats', [])
            self.current_formats = formats

            # 将解析到的格式填充到下拉框中
            format_options = []
            for f in formats:
                fid = f.get('format_id', '')
                ext = f.get('ext', '')
                width = f.get('width')
                height = f.get('height')
                resolution = f"{width}x{height}" if width and height else f.get('resolution', 'N/A')
                acodec = f.get('acodec', 'none')
                vcodec = f.get('vcodec', 'none')

                # 根据有无音视频决定描述方式
                if vcodec == 'none' and acodec != 'none':
                    # 音频格式
                    desc = f"{fid} - {ext} (audio only)"
                elif acodec == 'none' and vcodec != 'none':
                    # 视频格式
                    desc = f"{fid} - {ext} {resolution}"
                else:
                    # 音视频都有或其他情况
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

        # 构建 yt-dlp 命令参数
        cmd = ["yt-dlp", "-o", os.path.join(out_path, "%(title)s.%(ext)s")]

        # 字幕选项
        if self.subtitles_var.get():
            cmd.extend(["--write-subs", "--all-subs"])

        if self.audio_only_var.get():
            # 只下载音频
            cmd.extend(["-f", "bestaudio/best"])
        else:
            # 根据用户选择的格式ID进行下载
            chosen = self.format_var.get().strip()
            if chosen:
                # chosen类似于 "137 - mp4 1920x1080"
                # 提取format_id
                format_id = chosen.split()[0]  # 假设format_id在第一位
                cmd.extend(["-f", format_id])
            else:
                # 未选择格式时默认最佳
                cmd.extend(["-f", "bestvideo+bestaudio/best", "--merge-output-format", "mp4"])

        cmd.append(url)

        self.log_output("开始下载...\n")
        self.set_progress(0)

        process = subprocess.Popen(
            cmd, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.STDOUT,
            text=True
        )

        # 实时读取进程输出并分析进度
        for line in process.stdout:
            self.log_output(line)
            # 从输出中提取百分比进度信息
            # yt-dlp 的进度行一般包含 "[download]  12.3%" 这样的信息
            per = self.extract_percentage(line)
            if per is not None:
                self.set_progress(per)

        process.stdout.close()
        process.wait()

        if process.returncode == 0:
            self.log_output("下载完成！\n")
            self.set_progress(100)
        else:
            self.log_output("下载过程中出现错误。\n")

    def on_audio_only_check(self):
        # 当选择只下载音频时，禁用格式选择下拉框
        if self.audio_only_var.get():
            self.format_combobox.config(state="disabled")
        else:
            self.format_combobox.config(state="readonly")

    def extract_percentage(self, text_line):
        match = re.search(r"(\d+(?:\.\d+)?)%", text_line)
        if match:
            try:
                return float(match.group(1))
            except:
                return None
        return None

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