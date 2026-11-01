"""Package reviewable source without SDKs, builds, secrets or machine paths."""
from pathlib import Path
from release_utils import client_version, write_archive

root=Path(__file__).resolve().parents[1]
excluded={'build','failures','.dart_tool','.gradle','ephemeral','Pods','.symlinks','__pycache__','.pytest_cache','.git','.idea','.tools','.venv','.codex','.aws','.agents'}
files=[*root.glob('*.md'),root/'compose.yaml',root/'.gitignore',root/'.gitattributes',root/'render.yaml',root/'.python-version']
files.extend(root.glob('artifacts/verification/studio-*-08*.png'))
files.append(root/'artifacts/app-icon.png')
files.extend(root.glob('artifacts/verification/review-performance-04.json'))
for folder in ['client','server','worker','tools','packaging','native','.github']:
    for file in (root/folder).rglob('*'):
        if not file.is_file() or any(part in excluded for part in file.relative_to(root).parts):
            continue
        if (file.name.startswith('.env') and file.name != '.env.example') or file.name in {'auth.json','flutter_secure_storage.dat','local.properties','key.properties','.flutter-plugins-dependencies'} or file.suffix in {'.log','.pyc','.jks','.keystore','.iml','.pem','.key','.dem'} or '.sqlite' in file.name:
            continue
        files.append(file)
target=root/f'dist/TeamSync-{client_version(root)}-Source.zip'
write_archive(target, {'TeamSync/'+file.relative_to(root).as_posix(): file.read_bytes()
    for file in sorted(set(files)) if file.is_file()})
print(target)

