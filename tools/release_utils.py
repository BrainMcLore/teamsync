"""Release metadata and reproducible archives; standard library only."""
import hashlib
import re
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED


def client_version(root: Path) -> str:
    source = (root / 'client/pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+(?:-[\w.-]+)?)(?:\+\d+)?\s*$', source, re.M)
    if not match:
        raise ValueError('Missing client release version')
    return match[1]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def write_archive(target: Path, files: dict[str, bytes]) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(target.suffix + '.partial')
    try:
        with ZipFile(partial, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
            for name, content in sorted(files.items()):
                info = ZipInfo(name, (1980, 1, 1, 0, 0, 0))
                mode = 0o755 if name.endswith('/gradlew') else 0o644
                info.create_system = 3
                info.external_attr = (0o100000 | mode) << 16
                info.compress_type = ZIP_DEFLATED
                archive.writestr(info, content)
        with ZipFile(partial) as archive:
            if archive.testzip() is not None:
                raise ValueError('Archive integrity check failed')
        partial.replace(target)
    finally:
        partial.unlink(missing_ok=True)
