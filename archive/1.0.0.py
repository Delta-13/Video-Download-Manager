import tkinter as tk
from tkinter import filedialog, messagebox
import threading
import subprocess
import os

class YtdlpGUI:
    def __init__(self, master):
        self.master = master
        self.master.title("Yt-dlp GUI")

        self.url_label = tk.Label(master, text="视频URL:")
        self.url_label.grid(row=0, column=0, padx=5, pady=5, sticky="e")

        self.url_entry = tk.Entry(master, width=50)
        self.url_entry.grid(row=0, column=1, padx=5, pady=5)

        self.path_label = tk.Label(master, text="下载目录:")
        self.path_label.grid(row=1, column=0, padx=5, pady=5, sticky="e")

        self.path_var = tk.StringVar()
        self.path_entry = tk.Entry(master, textvariable=self.path_var, width=50)
        self.path_entry.grid(row=1, column=1, padx=5, pady=5)

        self.browse_button = tk.Button(master, text="浏览", command=self.browse_path)
        self.browse_button.grid(row=1, column=2, padx=5, pady=5)

        self.download_button = tk.Button(master, text="开始下载", command=self.start_download_thread)
        self.download_button.grid(row=2, column=0, columnspan=3, pady=10)

        # 显示输出的文本框
        self.output_text = tk.Text(master, height=15, width=60)
        self.output_text.grid(row=3, column=0, columnspan=3, padx=5, pady=5)

        self.scrollbar = tk.Scrollbar(master, command=self.output_text.yview)
        self.output_text.configure(yscrollcommand=self.scrollbar.set)
        self.scrollbar.grid(row=3, column=3, sticky='n'+'s')

    def browse_path(self):
        directory = filedialog.askdirectory()
        if directory:
            self.path_var.set(directory)

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

        # 构建 yt-dlp 命令行
        # 假设我们想下载最高质量的视频和音频，并转码为 mp4（如果有必要）
        cmd = [
            'yt-dlp',
            '-f', 'bestvideo+bestaudio/best',
            '-o', os.path.join(out_path, '%(title)s.%(ext)s'),
            '--merge-output-format', 'mp4',
            url
        ]

        # 使用 subprocess.Popen 来运行命令并捕获输出
        process = subprocess.Popen(
            cmd, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.STDOUT,
            text=True
        )

        # 实时读取并更新输出
        for line in process.stdout:
            # 将从子进程获取的行更新到文本框中
            self.log_output(line)

        process.stdout.close()
        process.wait()

        if process.returncode == 0:
            self.log_output("下载完成！\n")
        else:
            self.log_output("下载过程中出现错误。\n")

    def log_output(self, message):
        # 在主线程中更新GUI
        self.output_text.insert(tk.END, message)
        self.output_text.see(tk.END)

if __name__ == "__main__":
    root = tk.Tk()
    app = YtdlpGUI(root)
    root.mainloop()