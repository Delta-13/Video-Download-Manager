"""Regression tests for download input validation.

Run with: ``python -m unittest discover -s tests -v``
"""

import sys
import tempfile
from pathlib import Path
import unittest


SRC_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SRC_DIR))

from validation import is_valid_http_url, validate_output_dir


class UrlValidationTests(unittest.TestCase):
    def test_accepts_absolute_http_urls(self):
        self.assertTrue(is_valid_http_url("https://example.com/video?id=1"))
        self.assertTrue(is_valid_http_url("http://example.com"))

    def test_rejects_non_http_and_incomplete_urls(self):
        for url in ("", "example.com/video", "file:///video.mp4", "javascript:alert(1)", "https://"):
            with self.subTest(url=url):
                self.assertFalse(is_valid_http_url(url))


class OutputDirectoryValidationTests(unittest.TestCase):
    def test_accepts_an_existing_writable_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(validate_output_dir(directory), (True, ""))

    def test_rejects_missing_path_and_regular_file(self):
        self.assertFalse(validate_output_dir("")[0])
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            self.assertFalse(validate_output_dir(str(base / "missing"))[0])
            file_path = base / "not-a-directory.txt"
            file_path.write_text("x", encoding="utf-8")
            self.assertFalse(validate_output_dir(str(file_path))[0])
