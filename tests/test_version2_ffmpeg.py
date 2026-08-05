"""Regression test for Version-2's FFmpeg discovery without Qt installed."""

import importlib.util
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch


ROOT_DIR = Path(__file__).resolve().parents[1]


def load_downloader_module():
    qt_core = types.ModuleType("PySide6.QtCore")

    class FakeQThread:
        def __init__(self, parent=None):
            self.parent = parent

    qt_core.QThread = FakeQThread
    qt_core.Signal = lambda *args: object()
    pyside6 = types.ModuleType("PySide6")
    yt_dlp = types.ModuleType("yt_dlp")
    yt_dlp.YoutubeDL = object

    module_path = ROOT_DIR / "Version-2" / "downloader.py"
    spec = importlib.util.spec_from_file_location("version2_downloader_test", module_path)
    module = importlib.util.module_from_spec(spec)
    with patch.dict(sys.modules, {
        "PySide6": pyside6,
        "PySide6.QtCore": qt_core,
        "yt_dlp": yt_dlp,
    }):
        spec.loader.exec_module(module)
    return module


class Version2FfmpegTests(unittest.TestCase):
    def test_finds_repository_bundled_ffmpeg(self):
        downloader = load_downloader_module()
        ffmpeg = Path(downloader.find_ffmpeg_location())
        self.assertTrue(ffmpeg.is_file())
        self.assertEqual(ffmpeg.name, "ffmpeg.exe" if sys.platform.startswith("win") else "ffmpeg")
