"""Read-only site support evidence. Never downloads media or requests credentials."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ENGINES = ROOT / 'desktop' / 'engines'
EXE = str(ENGINES / 'yt-dlp.exe')
OUT = ROOT / 'artifacts' / 'site-checks.json'

def run(args, timeout=60):
    return subprocess.run([EXE, '--ignore-config', *args], capture_output=True,
                          text=True, encoding='utf-8', errors='replace', timeout=timeout,
                          creationflags=subprocess.CREATE_NO_WINDOW)

def main():
    names = run(['--list-extractors']).stdout.lower().splitlines()
    report = {'ytDlpVersion': run(['--version']).stdout.strip(), 'sites': {}}
    for site, prefix in [('YouTube', 'youtube'), ('Instagram', 'instagram'), ('X', 'twitter'), ('Pornhub', 'pornhub')]:
        report['sites'][site] = {'extractorsPresent': any(n.startswith(prefix) for n in names),
            'liveDownload': 'not_tested', 'reason': 'No user-provided accessible acceptance URL; extractor registration is not evidence of live download success.'}
    try:
        result = run(['--skip-download', '--simulate', '--no-playlist', '--socket-timeout', '12',
                      '--retries', '1', '--extractor-retries', '1', '--js-runtimes', f'deno:{ENGINES / "deno.exe"}',
                      '--print', '%(id)s', 'https://www.youtube.com/watch?v=aqz-KE-bpKQ'], timeout=80)
        report['sites']['YouTube']['publicMetadataProbe'] = 'passed' if result.returncode == 0 else 'blocked'
        # Deliberately do not persist upstream URLs, cookies or full diagnostics.
        err = result.stderr.lower()
        report['sites']['YouTube']['probeResult'] = 'metadata resolved' if result.returncode == 0 else (
            'site requested authentication / bot verification' if any(s in err for s in ['sign in', 'bot', 'login']) else
            'network/certificate/site rejection; no media was downloaded')
    except subprocess.TimeoutExpired:
        report['sites']['YouTube']['publicMetadataProbe'] = 'timeout'
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    main()
