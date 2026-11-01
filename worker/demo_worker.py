"""Isolated, native-process CS2 importer and demoparser2 pipeline.

Public HLTV catalog support is provided by an on-demand HTTPS client.
Restricted archive downloads can fall back to the user’s browser. No accounts
or personal browser cookies are imported.
"""
import argparse
import hashlib
import http.client
import importlib.metadata
import ipaddress
import json
import math
import os
from pathlib import Path, PurePosixPath
import shutil
import socket
import ssl
import subprocess
import sys
import time
from urllib.parse import urlsplit, urljoin
import uuid
import zipfile

MAX_INPUT=2*1024**3
MAX_TOTAL=8*1024**3
MAX_DEMOS=20

class ImportFailure(Exception):
    pass

def emit(phase,progress=None,**extra):
    print(json.dumps({'phase':phase,'progress':progress,**extra},ensure_ascii=True,allow_nan=False),flush=True)

def validate_source_page(value):
    if not value:return None
    url=urlsplit(value)
    if url.scheme!='https' or url.username or url.password or url.hostname not in ('hltv.org','www.hltv.org') or not url.path.startswith('/matches/'):
        raise ImportFailure('invalid_source_page')
    return value

def public_address(host):
    addresses=socket.getaddrinfo(host,443,type=socket.SOCK_STREAM)
    if not addresses or any(not ipaddress.ip_address(entry[4][0]).is_global for entry in addresses):
        raise ImportFailure('unsafe_download_url')
    return addresses[0]

def download(url,target):
    host=urlsplit(url).hostname or ''
    if host in ('www.hltv.org','hltv.org','demos.hltv.org','r2-demos.hltv.org'):
        from hltv_catalog import download_demo
        return download_demo(url,target,MAX_INPUT)
    started=time.monotonic()
    for _ in range(6):
        parsed=urlsplit(url)
        if parsed.scheme!='https' or not parsed.hostname or parsed.username or parsed.password or parsed.port not in (None,443):
            raise ImportFailure('unsafe_download_url')
        family,socktype,proto,_,address=public_address(parsed.hostname)
        connection=http.client.HTTPSConnection(parsed.hostname,timeout=25)
        raw=socket.socket(family,socktype,proto);raw.settimeout(25)
        try:
            raw.connect(address)
            connection.sock=ssl.create_default_context().wrap_socket(raw,server_hostname=parsed.hostname)
            path=parsed.path or '/'
            if parsed.query:path+='?'+parsed.query
            connection.request('GET',path,headers={'User-Agent':'TeamSync/0.2 (native demo importer)','Accept':'application/octet-stream,*/*;q=0.5'})
            response=connection.getresponse()
            if response.status in (301,302,303,307,308):
                location=response.getheader('Location')
                if not location:raise ImportFailure('download_failed')
                url=urljoin(url,location)
                continue
            if response.status in (401,403,429,503):raise ImportFailure('source_blocked')
            if response.status!=200:raise ImportFailure('download_failed')
            if 'text/html' in (response.getheader('Content-Type') or '').lower():raise ImportFailure('source_blocked')
            size=int(response.getheader('Content-Length') or 0)
            if size>MAX_INPUT:raise ImportFailure('file_too_large')
            if shutil.disk_usage(target.parent).free<max(size,256*1024**2)+512*1024**2:raise ImportFailure('insufficient_space')
            received=0;last=0
            with target.open('wb') as output:
                while True:
                    chunk=response.read(1024*1024)
                    if not chunk:break
                    received+=len(chunk)
                    if received>MAX_INPUT:raise ImportFailure('file_too_large')
                    output.write(chunk)
                    if time.monotonic()-last>0.2:
                        emit('downloading',received/size if size else None,bytes=received,total=size,speed=received/max(time.monotonic()-started,.01));last=time.monotonic()
            if size and received!=size:raise ImportFailure('download_incomplete')
            return target
        finally:
            connection.close();raw.close()
    raise ImportFailure('too_many_redirects')

def safe_member(name):
    path=PurePosixPath(name.replace('\\','/'))
    return not(path.is_absolute() or '..' in path.parts or ':' in name or name.startswith(('-', '/', '\\')) or '\x00' in name)

def copy_limited(source,target,expected=None):
    total=0
    with target.open('wb') as output:
        while True:
            data=source.read(1024*1024)
            if not data:break
            total+=len(data)
            if total>MAX_INPUT or expected is not None and total>expected:raise ImportFailure('archive_limit')
            output.write(data)
    if expected is not None and total!=expected:raise ImportFailure('archive_corrupt')

def find_7zip():
    roots=[Path(sys.executable).parent,Path(__file__).parent,Path(os.getenv('ProgramFiles','C:/Program Files'))/'7-Zip']
    for root in roots:
        for path in (root/'7z.exe',root/'tools/7z.exe'):
            if path.is_file():return str(path)
    raise ImportFailure('archive_tool_missing')

def unpack(source,folder):
    signature=source.open('rb').read(8)
    if signature==b'PBDEMS2\x00':
        target=folder/(uuid.uuid4().hex+'.dem')
        with source.open('rb') as input_file:copy_limited(input_file,target)
        return [(source.name,target)]
    extracted=[]
    if zipfile.is_zipfile(source):
        with zipfile.ZipFile(source) as archive:
            entries=archive.infolist()
            if len(entries)>512 or any(not safe_member(e.filename) or ((e.external_attr>>16)&0o170000)==0o120000 for e in entries):raise ImportFailure('unsafe_archive')
            demos=[e for e in entries if e.filename.lower().endswith('.dem') and not e.is_dir()]
            if not demos or len(demos)>MAX_DEMOS or sum(e.file_size for e in demos)>MAX_TOTAL or any(e.file_size>MAX_INPUT or e.flag_bits&1 for e in demos):raise ImportFailure('archive_limit')
            if shutil.disk_usage(folder).free<sum(e.file_size for e in demos)+512*1024**2:raise ImportFailure('insufficient_space')
            for entry in demos:
                target=folder/(uuid.uuid4().hex+'.dem')
                with archive.open(entry) as stream:copy_limited(stream,target,entry.file_size)
                extracted.append((PurePosixPath(entry.filename.replace('\\','/')).name,target))
        return extracted
    if signature[:6]==b'Rar!\x1a\x07':
        import rarfile
        with rarfile.RarFile(source) as archive:
            entries=archive.infolist()
            if len(entries)>512 or any(not safe_member(e.filename) or e.is_symlink() for e in entries):raise ImportFailure('unsafe_archive')
            demos=[e for e in entries if e.filename.lower().endswith('.dem') and not e.is_dir()]
            if not demos or len(demos)>MAX_DEMOS or sum(e.file_size for e in demos)>MAX_TOTAL or any(e.file_size>MAX_INPUT or e.needs_password() for e in demos):raise ImportFailure('archive_limit')
            if shutil.disk_usage(folder).free<sum(e.file_size for e in demos)+512*1024**2:raise ImportFailure('insufficient_space')
            seven=find_7zip()
            for entry in demos:
                target=folder/(uuid.uuid4().hex+'.dem')
                with target.open('wb') as output:
                    process=subprocess.Popen([seven,'x','-so','-y','-spd','--',str(source),entry.filename],stdout=output,stderr=subprocess.DEVNULL,stdin=subprocess.DEVNULL,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
                    started=time.monotonic()
                    while process.poll() is None:
                        if time.monotonic()-started>120 or target.stat().st_size>entry.file_size:
                            process.kill();process.wait();raise ImportFailure('archive_limit')
                        time.sleep(.05)
                if process.returncode!=0 or target.stat().st_size!=entry.file_size:raise ImportFailure('archive_corrupt')
                extracted.append((PurePosixPath(entry.filename.replace('\\','/')).name,target))
        return extracted
    raise ImportFailure('unsupported_format')

def records(df):
    for column in df.columns:
        if column=='steamid' or column.endswith('_steamid'):
            df[column]=df[column].map(lambda x:str(int(x)) if x is not None and x==x else None)
    return json.loads(df.to_json(orient='records',double_precision=3,force_ascii=False))

def parse_demo(path,output,name,source_page=None):
    from demoparser2 import DemoParser
    if path.open('rb').read(8)!=b'PBDEMS2\x00':raise ImportFailure('invalid_demo')
    emit('header',.05)
    parser=DemoParser(str(path))
    header=parser.parse_header()
    ends=records(parser.parse_event('round_end'))
    starts=records(parser.parse_event('round_freeze_end'))
    if not ends:raise ImportFailure('no_round_data')
    last=max(int(e['tick']) for e in ends)
    if last>3_000_000:raise ImportFailure('demo_limit')
    emit('events',.2)
    kills=records(parser.parse_event('player_death',player=['team_num'],other=['total_rounds_played']))
    events={}
    for event in ['bomb_planted','bomb_defused','bomb_exploded','smokegrenade_detonate','smokegrenade_expired','inferno_startburn','inferno_expire','hegrenade_detonate','flashbang_detonate']:
        try:events[event]=records(parser.parse_event(event,player=['X','Y','Z']) if event.startswith('bomb_') else parser.parse_event(event))
        except Exception:events[event]=[]
    emit('positions',.35)
    stride=16
    frame_ticks=list(range(0,last+1,stride))
    fields=['X','Y','Z','health','armor_value','team_num','yaw','active_weapon_name','total_rounds_played','is_alive','game_time']
    ticks=records(parser.parse_ticks(fields,ticks=frame_ticks))
    emit('indexing',.8)
    frames={};players={}
    for row in ticks:
        if row.get('X') is None or row.get('Y') is None or row.get('team_num') not in (2,3):continue
        steamid=row['steamid'];tick=int(row['tick'])
        players[steamid]={'steamid':steamid,'name':row['name']}
        frame=frames.setdefault(tick,{'tick':tick,'round':int(row.get('total_rounds_played') or 0)+1,'time':row.get('game_time'),'players':[]})
        frame['players'].append({'id':steamid,'x':row['X'],'y':row['Y'],'z':row.get('Z'),'hp':row['health'],'armor':row.get('armor_value'),'team':row['team_num'],'yaw':row.get('yaw'),'weapon':row.get('active_weapon_name'),'alive':row.get('is_alive')})
    ordered=[frames[t] for t in sorted(frames)]
    if not ordered:raise ImportFailure('no_position_data')
    # Derive observed tick rate from the game's recorded clock, rather than the file's origin.
    rates=[]
    for a,b in zip(ordered,ordered[1:]):
        if a['time'] is not None and b['time'] is not None and b['time']>a['time']:
            rate=(b['tick']-a['tick'])/(b['time']-a['time'])
            if 30<rate<256:rates.append(rate)
    tickrate=round(sorted(rates)[len(rates)//2]) if rates else 64
    rounds=[];previous_end=0
    for number,end in enumerate(ends,1):
        end_tick=int(end['tick'])
        candidates=[int(s['tick']) for s in starts if previous_end<int(s['tick'])<=end_tick]
        start=candidates[0] if candidates else previous_end
        rounds.append({'number':number,'start':start,'end':end_tick,'winner':end.get('winner'),'reason':end.get('reason')})
        previous_end=end_tick
    for player in players.values():
        sid=player['steamid']
        player['kills']=sum(k.get('attacker_steamid')==sid and k.get('user_steamid')!=sid and k.get('attacker_team_num')!=k.get('user_team_num') for k in kills)
        player['deaths']=sum(k.get('user_steamid')==sid for k in kills)
        player['assists']=sum(k.get('assister_steamid')==sid for k in kills)
    result={'schema':1,'parser':'demoparser2','parser_version':importlib.metadata.version('demoparser2'),'name':name,'header':header,'map':header.get('map_name'),'tick_rate':tickrate,'tick_rate_measured':bool(rates),'sample_stride':stride,'players':list(players.values()),'rounds':rounds,'kills':kills,'events':events,'frames':ordered,'source_page':source_page,'radar_version_notice':True}
    temporary=output.with_suffix('.partial')
    encoded=json.dumps(result,ensure_ascii=False,separators=(',',':'),allow_nan=False)
    if len(encoded.encode('utf-8'))>100*1024*1024:raise ImportFailure('demo_limit')
    temporary.write_text(encoded,encoding='utf-8')
    temporary.replace(output)
    digest=hashlib.file_digest(path.open('rb'),'sha256').hexdigest() if hasattr(hashlib,'file_digest') else file_hash(path)
    return {'name':name,'path':str(path.resolve()),'analysis':str(output.resolve()),'map':result['map'],'size':path.stat().st_size,'sha256':digest,'rounds':len(rounds),'players':len(players),'participants':list(players.values())}

def file_hash(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def main():
    cli=argparse.ArgumentParser();cli.add_argument('--input',required=True);cli.add_argument('--output',required=True);cli.add_argument('--source-page',default='')
    args=cli.parse_args();folder=Path(args.output).resolve();folder.mkdir(parents=True,exist_ok=True)
    try:
        from resource_limits import constrain
        constrain(active_processes=32 if (urlsplit(args.input).hostname or '').endswith('hltv.org') else 4)
        source_page=validate_source_page(args.source_page)
        source=Path(args.input)
        if args.input.startswith(('https://','http://')):
            source=download(args.input,folder/'download.tmp')
        if not source.is_file() or source.stat().st_size>MAX_INPUT:raise ImportFailure('file_too_large')
        emit('extracting',0)
        demos=unpack(source,folder)
        imported=[]
        for index,(name,path) in enumerate(demos):
            emit('parsing',index/len(demos),index=index+1,total_files=len(demos))
            imported.append(parse_demo(path,path.with_suffix('.json'),name,source_page))
        if source.name=='download.tmp':source.unlink(missing_ok=True)
        emit('complete',1,items=imported,source_page=source_page,match_id=str(uuid.uuid4()))
    except BaseException as error:
        code=str(error) if isinstance(error,ImportFailure) else 'parse_failed'
        emit('error',code=code)
        return 1
    return 0

if __name__=='__main__':
    sys.modules.setdefault('demo_worker',sys.modules[__name__])
    sys.stdout.reconfigure(encoding='utf-8')
    if '--hltv' in sys.argv:
        import hltv_catalog
        raise SystemExit(hltv_catalog.main([a for a in sys.argv[1:] if a != '--hltv']))
    if '--install-server' in sys.argv:
        import server_installer
        raise SystemExit(server_installer.main([a for a in sys.argv[1:] if a != '--install-server']))
    if '--install-plugin' in sys.argv:
        import plugin_installer
        raise SystemExit(plugin_installer.main([a for a in sys.argv[1:] if a != '--install-plugin']))
    raise SystemExit(main())
