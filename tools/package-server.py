"""The deploy package contains no desktop files, fixtures or secrets."""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
root=Path(__file__).resolve().parents[1]
files=[root/'render.yaml',root/'.python-version',root/'FREE_HOSTING.md']
files.extend(p for p in (root/'server').rglob('*') if p.is_file()
    and not any(part in ('tests','__pycache__') for part in p.parts)
    and (p.suffix in ('.py','.sql','.txt') or p.name=='Dockerfile'))
target=root/'dist/TeamSync-0.7.0-Server.zip'
with ZipFile(target,'w',ZIP_DEFLATED) as archive:
    for path in files:archive.write(path,path.relative_to(root).as_posix())
    archive.writestr('README.md',(root/'FREE_HOSTING.md').read_text(encoding='utf-8'))
print(target)
