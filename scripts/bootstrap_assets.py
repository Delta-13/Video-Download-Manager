"""Fetch pinned Windows runtime assets. --refresh intentionally updates the lock.

No downloaded binary is executed by this script. Official GitHub release digests
are checked where available; all extracted distributables get individual hashes.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.tools' / 'assets'
LOCK = ROOT / 'desktop' / 'assets.lock.json'


def fetch_json(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'VDM-Build/2.0'})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def release(repo, match):
    info = fetch_json(f'https://api.github.com/repos/{repo}/releases/latest')
    asset = next(a for a in info['assets'] if match(a['name']))
    return dict(version=info['tag_name'], url=asset['browser_download_url'],
                sha256=(asset.get('digest') or '').removeprefix('sha256:'),
                source=f'https://github.com/{repo}/tree/{info["tag_name"]}')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def download(name, item):
    path = CACHE / (name + '-' + item['url'].split('/')[-1])
    if not path.exists() or (item['sha256'] and digest(path) != item['sha256']):
        part = path.with_suffix(path.suffix + '.part')
        request = urllib.request.Request(item['url'], headers={'User-Agent': 'VDM-Build/2.0'})
        with urllib.request.urlopen(request, timeout=120) as response, part.open('wb') as out:
            shutil.copyfileobj(response, out)
        if item['sha256'] and digest(part) != item['sha256']:
            raise RuntimeError(f'Checksum mismatch: {name}')
        os.replace(part, path)
    item['sha256'] = digest(path)
    print(f'Verified {name}: {item["version"]}', flush=True)
    return name, path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    if LOCK.exists() and not args.refresh:
        assets = json.loads(LOCK.read_text('utf-8'))['downloads']
    else:
        assets = {
            'yt-dlp': release('yt-dlp/yt-dlp', lambda n: n == 'yt-dlp.exe'),
            'aria2': release('aria2/aria2', lambda n: 'win-64bit' in n and n.endswith('.zip')),
            'deno': release('denoland/deno', lambda n: n == 'deno-x86_64-pc-windows-msvc.zip'),
            'ffmpeg': release('GyanD/codexffmpeg', lambda n: 'essentials_build.zip' in n),
            'sarasa': release('be5invis/Sarasa-Gothic', lambda n: n.startswith('SarasaMonoSC-TTF-') and 'Unhinted' not in n),
            'jetbrains': dict(version='v2.304', url='https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip', sha256='', source='https://github.com/JetBrains/JetBrainsMono/tree/v2.304'),
        }
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        downloaded = dict(pool.map(lambda kv: download(*kv), assets.items()))
    runtime = ROOT / 'desktop' / 'engines'
    fonts = ROOT / 'desktop' / 'assets' / 'fonts'
    legal = ROOT / 'desktop' / 'assets' / 'legal'
    for folder in (runtime, fonts, legal):
        folder.mkdir(parents=True, exist_ok=True)
    distributables = []
    for name, path in downloaded.items():
        extracted = CACHE / (name + '-extracted')
        extracted.mkdir(exist_ok=True)
        if path.suffix == '.zip':
            with zipfile.ZipFile(path) as archive:
                archive.extractall(extracted)
        elif path.suffix == '.7z':
            subprocess.run([str(Path(os.environ['SystemRoot']) / 'System32/tar.exe'), '-xf', str(path), '-C', str(extracted)], check=True)
        else:
            shutil.copy2(path, extracted / 'yt-dlp.exe')
        names = {'yt-dlp': ['yt-dlp.exe'], 'aria2': ['aria2c.exe'], 'deno': ['deno.exe'],
                 'ffmpeg': ['ffmpeg.exe', 'ffprobe.exe'],
                 'sarasa': ['SarasaMonoSC-Regular.ttf'],
                 'jetbrains': ['JetBrainsMono-Regular.ttf', 'JetBrainsMono-Bold.ttf']}[name]
        for filename in names:
            source = next(extracted.rglob(filename))
            dest = (fonts if name in ('sarasa', 'jetbrains') else runtime) / filename
            shutil.copy2(source, dest)
            distributables.append(dict(path=str(dest.relative_to(ROOT / 'desktop')).replace('\\', '/'), sha256=digest(dest), origin=name))
        for source in extracted.rglob('*'):
            if source.is_file() and source.name.lower() in ('license', 'license.txt', 'copying', 'ofl.txt', 'license.md'):
                shutil.copy2(source, legal / f'{name}-{source.name}.txt')
    lock = dict(schemaVersion=1, platform='windows-x64', downloads=assets, files=distributables)
    legal_sources = {
        'yt-dlp-LICENSE.txt': f'https://raw.githubusercontent.com/yt-dlp/yt-dlp/{assets["yt-dlp"]["version"]}/LICENSE',
        'yt-dlp-THIRD_PARTY_LICENSES.txt': f'https://raw.githubusercontent.com/yt-dlp/yt-dlp/{assets["yt-dlp"]["version"]}/THIRD_PARTY_LICENSES.txt',
        'deno-LICENSE.txt': f'https://raw.githubusercontent.com/denoland/deno/{assets["deno"]["version"]}/LICENSE.md',
        'sarasa-LICENSE.txt': f'https://raw.githubusercontent.com/be5invis/Sarasa-Gothic/{assets["sarasa"]["version"]}/LICENSE',
    }
    for filename, url in legal_sources.items():
        with urllib.request.urlopen(url, timeout=60) as response:
            (legal / filename).write_bytes(response.read())
    lock['legal'] = [dict(path='assets/legal/' + filename, url=url, sha256=digest(legal / filename)) for filename, url in legal_sources.items()]
    LOCK.write_text(json.dumps(lock, indent=2) + '\n', encoding='utf-8')
    shutil.copy2(LOCK, runtime / 'assets.lock.json')
    (legal / 'SOURCES.json').write_text(json.dumps(assets, indent=2) + '\n', encoding='utf-8')
    print('Runtime and fonts ready.', flush=True)


if __name__ == '__main__':
    main()
