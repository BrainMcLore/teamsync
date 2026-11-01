"""Package reviewable source without SDKs, builds, secrets or machine paths."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root=Path(__file__).resolve().parents[1]
excluded={'build','failures','.dart_tool','.gradle','ephemeral','Pods','.symlinks','__pycache__','.pytest_cache','.git','.idea'}
files=[*root.glob('*.md'),root/'compose.yaml',root/'.gitignore',root/'render.yaml',root/'.python-version']
files.extend(root.glob('artifacts/verification/studio-*-08.png'))
files.extend(root.glob('artifacts/verification/review-performance-04.json'))
for folder in ['client','server','worker','tools','packaging','native']:
    for file in (root/folder).rglob('*'):
        if not file.is_file() or any(part in excluded for part in file.relative_to(root).parts):
            continue
        if file.name in {'.env','local.properties','key.properties','.flutter-plugins-dependencies'} or file.suffix in {'.log','.pyc','.jks','.keystore','.iml'}:
            continue
        files.append(file)
target=root/'dist/TeamSync-0.8.0-Source.zip'
target.parent.mkdir(exist_ok=True)
with ZipFile(target,'w',ZIP_DEFLATED) as archive:
    for file in sorted(set(files)):
        archive.write(file,'TeamSync/'+file.relative_to(root).as_posix())
print(target)

