import io
import json
from pathlib import Path
import socket
import struct
import zipfile
import zlib

import pytest
from worker.demo_worker import ImportFailure, unpack, parse_demo, public_address, validate_source_page

FIXTURE=Path(__file__).resolve().parents[1]/'.tools/demo-fixtures/test_demo.dem'

def test_archive_traversal_and_symlinks_are_rejected(tmp_path):
    archive=tmp_path/'bad.zip'
    with zipfile.ZipFile(archive,'w') as z:
        z.writestr('../escape.dem',b'PBDEMS2\0'+b'0'*20)
    with pytest.raises(ImportFailure,match='unsafe_archive'):
        unpack(archive,tmp_path)
    with zipfile.ZipFile(archive,'w') as z:
        link=zipfile.ZipInfo('recording.dem');link.create_system=3;link.external_attr=0o120777<<16
        z.writestr(link,'/etc/passwd')
    with pytest.raises(ImportFailure,match='unsafe_archive'):
        unpack(archive,tmp_path)

def test_private_sources_and_fake_hltv_pages_are_rejected(monkeypatch):
    monkeypatch.setattr(socket,'getaddrinfo',lambda *a,**k:[(socket.AF_INET,socket.SOCK_STREAM,6,'',('127.0.0.1',443))])
    with pytest.raises(ImportFailure,match='unsafe_download_url'):public_address('example.com')
    for page in ['https://hltv.org.evil.example/matches/1','file:///matches/1','https://www.hltv.org/news/1']:
        with pytest.raises(ImportFailure):validate_source_page(page)
    assert validate_source_page('https://www.hltv.org/matches/1/test')=='https://www.hltv.org/matches/1/test'

def test_corrupt_demo_is_rejected(tmp_path):
    source=tmp_path/'fake.dem';source.write_bytes(b'not a demo')
    with pytest.raises(ImportFailure,match='invalid_demo'):
        parse_demo(source,tmp_path/'review.json','fake.dem')

def rar_header(kind,flags,body=b'',header_size=None):
    header=struct.pack('<BHH',kind,flags,header_size or 7+len(body))+body
    return struct.pack('<H',zlib.crc32(header)&0xffff)+header

@pytest.mark.skipif(not FIXTURE.exists(),reason='Download the upstream real CS2 demo fixture first')
def test_real_demo_zip_and_rar_then_parse(tmp_path):
    payload=FIXTURE.read_bytes()
    archive=tmp_path/'two-maps.zip'
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=1) as z:
        z.writestr('match/mirage.dem',payload)
        z.writestr('README.txt','One file per map, never one file per player.')
    output=tmp_path/'zip-output';output.mkdir()
    entries=unpack(archive,output)
    assert len(entries)==1
    result=parse_demo(entries[0][1],output/'review.json',entries[0][0])
    data=json.loads((output/'review.json').read_text(encoding='utf-8'))
    assert result['map']=='de_mirage' and result['players']==10 and result['rounds']==10
    assert len(data['kills'])==73 and len(data['frames'])>3000
    assert data['tick_rate_measured'] and data['tick_rate']==64
    assert all(isinstance(p['steamid'],str) for p in data['players'])
    assert all(0<=p['hp']<=100 for f in data['frames'] for p in f['players'])
    # A standard stored RAR4 fixture exercises the native 7-Zip extraction path.
    name=b'mirage.dem'
    file_body=struct.pack('<IIBIIBBHI',len(payload),len(payload),2,zlib.crc32(payload)&0xffffffff,0,20,0x30,len(name),0x20)+name
    rar=tmp_path/'match.rar'
    with rar.open('wb') as f:
        f.write(b'Rar!\x1a\x07\x00');f.write(rar_header(0x73,0,b'\0'*6));f.write(rar_header(0x74,0x8000,file_body));f.write(payload);f.write(rar_header(0x7b,0))
    rar_output=tmp_path/'rar-output';rar_output.mkdir()
    rar_entries=unpack(rar,rar_output)
    assert len(rar_entries)==1 and rar_entries[0][1].read_bytes()==payload
