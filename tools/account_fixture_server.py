"""Local integration fixture only. Never deploy this file as the production API.

Provider assertions are deliberately replaced for reproducible device testing.
It binds only to loopback; no production settings, tokens or users are loaded.
"""
import os
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
os.environ['DISCORD_CLIENT_ID']='fixture'
os.environ['DISCORD_CLIENT_SECRET']='fixture'
from server import app as module

async def fixture_identity(provider,query,*args):
    subject=query.get('fixture_subject','76561198000000001')
    if subject not in ('76561198000000001','76561198000000002'):
        from server.auth import fail
        fail('provider_verification_failed',401)
    return subject,'QA Owner' if subject.endswith('1') else 'QA Player'

module.verified_identity=fixture_identity
database=ROOT/'.tools/account-integration-06.sqlite'
app=module.create_app('sqlite:///'+str(database),'http://127.0.0.1:8766')
if __name__=='__main__':
    import uvicorn
    uvicorn.run(app,host='127.0.0.1',port=8766,access_log=False)
