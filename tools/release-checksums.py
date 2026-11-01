"""Hash existing artifacts and explicitly report missing client binaries."""
import argparse
import json
from pathlib import Path
from release_utils import client_version, sha256_file

root = Path(__file__).resolve().parents[1]
cli = argparse.ArgumentParser()
cli.add_argument('--require-windows', action='store_true')
cli.add_argument('--require-android', action='store_true')
args = cli.parse_args()
version = client_version(root)
dist = root / 'dist'
dist.mkdir(exist_ok=True)
expected = [f'TeamSync-{version}-Windows-Setup.exe', f'TeamSync-{version}-Android-test.apk',
            f'TeamSync-{version}-Source.zip']
missing = [name for name in expected if not (dist / name).is_file()]
for required, name in [(args.require_windows, expected[0]), (args.require_android, expected[1])]:
    if required and name in missing:
        cli.error(f'Required artifact is missing: {name}')
paths = [dist / name for name in expected if (dist / name).is_file()]
server = dist / 'TeamSync-0.7.0-Server.zip'
if server.is_file():
    paths.append(server)
files = [{'name': p.name, 'bytes': p.stat().st_size, 'sha256': sha256_file(p)} for p in sorted(paths)]
(dist / f'SHA256SUMS-{version}.txt').write_text(
    ''.join(f"{f['sha256']}  {f['name']}\n" for f in files), encoding='ascii')
manifest = {'client_version': version, 'targets': ['windows', 'android'],
            'complete': not missing, 'missing': missing, 'files': files}
(dist / f'TeamSync-{version}-manifest.json').write_text(
    json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'artifacts': len(files), 'complete': not missing, 'missing': missing}))
