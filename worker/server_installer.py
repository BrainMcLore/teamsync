"""First-party server downloads, no server launch or licence acceptance.
CS2 is installed by Valve SteamCMD using anonymous app 730, with resumable
Steam content updates. Destinations must be dedicated TeamSync-owned folders.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import time
from urllib.request import Request, urlopen
import zipfile

SOURCES = {
    'teamspeak': ('https://files.teamspeak-services.com/releases/server/3.13.8/teamspeak3-server_win64-3.13.8.zip', '1dbde314c4895af0c8aae73755b2a920e564fabcb2c651e56d0532a473cdc5cb'),
    'steamcmd': ('https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip', '7669b170dee42db8ee2273775ed7dfb2d173bdba1b849f70d2c7b379290bce13'),
}

def emit(phase, **extra): print(json.dumps({'phase':phase, **extra},ensure_ascii=True),flush=True)

def checksum(path):
    value=hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda:source.read(1024*1024),b''): value.update(chunk)
    return value.hexdigest()

def owned_folder(path, kind):
    path=Path(os.path.abspath(path))
    if path.name.lower()!=kind or path.parent.name.lower()!='teamsyncservers' or any(c in str(path) for c in '\r\n;"'):
        raise ValueError('invalid_server_destination')
    cursor=path
    while cursor.parent!=cursor:
        if cursor.is_symlink() or (cursor.exists() and bool(getattr(cursor.stat(),'st_file_attributes',0)&0x400)): raise ValueError('linked_server_path')
        cursor=cursor.parent
    marker=path/'.teamsync-install.json'
    if path.exists() and any(path.iterdir()):
        if not marker.is_file() or json.loads(marker.read_text()) .get('kind')!=kind: raise ValueError('server_folder_not_owned')
    path.mkdir(parents=True,exist_ok=True)
    if not marker.exists(): marker.write_text(json.dumps({'kind':kind,'state':'pending','updated':time.time()}))
    return path

def download(name, cache):
    cache.mkdir(parents=True,exist_ok=True); target=cache/(name+'.zip'); url, expected=SOURCES[name]
    if target.exists() and checksum(target)==expected: return target
    partial=target.with_suffix('.partial'); size=0; started=time.monotonic()
    try:
        with urlopen(Request(url,headers={'User-Agent':'TeamSync-server-setup/0.4'}),timeout=30) as source, partial.open('wb') as out:
            length=int(source.headers.get('Content-Length','0') or 0)
            for chunk in iter(lambda:source.read(256*1024),b''):
                size+=len(chunk)
                if size>50*1024*1024: raise ValueError('server_download_limit')
                out.write(chunk); emit('server_download',progress=size/length if length else None,bytes=size,speed=size/max(time.monotonic()-started,.01))
        if checksum(partial)!=expected: raise ValueError('server_checksum_changed')
        partial.replace(target); return target
    finally: partial.unlink(missing_ok=True)

def safe_extract(archive, destination, prefix=''):
    planned=[]
    with zipfile.ZipFile(archive) as source:
        if len(source.infolist())>2000 or sum(i.file_size for i in source.infolist())>200*1024*1024: raise ValueError('unsafe_server_archive')
        for info in source.infolist():
            name=info.orig_filename
            if '\\' in name or ':' in name or stat.S_ISLNK(info.external_attr>>16) or info.flag_bits&1: raise ValueError('unsafe_server_archive')
            relative=PurePosixPath(name)
            if relative.is_absolute() or '..' in relative.parts: raise ValueError('unsafe_server_archive')
            if prefix:
                if not name.startswith(prefix): raise ValueError('unsafe_server_archive')
                name=name[len(prefix):]
            if not name or info.is_dir(): continue
            planned.append((info,destination.joinpath(*PurePosixPath(name).parts)))
        # Validate all names before creating a single archive file.
        for info,target in planned:
            cursor=target
            while cursor!=destination.parent:
                if cursor.is_symlink() or (cursor.exists() and bool(getattr(cursor.stat(),'st_file_attributes',0)&0x400)): raise ValueError('linked_server_path')
                cursor=cursor.parent
            # Keep TS database, identity and user config on repeat installs.
            if target.exists() and target.suffix.lower() in ('.db','.sqlitedb','.ini','.dat'): continue
            target.parent.mkdir(parents=True,exist_ok=True)
            temporary=target.with_name(target.name+'.teamsync-partial')
            try:
                with source.open(info) as src, temporary.open('wb') as out: shutil.copyfileobj(src,out)
                temporary.replace(target)
            finally: temporary.unlink(missing_ok=True)

def steam_arguments(folder):
    return ['+force_install_dir', str(folder), '+login', 'anonymous', '+app_update', '730', 'validate', '+quit']

def install(kind, destination, cache, *, minimum_cs_bytes=100*1024**3, runner=subprocess.Popen):
    destination=owned_folder(destination,kind)
    if kind=='teamspeak':
        if shutil.disk_usage(destination).free < 250*1024*1024: raise ValueError('server_disk_space')
        archive=download('teamspeak',cache); emit('server_extract')
        (destination/'.teamsync-install.json').write_text(json.dumps({'kind':kind,'state':'pending'}))
        safe_extract(archive,destination,'teamspeak3-server_win64/')
        executable=destination/'ts3server.exe'
        if not executable.is_file() or executable.open('rb').read(2)!=b'MZ': raise ValueError('server_install_incomplete')
    elif kind=='cs2':
        # Existing Steam updates need less space than a full first installation.
        existing=(destination/'game/bin/win64/cs2.exe').is_file()
        required=10*1024**3 if existing else minimum_cs_bytes
        if shutil.disk_usage(destination).free<required: raise ValueError('server_disk_space')
        tools=owned_folder(destination.parent/'steamcmd','steamcmd')
        command=tools/'steamcmd.exe'
        if not command.is_file():
            archive=download('steamcmd',cache); safe_extract(archive,tools)
        emit('steamcmd',progress=None)
        (destination/'.teamsync-install.json').write_text(json.dumps({'kind':kind,'state':'pending'}))
        for attempt in range(4):
            process=runner([str(command),*steam_arguments(destination)],cwd=str(tools),stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace',creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            installed=False; updated=0; started=time.monotonic()
            try:
                for line in process.stdout:
                    if time.monotonic()-started>4*3600: raise ValueError('server_install_timeout')
                    if "Success! App '730'" in line: installed=True
                    if any(marker in line.lower() for marker in ['invalid platform','no subscription','not enough disk','error!','failed to install']):
                        emit('steamcmd_message',message=line.strip()[:250])
                    match=re.search(r'progress:\s*([\d.]+)',line)
                    if match and time.monotonic()-updated>.25:
                        emit('server_installing',progress=min(1,float(match[1])/100)); updated=time.monotonic()
                code=process.wait(timeout=60)
            finally:
                if process.poll() is None: process.kill(); process.wait(timeout=10)
            if code != 7: break
            emit('steamcmd',progress=None,restart=attempt+1)
            time.sleep(1)
        executable=destination/'game/bin/win64/cs2.exe'
        if code!=0 or not installed or not executable.is_file(): raise ValueError('steamcmd_failed')
    else: raise ValueError('invalid_server_kind')
    (destination/'.teamsync-install.json').write_text(json.dumps({'kind':kind,'state':'installed','updated':time.time(),'executable':str(executable)}))
    emit('server_complete',kind=kind,path=str(executable.resolve()))
    return executable

def main(argv=None):
    cli=argparse.ArgumentParser();cli.add_argument('--kind',choices=['cs2','teamspeak'],required=True);cli.add_argument('--destination',required=True);cli.add_argument('--cache',required=True);args=cli.parse_args(argv)
    try:
        from resource_limits import constrain
        constrain()  # includes killing only our child SteamCMD on cancellation
        install(args.kind,Path(args.destination),Path(args.cache)); return 0
    except Exception as error:
        emit('error',code=str(error) if isinstance(error,ValueError) else 'server_install_failed'); return 1

if __name__=='__main__':raise SystemExit(main())
