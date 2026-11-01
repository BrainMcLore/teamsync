"""Restart acceptance check on the task-owned QA emulator and local fixture only."""
import hashlib
from pathlib import Path
import sqlite3
import subprocess
import time
from urllib.parse import parse_qs,urlsplit
import httpx

ROOT=Path(__file__).resolve().parents[1]
ADB=ROOT/'.tools/android-sdk/platform-tools/adb.exe'
SERIAL='emulator-5554'
PACKAGE='app.teamsync.teamsync'
def adb(*args):
    return subprocess.run([str(ADB),'-s',SERIAL,*args],capture_output=True,check=True).stdout

if __name__=='__main__':
    if b'TeamSync_QA_35' not in adb('emu','avd','name'):
        raise RuntimeError('This check only operates on the task-owned QA emulator')
    adb('reverse','tcp:8766','tcp:8766')
    adb('install','-r',str(ROOT/'.tools/android-main-debug-06.apk'))
    adb('shell','am','force-stop',PACKAGE)
    challenge=adb('shell','run-as',PACKAGE,'cat','files/qa-challenge-06.txt').decode().strip()
    if len(challenge)!=43:raise RuntimeError('QA setup did not persist the PKCE challenge')
    started=time.time()
    with httpx.Client(timeout=15,follow_redirects=False) as client:
        response=client.post('http://127.0.0.1:8766/api/v1/auth/steam/start',json={'redirect':'teamsync://auth/callback','challenge':challenge})
        response.raise_for_status()
        callback=parse_qs(urlsplit(response.json()['url']).query)['openid.return_to'][0]
        response=client.get(callback)
        if response.status_code!=303:raise RuntimeError('fixture provider failed')
        redirect=response.headers['location']
    if not redirect.startswith('teamsync://auth/callback?code='):raise RuntimeError('Unexpected fixture callback')
    adb('shell','am','start','-W','-a','android.intent.action.VIEW','-d',redirect)
    for _ in range(20):
        with sqlite3.connect(ROOT/'.tools/account-integration-06.sqlite') as conn:
            restored=conn.execute("SELECT count(*) FROM sessions WHERE device='android' AND created>?",(started,)).fetchone()[0]
        if restored:break
        time.sleep(1)
    if not restored:raise RuntimeError('Android did not exchange the callback after restart')
    time.sleep(2)
    (ROOT/'artifacts/verification/android-cold-login-06.png').write_bytes(adb('exec-out','screencap','-p'))
    print('Cold process restart: Android received the deep link, restored the secure PKCE request and created an authenticated session.')
