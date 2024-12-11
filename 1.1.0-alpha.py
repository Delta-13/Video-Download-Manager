import tkinter as tk
from tkinter import filedialog, messagebox
import threading
import os

# 请确保已安装 youtube_dl: pip install youtube_dl
# import youtube_dl
import yt_dlp as youtube_dl
class YoutubeDLApp:
    def __init__(self, master):
        self.master = master
        self.master.title("Youtube-DL视频下载器")
        
        # 视频URL标签与输入框
        self.url_label = tk.Label(master, text="视频URL:")
        self.url_label.grid(row=0, column=0, padx=5, pady=5, sticky="e")
        
        self.url_entry = tk.Entry(master, width=50)
        self.url_entry.grid(row=0, column=1, padx=5, pady=5)
        
        # 下载目录选择
        self.path_label = tk.Label(master, text="下载目录:")
        self.path_label.grid(row=1, column=0, padx=5, pady=5, sticky="e")
        
        self.path_var = tk.StringVar()
        self.path_entry = tk.Entry(master, textvariable=self.path_var, width=50)
        self.path_entry.grid(row=1, column=1, padx=5, pady=5)
        
        self.browse_button = tk.Button(master, text="浏览", command=self.browse_path)
        self.browse_button.grid(row=1, column=2, padx=5, pady=5)
        # 在 __init__ 中添加一个 Label 用于显示进度
        self.progress_label = tk.Label(master, text="下载进度: 0.00%")
        self.progress_label.grid(row=4, column=0, columnspan=3, padx=5, pady=5)
        # 下载按钮
        self.download_button = tk.Button(master, text="开始下载", command=self.start_download_thread)
        self.download_button.grid(row=2, column=0, columnspan=3, pady=10)
        
        # 显示下载进度的文本框
        self.status_text = tk.Text(master, height=10, width=60)
        self.status_text.grid(row=3, column=0, columnspan=3, padx=5, pady=5)
        
        # 设置滚动条
        self.scrollbar = tk.Scrollbar(master, command=self.status_text.yview)
        self.status_text.configure(yscrollcommand=self.scrollbar.set)
        self.scrollbar.grid(row=3, column=3, sticky='n'+'s')
        
    def browse_path(self):
        # 选择文件保存目录
        directory = filedialog.askdirectory()
        if directory:
            self.path_var.set(directory)
            
    def start_download_thread(self):
        # 使用多线程避免GUI卡顿
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

        # 配置youtube_dl
        ydl_opts = {
            'outtmpl': os.path.join(out_path, '%(title)s.%(ext)s'),
            'progress_hooks': [self.my_hook],
            'format': 'bestvideo+bestaudio/best', 
            'merge_output_format': 'mp4'
        }
        
        try:
            with youtube_dl.YoutubeDL(ydl_opts) as ydl:
                self.log_status("开始下载...\n")
                ydl.download([url])
                self.log_status("下载完成！\n")
                self.progress_label.config(text=f"下载进度: {100:.2f}%")

        except Exception as e:
            self.log_status("下载出错: {}\n".format(str(e)))
            messagebox.showerror("下载错误", str(e))
        
    def my_hook(self, d):
        if d['status'] == 'downloading':
            downloaded = d.get('downloaded_bytes', 0)
            total = d.get('total_bytes', 0)
            if total > 0:
                percent = downloaded / total * 100
                # self.log_status(f"下载进度: {percent:.2f}%\r")
                self.progress_label.config(text=f"下载进度: {percent:.2f}%")

            else:
                # self.log_status(f"已下载: {downloaded}字节\r")
                self.progress_label.config(text=f"已下载: {downloaded}字节")

        elif d['status'] == 'finished':
            self.log_status("合并文件中...\n")
            
    def log_status(self, message):
        self.status_text.insert(tk.END, message)
        self.status_text.see(tk.END)

if __name__ == "__main__":
    root = tk.Tk()
    app = YoutubeDLApp(root)
    root.mainloop()
