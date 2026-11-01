"""Download the pinned upstream CS2 parser fixture for integration tests only."""
from pathlib import Path
from urllib.request import urlopen
import hashlib

root=Path(__file__).resolve().parents[1]
target=root/'.tools/demo-fixtures/test_demo.dem'
target.parent.mkdir(parents=True,exist_ok=True)
url='https://raw.githubusercontent.com/LaihoE/demoparser/af781eaf2ee98be5ca875e241b4e971e49570be8/src/parser/test_demo.dem'
expected='84a1a4191302bdd2a3bbb5a727842093744b1fb1a228aeec630369e44b622cb2'
with urlopen(url,timeout=60) as response,target.open('wb') as output:
    checksum=hashlib.sha256()
    while chunk:=response.read(1024*1024):output.write(chunk);checksum.update(chunk)
if checksum.hexdigest()!=expected:raise RuntimeError('Unexpected upstream fixture checksum')
print(target)
