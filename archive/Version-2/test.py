import sys
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLineEdit, QComboBox, QPushButton, QTableWidget, QTableWidgetItem,
    QStatusBar, QFileDialog, QLabel
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QClipboard


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Yt-dlp GUI")

        # 顶部区域：输入视频链接、分辨率、字幕、下载路径及浏览按钮
        top_widget = QWidget()
        top_layout = QHBoxLayout()

        # 视频链接输入
        self.url_label = QLabel("视频链接:")
        self.url_input = QLineEdit()
        top_layout.addWidget(self.url_label)
        top_layout.addWidget(self.url_input)

        # 分辨率选择
        self.resolution_label = QLabel("分辨率:")
        self.resolution_combo = QComboBox()
        # 可从配置或上次记忆中加载默认值
        self.resolution_combo.addItems(["720p", "1080p", "4K", "原画"])
        top_layout.addWidget(self.resolution_label)
        top_layout.addWidget(self.resolution_combo)

        # 字幕语言选择
        self.subtitle_label = QLabel("字幕:")
        self.subtitle_combo = QComboBox()
        # 同样可根据配置加载默认值，比如 "中文", "英文", "无字幕"
        self.subtitle_combo.addItems(["中文", "英文", "无字幕"])
        top_layout.addWidget(self.subtitle_label)
        top_layout.addWidget(self.subtitle_combo)

        # 下载路径与浏览按钮
        self.path_label = QLabel("下载路径:")
        self.path_input = QLineEdit()
        self.browse_button = QPushButton("浏览")
        self.browse_button.clicked.connect(self.browse_path)
        top_layout.addWidget(self.path_label)
        top_layout.addWidget(self.path_input)
        top_layout.addWidget(self.browse_button)

        # 开始下载按钮
        self.download_button = QPushButton("开始下载")
        self.download_button.clicked.connect(self.start_download)
        top_layout.addWidget(self.download_button)

        top_widget.setLayout(top_layout)

        # 中间区域：下载任务列表，采用 QTableWidget 展示各任务信息
        self.table = QTableWidget(0, 6)
        self.table.setHorizontalHeaderLabels(["文件名", "进度", "速度", "剩余时间", "格式", "状态"])

        # 底部状态栏：显示全局状态信息，如总速率、提示信息等
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("准备就绪")

        # 主布局：将顶部区域和任务列表放到垂直布局中
        central_widget = QWidget()
        main_layout = QVBoxLayout()
        main_layout.addWidget(top_widget)
        main_layout.addWidget(self.table)
        central_widget.setLayout(main_layout)

        self.setCentralWidget(central_widget)

        # 剪贴板监控：自动检测剪贴板中的视频链接
        self.clipboard = QApplication.clipboard()
        self.clipboard.dataChanged.connect(self.on_clipboard_change)

        # 此处后续可以接入 QSettings，实现各项设置的持久化保存

    def browse_path(self):
        directory = QFileDialog.getExistingDirectory(self, "选择下载目录")
        if directory:
            self.path_input.setText(directory)

    def on_clipboard_change(self):
        # 检查剪贴板内容是否为视频链接（这里只做简单判断）
        text = self.clipboard.text().strip()
        if text.startswith("http"):
            # 自动填入链接并触发解析逻辑
            self.url_input.setText(text)
            self.status_bar.showMessage("检测到视频链接，正在解析...")
            # 此处可调用解析函数，自动更新分辨率和字幕选项
            # 如果启用了自动下载，也可以直接启动下载操作

    def start_download(self):
        # 模拟添加一个下载任务到任务列表中
        row = self.table.rowCount()
        self.table.insertRow(row)
        # 任务信息项：文件名、进度、速度、剩余时间、格式、状态
        self.table.setItem(row, 0, QTableWidgetItem("示例视频"))
        self.table.setItem(row, 1, QTableWidgetItem("0%"))
        self.table.setItem(row, 2, QTableWidgetItem("0 KB/s"))
        self.table.setItem(row, 3, QTableWidgetItem("未知"))
        self.table.setItem(row, 4, QTableWidgetItem(self.resolution_combo.currentText()))
        self.table.setItem(row, 5, QTableWidgetItem("等待下载"))
        self.status_bar.showMessage("下载任务已添加")
        # 这里需要接入 yt-dlp 的下载逻辑，并通过信号槽更新任务列表的进度、状态等


if __name__ == "__main__":
    app = QApplication(sys.argv)
    # 如需应用美化风格，可加载 PyOneDark 主题，示例如下（需要确保主题模块已安装）
    # from PyOneDark_Qt_Widgets_Modern_GUI import setTheme
    # setTheme(app)

    window = MainWindow()
    window.resize(800, 600)
    window.show()
    sys.exit(app.exec())