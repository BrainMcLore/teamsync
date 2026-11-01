"""Check reproducibility and exclusion of local credentials from release source."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from zipfile import ZipFile


class ReleaseChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'tools').mkdir()
        for name in ['package-source.py', 'release_utils.py', 'release-checksums.py']:
            shutil.copyfile(Path(__file__).parent / name, self.root / 'tools' / name)
        (self.root / 'client/lib').mkdir(parents=True)
        (self.root / 'client/pubspec.yaml').write_text('version: 0.8.0+8\n')
        (self.root / 'client/lib/app.dart').write_text('source\n')

    def run_tool(self, name, *args, check=True):
        return subprocess.run([sys.executable, str(self.root / 'tools' / name), *args],
                              capture_output=True, text=True, check=check)

    def test_source_is_reproducible_and_omits_credentials_and_generated_files(self):
        for relative in ['client/.env.local', 'client/local.properties', 'client/user.sqlite-wal',
                         'tools/auth.json', 'client/build/session.txt', 'client/.codex/auth.json',
                         'client/debug.keystore', 'client/failures/screenshot.png']:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('private fixture')
        (self.root / '.github/workflows').mkdir(parents=True)
        (self.root / '.github/workflows/build.yml').write_text('name: build\n')
        self.run_tool('package-source.py')
        archive = self.root / 'dist/TeamSync-0.8.0-Source.zip'
        before = hashlib.sha256(archive.read_bytes()).hexdigest()
        with ZipFile(archive) as zipped:
            names = zipped.namelist()
            self.assertIn('TeamSync/client/lib/app.dart', names)
            self.assertIn('TeamSync/.github/workflows/build.yml', names)
            self.assertFalse(any('private fixture' in zipped.read(n).decode('utf-8', errors='ignore') for n in names))
        self.run_tool('package-source.py')
        self.assertEqual(before, hashlib.sha256(archive.read_bytes()).hexdigest())

    def test_missing_binaries_are_reported_and_required_windows_build_fails(self):
        self.run_tool('package-source.py')
        self.run_tool('release-checksums.py')
        manifest = json.loads((self.root / 'dist/TeamSync-0.8.0-manifest.json').read_text())
        self.assertFalse(manifest['complete'])
        self.assertEqual(len(manifest['missing']), 2)
        self.assertNotEqual(self.run_tool('release-checksums.py', '--require-windows', check=False).returncode, 0)
        artifact = self.root / 'dist/TeamSync-0.8.0-Windows-Setup.exe'
        artifact.write_bytes(b'fixture installer')
        self.run_tool('release-checksums.py', '--require-windows')
        manifest = json.loads((self.root / 'dist/TeamSync-0.8.0-manifest.json').read_text())
        entry = next(f for f in manifest['files'] if f['name'] == artifact.name)
        self.assertEqual(entry['sha256'], hashlib.sha256(artifact.read_bytes()).hexdigest())
        android = self.root / 'dist/TeamSync-0.8.0-Android.apk'
        android.write_bytes(b'fixture signed apk')
        self.run_tool('release-checksums.py', '--require-windows', '--require-android')
        manifest = json.loads((self.root / 'dist/TeamSync-0.8.0-manifest.json').read_text())
        self.assertTrue(manifest['complete'])
        self.assertIn(android.name, [item['name'] for item in manifest['files']])
        self.assertNotIn('TeamSync-0.8.0-Android-test.apk', manifest['missing'])



if __name__ == '__main__':
    unittest.main()
