"""Exercise the shipped C++ stdio framing with a temporary inbox, restoring registry state."""
import argparse
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import threading
import time
import winreg


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    registry = r'Software\VDM2'
    key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, registry)
    try:
        original = winreg.QueryValueEx(key, 'Inbox')
    except FileNotFoundError:
        original = None
    report = {'nativeMessagingFraming': False, 'unicodeRoundTrip': False, 'oversizedInputRejected': False}
    try:
        with tempfile.TemporaryDirectory(prefix='vdm-host-check-') as folder:
            inbox = Path(folder)
            winreg.SetValueEx(key, 'Inbox', 0, winreg.REG_SZ, folder)
            (inbox / 'heartbeat').write_text('fixture', encoding='utf-8')
            request = {'protocolVersion': 1, 'requestId': 'native-smoke-123', 'action': 'ping', 'fixture': '本地测试'}
            errors = []

            def respond():
                try:
                    deadline = time.monotonic() + 10
                    while time.monotonic() < deadline:
                        files = list(inbox.glob('*.request'))
                        if files:
                            received = json.loads(files[0].read_text('utf-8'))
                            assert received == request
                            response = files[0].with_suffix('.response')
                            partial = response.with_suffix('.tmp')
                            partial.write_text(json.dumps({'ok': True, 'fixture': received['fixture']}, ensure_ascii=False), encoding='utf-8')
                            os.replace(partial, response)
                            files[0].unlink()
                            return
                        time.sleep(.05)
                    raise TimeoutError('Host did not write its request')
                except BaseException as error:
                    errors.append(str(error))

            responder = threading.Thread(target=respond, daemon=True)
            responder.start()
            payload = json.dumps(request, ensure_ascii=False).encode('utf-8')
            result = subprocess.run([str(args.host.resolve())], input=struct.pack('<I', len(payload)) + payload,
                                    capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
            responder.join(timeout=12)
            assert not errors, errors
            assert result.returncode == 0
            size = struct.unpack('<I', result.stdout[:4])[0]
            assert size == len(result.stdout) - 4
            response = json.loads(result.stdout[4:])
            assert response == {'ok': True, 'fixture': '本地测试'}
            report['nativeMessagingFraming'] = report['unicodeRoundTrip'] = True
            rejected = subprocess.run([str(args.host.resolve())], input=struct.pack('<I', 1024 * 1024 + 1),
                                      capture_output=True, timeout=5, creationflags=subprocess.CREATE_NO_WINDOW)
            assert rejected.returncode == 1 and not rejected.stdout
            report['oversizedInputRejected'] = True
    finally:
        if original is None:
            winreg.DeleteValue(key, 'Inbox')
        else:
            winreg.SetValueEx(key, 'Inbox', 0, original[1], original[0])
        winreg.CloseKey(key)
    args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
