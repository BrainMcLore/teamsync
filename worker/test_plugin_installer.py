import hashlib
from pathlib import Path
import zipfile

import pytest

import plugin_installer as installer


def fixture(tmp_path):
    root = tmp_path / 'host' / 'game'
    exe = root / 'bin' / 'win64' / 'cs2.exe'
    exe.parent.mkdir(parents=True)
    exe.write_bytes(b'test fixture - never executed')
    csgo = root / 'csgo'
    csgo.mkdir()
    (csgo / 'gameinfo.gi').write_text('SearchPaths\n{\n Game_LowViolence csgo_lv\n Game csgo\n}\n')
    cache = tmp_path / 'cache'
    cache.mkdir()
    with zipfile.ZipFile(cache / 'fixture.zip', 'w') as z:
        for name in ['addons/metamod/bin/win64/server.dll', 'addons/counterstrikesharp/plugins/MatchZy/MatchZy.dll', 'addons/counterstrikesharp/api/CounterStrikeSharp.API.dll', 'cfg/MatchZy/config.cfg']:
            z.writestr(name, b'test-only pinned bytes')
    sha = hashlib.sha256((cache / 'fixture.zip').read_bytes()).hexdigest()
    return exe, csgo, cache, [('fixture', 'test', 'https://invalid.example/never-fetched', sha)]


def test_install_preserves_coach_config_and_is_idempotent(tmp_path):
    exe, root, cache, packages = fixture(tmp_path)
    config = root / 'cfg' / 'MatchZy' / 'config.cfg'
    config.parent.mkdir(parents=True)
    config.write_text('my personal config')
    original = (root / 'gameinfo.gi').read_bytes()
    installer.install(exe, cache, packages)
    assert config.read_text() == 'my personal config'
    assert (root / 'addons/counterstrikesharp/plugins/MatchZy/MatchZy.dll').is_file()
    assert any(p.read_bytes() == original for p in (root / 'teamsync-plugin-backups').glob('*/gameinfo.gi'))
    installer.install(exe, cache, packages)
    assert (root / 'gameinfo.gi').read_text().count('csgo/addons/metamod') == 1


@pytest.mark.parametrize('name', ['../evil.dll', '/addons/evil.dll', 'addons/../../evil.dll', 'addons\\evil.dll', 'addons/c:evil.dll', 'cfg/server.cfg', 'gameinfo.gi'])
def test_plugin_archive_rejects_paths_outside_allowlist(name):
    with pytest.raises(ValueError): installer.safe_path(name)


def test_failed_write_rolls_back_all_replacements(tmp_path, monkeypatch):
    exe, root, cache, packages = fixture(tmp_path)
    previous = root / 'addons/counterstrikesharp/plugins/MatchZy/MatchZy.dll'
    previous.parent.mkdir(parents=True)
    previous.write_bytes(b'previous version')
    original = (root / 'gameinfo.gi').read_bytes()
    real_copy = installer.shutil.copy2
    count = 0
    def fail_once(src, dst, *a, **kw):
        nonlocal count
        # Fail only during the final gameinfo backup, after plugin writes.
        if Path(src) == root / 'gameinfo.gi' and count == 0:
            count += 1
            raise OSError('simulated disk failure')
        return real_copy(src, dst, *a, **kw)
    monkeypatch.setattr(installer.shutil, 'copy2', fail_once)
    with pytest.raises(OSError): installer.install(exe, cache, packages)
    assert previous.read_bytes() == b'previous version'
    assert (root / 'gameinfo.gi').read_bytes() == original
    assert not (root / 'addons/metamod/bin/win64/server.dll').exists()


def test_unknown_gameinfo_is_left_untouched(tmp_path):
    exe, root, cache, packages = fixture(tmp_path)
    info = root / 'gameinfo.gi'
    info.write_bytes(b'unknown format')
    with pytest.raises(ValueError): installer.install(exe, cache, packages)
    assert info.read_bytes() == b'unknown format'
    assert not (root / 'addons').exists()
