"""Pure input-validation helpers shared by the stable desktop clients."""

import os
from urllib.parse import urlparse


def is_valid_http_url(url):
    """Return whether *url* is an absolute HTTP(S) URL."""
    if not url:
        return False
    try:
        parsed = urlparse(url)
    except (TypeError, ValueError):
        return False
    return parsed.scheme in ("http", "https") and bool(parsed.netloc)


def validate_output_dir(path):
    """Return ``(ok, message)`` after checking that a download directory is writable."""
    if not path:
        return False, "请选择下载目录!"
    if not os.path.exists(path):
        return False, f"下载目录不存在：{path}"
    if not os.path.isdir(path):
        return False, f"下载目录不是有效的目录：{path}"
    if not os.access(path, os.W_OK):
        return False, f"下载目录不可写（无权限）：{path}"
    return True, ""
