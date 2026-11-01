"""Install pinned official server plugins into an explicitly selected CS2 host.

No game/client launch, privilege escalation, firewall changes or third-party
process termination. Every replaced file has a backup; partial work rolls back.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import tempfile
import time
from urllib.request import Request, urlopen
import uuid
import zipfile

PACKAGES = [
    ('metamod', '2.0.0.1483', 'https://github.com/alliedmodders/metamod-source/releases/download/2.0.0.1483/mmsource-2.0.0-git1483-windows.zip', '5a5b61413eeb4c204050d7cca83d28c5c707d9edd5e74d4fc9f96cde147c5341'),
    ('cssharp', '1.0.378', 'https://github.com/roflmuffin/CounterStrikeSharp/releases/download/v1.0.378/counterstrikesharp-with-runtime-windows-1.0.378.zip', '6784cc463e8a85e5e70d41c4190601ac4d93295ae7ebdd1e12b6bb92f861ae02'),
    ('matchzy', '0.9.2', 'https://github.com/shobhit-pathak/MatchZy/releases/download/0.9.2/MatchZy-0.9.2.zip', '8618294d1cfd1f951eeedc2e0b97b0780435cc62df9f9b0afe6738900ea71d88'),
]

def emit(phase, **values):
    print(json.dumps({'phase': phase, **values}), flush=True)

def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''): result.update(chunk)
    return result.hexdigest()

def safe_path(name):
    if '\\' in name or ':' in name or '\x00' in name: raise ValueError('unsafe_plugin_archive')
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts or not path.parts: raise ValueError('unsafe_plugin_archive')
    if path.parts[0] != 'addons' and tuple(path.parts[:2]) != ('cfg', 'MatchZy'):
        raise ValueError('unsafe_plugin_archive')
    return path

def no_links(root, target):
    target.relative_to(root)
    current = target
    while current != root.parent:
        if current.is_symlink() or (current.exists() and bool(getattr(current.stat(), 'st_file_attributes', 0) & 0x400)):
            raise ValueError('linked_server_path')
        if current == root: break
        current = current.parent

def patch_gameinfo(text):
    line = 'Game\tcsgo/addons/metamod'
    if re.search(r'^\s*Game\s+csgo/addons/metamod\s*$', text, re.M): return text
    marker = re.search(r'^[ \t]*Game_LowViolence[ \t]+csgo_lv[^\r\n]*', text, re.M)
    if not marker: raise ValueError('unknown_gameinfo')
    return text[:marker.end()] + '\n\t\t\t' + line + text[marker.end():]

def stage_package(archive, stage):
    with zipfile.ZipFile(archive) as zipped:
        if len(zipped.infolist()) > 3000 or sum(i.file_size for i in zipped.infolist()) > 750 * 1024 * 1024:
            raise ValueError('plugin_archive_limit')
        for info in zipped.infolist():
            if info.is_dir() and info.filename == 'cfg/': continue
            relative = safe_path(info.filename)
            if stat.S_ISLNK(info.external_attr >> 16) or info.flag_bits & 1: raise ValueError('unsafe_plugin_archive')
            if info.is_dir(): continue
            if info.file_size > 150 * 1024 * 1024: raise ValueError('plugin_archive_limit')
            destination = stage.joinpath(*relative.parts)
            destination.parent.mkdir(parents=True, exist_ok=True)
            with zipped.open(info) as src, destination.open('wb') as dst: shutil.copyfileobj(src, dst)

def install(server, cache, packages=PACKAGES):
    server = Path(os.path.abspath(server))
    if server.name.lower() != 'cs2.exe' or not server.is_file(): raise ValueError('invalid_server')
    root = server.parent.parent.parent / 'csgo'
    if not root.is_dir(): raise ValueError('invalid_server')
    no_links(root, root)
    gameinfo = root / 'gameinfo.gi'
    no_links(root, gameinfo)
    original_info = gameinfo.read_bytes()
    patched = patch_gameinfo(original_info.decode('utf-8-sig')).encode('utf-8')
    cache.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(root).free < 1500 * 1024 * 1024: raise ValueError('disk_space')
    with tempfile.TemporaryDirectory(prefix='teamsync-plugin-') as tmp:
        stage = Path(tmp)
        for name, version, url, expected in packages:
            target = cache / (name + '.zip')
            if not target.is_file() or digest(target) != expected:
                partial = target.with_suffix('.partial')
                emit('plugin_download', package=name, version=version)
                try:
                    with urlopen(Request(url, headers={'User-Agent': 'TeamSync-plugin-installer/0.3'}), timeout=30) as src, partial.open('wb') as dst:
                        total = 0
                        while True:
                            chunk = src.read(1024 * 1024)
                            if not chunk: break
                            total += len(chunk)
                            if total > 200 * 1024 * 1024: raise ValueError('plugin_download_limit')
                            dst.write(chunk)
                    if digest(partial) != expected: raise ValueError('plugin_checksum')
                    partial.replace(target)
                finally: partial.unlink(missing_ok=True)
            stage_package(target, stage)
        required = ['addons/metamod/bin/win64/server.dll', 'addons/counterstrikesharp/plugins/MatchZy/MatchZy.dll', 'addons/counterstrikesharp/api/CounterStrikeSharp.API.dll']
        if any(not (stage / name).is_file() for name in required): raise ValueError('incomplete_plugin_pack')
        receipt_id = time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8]
        backup = root / 'teamsync-plugin-backups' / receipt_id
        no_links(root, backup)
        backup.mkdir(parents=True)
        changes = []
        try:
            for source in stage.rglob('*'):
                if not source.is_file(): continue
                relative = source.relative_to(stage)
                target = root / relative
                no_links(root, target)
                # Never replace the coach's existing MatchZy configs/admins.
                if target.exists() and (relative.parts[0] == 'cfg' or tuple(relative.parts[:3]) == ('addons', 'counterstrikesharp', 'configs') or relative.as_posix() == 'addons/metamod/metaplugins.ini'): continue
                old = backup / relative if target.exists() else None
                if old:
                    old.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(target, old)
                target.parent.mkdir(parents=True, exist_ok=True)
                changes.append((target, old))
                shutil.copy2(source, target)
            shutil.copy2(gameinfo, backup / 'gameinfo.gi')
            changes.append((gameinfo, backup / 'gameinfo.gi'))
            gameinfo.write_bytes(patched)
            receipt = {'id': receipt_id, 'packages': [{'name': n, 'version': v, 'sha256': sha, 'source': url} for n, v, url, sha in packages], 'files': [str(p.relative_to(root)) for p, _ in changes]}
            (backup / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        except BaseException:
            for target, old in reversed(changes):
                if old: shutil.copy2(old, target)
                else: target.unlink(missing_ok=True)
            raise
        emit('plugin_complete', backup=str(backup), versions={n: v for n, v, _, _ in packages})

def main(argv=None):
    cli = argparse.ArgumentParser()
    cli.add_argument('--server', required=True)
    cli.add_argument('--cache', required=True)
    args = cli.parse_args(argv)
    try:
        install(Path(args.server), Path(args.cache))
        return 0
    except Exception as error:
        emit('error', code=str(error) if isinstance(error, ValueError) else 'plugin_install_failed')
        return 1

if __name__ == '__main__': raise SystemExit(main())
