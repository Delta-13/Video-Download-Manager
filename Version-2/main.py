# main.py
import sys
from PySide6.QtWidgets import QApplication
from mainwindow import MainWindow


def main():
    app = QApplication(sys.argv)

    # 如需加载主题美化，可取消下面两行注释（确保已安装对应模块）
    # from PyOneDark_Qt_Widgets_Modern_GUI import setTheme
    # setTheme(app)

    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()