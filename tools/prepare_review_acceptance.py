"""Parse the pinned public recording and enable the real-recording query benchmark."""
from pathlib import Path
import sys
import shutil

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from worker.demo_worker import parse_demo

if __name__ == '__main__':
    source = ROOT / '.tools/demo-fixtures/test_demo.dem'
    destination = ROOT / '.tools/acceptance-review/mirage.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    parse_demo(source, destination, source.name)
    golden_fixture = ROOT / '.tools/demo-fixtures/parsed/mirage.json'
    golden_fixture.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(destination, golden_fixture)
    (ROOT / '.tools/benchmark-source-04.txt').write_text(str(destination), encoding='utf-8')
    print('Pinned public recording prepared for review acceptance.')
