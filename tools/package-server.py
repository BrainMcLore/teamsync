"""The deploy package contains no desktop files, fixtures or secrets."""
from pathlib import Path
from release_utils import write_archive
root=Path(__file__).resolve().parents[1]
files=[root/'render.yaml',root/'.python-version',root/'FREE_HOSTING.md']
files.extend(p for p in (root/'server').rglob('*') if p.is_file()
    and not any(part in ('tests','__pycache__') for part in p.parts)
    and (p.suffix in ('.py','.sql','.txt') or p.name=='Dockerfile'))
target=root/'dist/TeamSync-0.7.0-Server.zip'
payload={path.relative_to(root).as_posix(): path.read_bytes() for path in files}
payload['README.md']=(root/'FREE_HOSTING.md').read_bytes()
write_archive(target, payload)
print(target)
