# mainwindow.py
import os
import uuid
from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLineEdit, QComboBox, QPushButton, QTableWidget, QTableWidgetItem,
    QStatusBar, QFileDialog, QLabel, QAction
)
from PySide6.QtCore import QSettings
from PySide6.QtGui import QGuiApplication
from downloader import DownloadThread
from settingsdialog import SettingsDialog

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Yt-dlp GUI")
        self.resize(800, 600)

        # 加载配置
        self.settings = QSettings("MyCompany", "YtdlpGUI")

        # 菜单栏：设置入口
        menu_bar = self.menuBar()
        settings_menu = menu_bar.addMenu("设置")
        settings_action = QAction("偏好设置", self)
        settings_action.triggered.connect(self.open_settings)
        settings_menu.addAction(settings_action)

        # 顶部区域：视频链接、分辨率、字幕、下载路径及浏览按钮
        top_widget = QWidget()
        top_layout = QHBoxLayout()

        self.url_label = QLabel("视频链接:")
        self.url_input = QLineEdit()
        top_layout.addWidget(self.url_label)
        top_layout.addWidget(self.url_input)

        self.resolution_label = QLabel("分辨率:")
        self.resolution_combo = QComboBox()
        self.resolution_combo.addItems(["480p", "720p", "1080p", "1440p", "2160p"])
        default_res = self.settings.value("defaultResolution", "1080p")
        index = self.resolution_combo.findText(default_res)
        if index >= 0:
            self.resolution_combo.setCurrentIndex(index)
        top_layout.addWidget(self.resolution_label)
        top_layout.addWidget(self.resolution_combo)

        self.subtitle_label = QLabel("字幕:")
        self.subtitle_combo = QComboBox()
        self.subtitle_combo.addItems(["中文", "英文", "无字幕"])
        default_sub = self.settings.value("defaultSubtitle", "中文")
        index = self.subtitle_combo.findText(default_sub)
        if index >= 0:
            self.subtitle_combo.setCurrentIndex(index)
        top_layout.addWidget(self.subtitle_label)
        top_layout.addWidget(self.subtitle_combo)

        self.path_label = QLabel("下载路径:")
        self.path_input = QLineEdit()
        default_path = self.settings.value("defaultDownloadPath", "")
        self.path_input.setText(default_path)
        top_layout.addWidget(self.path_label)
        top_layout.addWidget(self.path_input)

        self.browse_button = QPushButton("浏览")
        self.browse_button.clicked.connect(self.browse_path)
        top_layout.addWidget(self.browse_button)

        self.download_button = QPushButton("开始下载")
        self.download_button.clicked.connect(self.start_download)
        top_layout.addWidget(self.download_button)

        top_widget.setLayout(top_layout)

        # 中间区域：下载任务列表
        self.table = QTableWidget(0, 6)
        self.table.setHorizontalHeaderLabels(["文件名", "进度", "速度", "剩余时间", "格式", "状态"])

        # 底部状态栏
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("准备就绪")

        # 主布局
        central_widget = QWidget()
        main_layout = QVBoxLayout()
        main_layout.addWidget(top_widget)
        main_layout.addWidget(self.table)
        central_widget.setLayout(main_layout)
        self.setCentralWidget(central_widget)

        # 剪贴板监控：自动检测视频链接
        self.clipboard = QGuiApplication.clipboard()
        self.clipboard.dataChanged.connect(self.on_clipboard_change)

        # 用于保存下载线程（以表格行号为 key）
        self.download_threads = {}

    def browse_path(self):
        directory = QFileDialog.getExistingDirectory(self, "选择下载目录")
        if directory:
            self.path_input.setText(directory)

    def on_clipboard_change(self):
        text = self.clipboard.text().strip()
        if text.startswith("http"):
            self.url_input.setText(text)
            self.status_bar.showMessage("检测到视频链接，正在解析...")
            # 此处可增加解析逻辑

    def start_download(self):
        video_url = self.url_input.text().strip()
        if not video_url:
            self.status_bar.showMessage("请先输入视频链接")
            return
        download_path = self.path_input.text().strip()
        if not download_path:
            self.status_bar.showMessage("请先选择下载路径")
            return
        resolution = self.resolution_combo.currentText()
        subtitle = self.subtitle_combo.currentText()

        # 为显示生成一个临时文件名（实际文件名由 yt-dlp 确定）
        file_name = f"视频_{str(uuid.uuid4())[:8]}"

        # 在任务列表中新加一行
        row = self.table.rowCount()
        self.table.insertRow(row)
        self.table.setItem(row, 0, QTableWidgetItem(file_name))
        self.table.setItem(row, 1, QTableWidgetItem("0%"))
        self.table.setItem(row, 2, QTableWidgetItem("0 KB/s"))
        self.table.setItem(row, 3, QTableWidgetItem("未知"))
        self.table.setItem(row, 4, QTableWidgetItem(resolution))
        self.table.setItem(row, 5, QTableWidgetItem("等待下载"))

        # 创建下载线程并连接信号更新任务状态
        download_thread = DownloadThread(video_url, download_path, resolution, subtitle)
        download_thread.progressChanged.connect(lambda progress, speed, eta, row=row: self.update_task(row, progress, speed, eta))
        download_thread.downloadFinished.connect(lambda row=row: self.finish_task(row))
        download_thread.downloadError.connect(lambda error, row=row: self.error_task(row, error))
        self.download_threads[row] = download_thread

        self.table.setItem(row, 5, QTableWidgetItem("正在下载"))
        self.status_bar.showMessage(f"开始下载: {file_name}")
        download_thread.start()

    def update_task(self, row, progress, speed, eta):
        self.table.item(row, 1).setText(f"{progress}%")
        self.table.item(row, 2).setText(speed)
        self.table.item(row, 3).setText(eta)

    def finish_task(self, row):
        self.table.item(row, 5).setText("已完成")
        self.status_bar.showMessage("下载完成")

    def error_task(self, row, error):
        self.table.item(row, 5).setText(f"错误: {error}")
        self.status_bar.showMessage(f"下载错误: {error}")

    def open_settings(self):
        dialog = SettingsDialog(self)
        if dialog.exec():
            # 更新配置后刷新相关默认项
            self.path_input.setText(self.settings.value("defaultDownloadPath", ""))
            default_res = self.settings.value("defaultResolution", "1080p")
            index = self.resolution_combo.findText(default_res)
            if index >= 0:
                self.resolution_combo.setCurrentIndex(index)
            default_sub = self.settings.value("defaultSubtitle", "中文")
            index = self.subtitle_combo.findText(default_sub)
            if index >= 0:
                self.subtitle_combo.setCurrentIndex(index)