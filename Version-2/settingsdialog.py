# settingsdialog.py
from PySide6.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, QComboBox, QCheckBox, QDialogButtonBox, QFileDialog
from PySide6.QtCore import QSettings

class SettingsDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("偏好设置")
        self.settings = QSettings("MyCompany", "YtdlpGUI")

        layout = QVBoxLayout()

        # 默认下载路径
        path_layout = QHBoxLayout()
        self.path_label = QLabel("默认下载路径:")
        self.path_input = QLineEdit()
        self.path_input.setText(self.settings.value("defaultDownloadPath", ""))
        self.browse_button = QPushButton("浏览")
        self.browse_button.clicked.connect(self.browse_path)
        path_layout.addWidget(self.path_label)
        path_layout.addWidget(self.path_input)
        path_layout.addWidget(self.browse_button)
        layout.addLayout(path_layout)

        # 默认分辨率
        res_layout = QHBoxLayout()
        self.res_label = QLabel("默认分辨率:")
        self.res_combo = QComboBox()
        self.res_combo.addItems(["720p", "1080p", "4K", "原画"])
        default_res = self.settings.value("defaultResolution", "1080p")
        index = self.res_combo.findText(default_res)
        if index >= 0:
            self.res_combo.setCurrentIndex(index)
        res_layout.addWidget(self.res_label)
        res_layout.addWidget(self.res_combo)
        layout.addLayout(res_layout)

        # 默认字幕
        sub_layout = QHBoxLayout()
        self.sub_label = QLabel("默认字幕:")
        self.sub_combo = QComboBox()
        self.sub_combo.addItems(["中文", "英文", "无字幕", "自动检测"])
        default_sub = self.settings.value("defaultSubtitle", "中文")
        index = self.sub_combo.findText(default_sub)
        if index >= 0:
            self.sub_combo.setCurrentIndex(index)
        sub_layout.addWidget(self.sub_label)
        sub_layout.addWidget(self.sub_combo)
        layout.addLayout(sub_layout)

        # 剪贴板监控
        self.clipboard_checkbox = QCheckBox("监控剪贴板")
        self.clipboard_checkbox.setChecked(self.settings.value("clipboardMonitoring", "true") == "true")
        layout.addWidget(self.clipboard_checkbox)

        # 自动开始下载
        self.autodownload_checkbox = QCheckBox("自动开始下载")
        self.autodownload_checkbox.setChecked(self.settings.value("autoDownload", "false") == "true")
        layout.addWidget(self.autodownload_checkbox)

        # 确定和取消按钮
        self.buttonBox = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        self.buttonBox.accepted.connect(self.save_settings)
        self.buttonBox.rejected.connect(self.reject)
        layout.addWidget(self.buttonBox)

        self.setLayout(layout)

    def browse_path(self):
        directory = QFileDialog.getExistingDirectory(self, "选择默认下载目录")
        if directory:
            self.path_input.setText(directory)

    def save_settings(self):
        self.settings.setValue("defaultDownloadPath", self.path_input.text())
        self.settings.setValue("defaultResolution", self.res_combo.currentText())
        self.settings.setValue("defaultSubtitle", self.sub_combo.currentText())
        self.settings.setValue("clipboardMonitoring", "true" if self.clipboard_checkbox.isChecked() else "false")
        self.settings.setValue("autoDownload", "true" if self.autodownload_checkbox.isChecked() else "false")
        self.accept()