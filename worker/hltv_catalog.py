"""On-demand public HLTV results/match reader. No accounts, browser cookies,
proxies, CAPTCHA solvers or background crawling. Cache and stop on rate limits.
"""
import argparse
from contextlib import closing
from datetime import datetime, timezone
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
import time
from urllib.parse import urlsplit, urljoin

from curl_cffi import requests, CurlOpt

ORIGIN = 'https://www.hltv.org'
MAX_HTML = 4 * 1024 * 1024
_session = None

class CatalogError(Exception): pass

class Node:
    def __init__(self, tag='', attrs=(), parent=None):
        self.tag, self.attrs, self.parent, self.children = tag, dict(attrs), parent, []
    def all(self, cls=None, tag=None):
        result = []
        for child in self.children:
            if not isinstance(child, Node): continue
            if (cls is None or cls in child.attrs.get('class', '').split()) and (tag is None or child.tag == tag): result.append(child)
            result.extend(child.all(cls, tag))
        return result
    def first(self, cls=None, tag=None): return next(iter(self.all(cls, tag)), None)
    def text(self): return ' '.join(''.join(c.text() if isinstance(c, Node) else c for c in self.children).split())[:500]

class Dom(HTMLParser):
    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.root = Node(); self.current = self.root; self.feed(source)
    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.current); self.current.children.append(node)
        if tag not in {'area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr'}: self.current = node
    def handle_startendtag(self, tag, attrs): self.current.children.append(Node(tag, attrs, self.current))
    def handle_endtag(self, tag):
        node = self.current
        while node.parent is not None:
            if node.tag == tag: self.current = node.parent; return
            node = node.parent
    def handle_data(self, data): self.current.children.append(data)

def match_url(value):
    url = urlsplit(urljoin(ORIGIN, value))
    if url.scheme != 'https' or url.hostname not in ('hltv.org','www.hltv.org') or url.username or url.port not in (None,443) or not re.fullmatch(r'/matches/\d+/[a-zA-Z0-9-]+/?', url.path): raise CatalogError('invalid_match_url')
    return ORIGIN + url.path

def parse_results(source):
    root = Dom(source).root; result = []; seen = set()
    for row in root.all('result-con'):
        link = row.first(tag='a'); teams = row.all('team'); event = row.first('event-name')
        if not link or len(teams) < 2 or not event: continue
        try: url = match_url(link.attrs.get('href',''))
        except CatalogError: continue
        mid = re.search(r'/matches/(\d+)',url)[1]
        if mid in seen: continue
        seen.add(mid)
        parent = row.parent
        while parent and 'results-sublist' not in parent.attrs.get('class','').split(): parent = parent.parent
        headline = parent.first('standard-headline') if parent else None
        stars = row.first('stars'); score = row.first('result-score'); fmt = row.first('map-text')
        result.append({'id':mid, 'url':url, 'teams':[t.text()[:120] for t in teams[:2]], 'event':event.text()[:250],
            'score':score.text() if score else '', 'format':fmt.text() if fmt else '',
            'stars':len(stars.all('star')) if stars else 0, 'date':headline.text() if headline else '',
            'demo_status':'unchecked'})
    # Featured cards precede dated duplicates; use their real row timestamp.
    for row in root.all('result-con'):
        stamp = row.attrs.get('data-zonedgrouping-entry-unix')
        link = row.first(tag='a')
        if stamp and stamp.isdigit() and link:
            for item in result:
                if item['url'] == urljoin(ORIGIN,link.attrs.get('href','')):
                    item['date'] = datetime.fromtimestamp(int(stamp)/1000,timezone.utc).isoformat()
    if not result: raise CatalogError('catalog_layout_changed')
    return result[:100]

def parse_match(source, url):
    root = Dom(source).root; demos = []
    for node in root.all(tag='a'):
        path = node.attrs.get('data-demo-link') or node.attrs.get('href','')
        if re.fullmatch(r'/download/demo/\d+', path): demos.append(ORIGIN + path)
    teams = [n.text()[:120] for n in root.all('teamName')[:2]]
    if len(teams) != 2: raise CatalogError('catalog_layout_changed')
    event_root = root.first('timeAndEvent'); event = event_root.first('event') if event_root else None
    maps = list(dict.fromkeys(n.text() for n in root.all('mapname')))
    players = list(dict.fromkeys(n.text() for n in root.all('player-nick')))
    return {'url':match_url(url), 'demo_urls':list(dict.fromkeys(demos))[:10], 'teams':teams, 'event':event.text() if event else '', 'maps':maps, 'players':players[:20]}

def response(url, *, stream=True):
    # Pin validated public DNS for every hop; libcurl still verifies TLS hostname.
    from demo_worker import public_address
    parts = urlsplit(url)
    if parts.scheme != 'https' or parts.port not in (None,443) or parts.username or parts.password: raise CatalogError('unsafe_download_url')
    address = public_address(parts.hostname)[4][0]
    resolve = f'{parts.hostname}:443:{"["+address+"]" if ":" in address else address}'
    global _session
    if _session is None: _session = requests.Session(impersonate='chrome')
    _session.curl_options[CurlOpt.RESOLVE] = [resolve]
    return _session.get(url, allow_redirects=False, stream=stream, timeout=30,
        headers={'Accept-Language':'en-US,en;q=0.8','Referer':ORIGIN+'/'})

def html_http(url, cache):
    cooldown = cache / 'cooldown.json'
    if cooldown.exists():
        try:
            if json.loads(cooldown.read_text())['until'] > time.time(): raise CatalogError('hltv_rate_limited')
        except (ValueError, KeyError): pass
    for _ in range(4):
        with closing(response(url)) as result:
            if result.status_code in (301,302,303,307,308):
                target = urljoin(url, result.headers.get('location',''))
                if urlsplit(target).hostname not in ('www.hltv.org','hltv.org'): raise CatalogError('hltv_redirect')
                url = target; continue
            if result.status_code == 429:
                cooldown.write_text(json.dumps({'until':time.time()+max(300,min(3600,int(result.headers.get('retry-after','300')) if result.headers.get('retry-after','300').isdigit() else 300))}))
                raise CatalogError('hltv_rate_limited')
            if result.status_code != 200: raise CatalogError('source_blocked')
            chunks = []; size = 0
            for chunk in result.iter_content():
                size += len(chunk)
                if size > MAX_HTML: raise CatalogError('catalog_size')
                chunks.append(chunk)
            text = b''.join(chunks).decode('utf-8', errors='replace')
            if 'cf-chl-' in text or '<title>Just a moment' in text: raise CatalogError('source_blocked')
            return text
    raise CatalogError('hltv_redirect')

def managed_html(url, cache):
    import os, subprocess, sys, uuid
    executable = Path(sys.executable).parent/'teamsync-download.exe' if getattr(sys, 'frozen', False) else Path(__file__).resolve().parents[1]/'.tools/native-download/teamsync-download.exe'
    if os.name != 'nt' or not executable.exists(): raise CatalogError('managed_downloader_missing')
    target = cache / ('page-' + uuid.uuid4().hex + '.json')
    # Same isolated HLTV session for catalog, match and archive downloads.
    profile = cache.parent / 'hltv-source-session'
    process = subprocess.Popen([str(executable), '--html', '--url', url,
        '--output', str(target.resolve()), '--profile', str(profile.resolve()),
        '--window-title', 'TeamSync — HLTV', '--window-message', 'HLTV'],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, encoding='utf-8',
        creationflags=subprocess.CREATE_NO_WINDOW)
    complete = False; code = 'source_blocked'
    try:
        for line in process.stdout:
            try:
                event = json.loads(line)
                if event.get('phase') == 'html_complete': complete = True
                elif event.get('phase') == 'error': code = event.get('code', code)
                else: print(json.dumps(event), flush=True)
            except (ValueError, TypeError): pass
        if process.wait(timeout=10) != 0 or not complete: raise CatalogError(code)
        if target.stat().st_size > MAX_HTML * 2: raise CatalogError('catalog_size')
        source = json.loads(target.read_text(encoding='utf-8'))
        if not isinstance(source, str) or len(source.encode('utf-8')) > MAX_HTML: raise CatalogError('catalog_size')
        return source
    finally:
        if process.poll() is None: process.kill(); process.wait(timeout=10)
        target.unlink(missing_ok=True)

def html(url, cache):
    try: return html_http(url, cache)
    except CatalogError as error:
        if str(error) != 'source_blocked': raise
        return managed_html(url, cache)

def download_demo_http(url, target, limit):
    from demo_worker import emit, ImportFailure
    for _ in range(7):
        with closing(response(url)) as result:
            if result.status_code in (301,302,303,307,308): url = urljoin(url,result.headers.get('location','')); continue
            if result.status_code in (401,403,429,503) or 'text/html' in result.headers.get('content-type',''): raise ImportFailure('source_blocked')
            if result.status_code != 200: raise ImportFailure('download_failed')
            expected = int(result.headers.get('content-length','0') or 0)
            if expected > limit or shutil.disk_usage(target.parent).free < max(expected,512*1024*1024)+256*1024*1024: raise ImportFailure('file_too_large')
            size = 0; started = time.monotonic(); updated = 0
            with target.open('wb') as out:
                for chunk in result.iter_content(chunk_size=256*1024):
                    size += len(chunk)
                    if size > limit: raise ImportFailure('file_too_large')
                    out.write(chunk)
                    elapsed = time.monotonic()-started
                    if elapsed-updated >= .2:
                        emit('downloading',size/expected if expected else None,bytes=size,speed=size/max(elapsed,.01)); updated=elapsed
            if expected and size != expected: raise ImportFailure('download_failed')
            return target
    raise ImportFailure('download_failed')

def managed_download(url, target, limit):
    import os, sys, subprocess
    from demo_worker import emit, ImportFailure
    executable=Path(sys.executable).parent/'teamsync-download.exe' if getattr(sys,'frozen',False) else Path(__file__).resolve().parents[1]/'.tools/native-download/teamsync-download.exe'
    if os.name!='nt' or not executable.exists(): raise ImportFailure('managed_downloader_missing')
    profile=target.parent.parent.parent/'hltv-source-session'
    labels_path=executable.parent/'download-labels.json'
    if not labels_path.exists(): labels_path=Path(__file__).resolve().parents[1]/'native/download/labels.json'
    labels=json.loads(labels_path.read_text(encoding='utf-8')).get(os.environ.get('TEAMSYNC_LANGUAGE','ru'),{})
    process=subprocess.Popen([str(executable),'--url',url,'--output',str(target.resolve()),'--profile',str(profile.resolve()),'--window-title',labels.get('title','TeamSync'),'--window-message',labels.get('message','')],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,encoding='utf-8',creationflags=subprocess.CREATE_NO_WINDOW)
    complete=False; code='native_download_failed'
    try:
        for line in process.stdout:
            try:
                event=json.loads(line)
                if event.get('phase')=='network_complete': complete=True
                elif event.get('phase')=='error': code=event.get('code','native_download_failed')
                else: print(json.dumps(event),flush=True)
            except (ValueError,TypeError): pass
        result=process.wait(timeout=10)
    finally:
        if process.poll() is None: process.kill(); process.wait(timeout=10)
    if result!=0 or not complete or not target.is_file(): raise ImportFailure(code)
    if target.stat().st_size>limit: raise ImportFailure('file_too_large')
    return target

def download_demo(url,target,limit):
    from demo_worker import ImportFailure
    try: return download_demo_http(url,target,limit)
    except ImportFailure as error:
        if str(error)!='source_blocked': raise
        return managed_download(url,target,limit)

def main(argv=None):
    parser = argparse.ArgumentParser(); parser.add_argument('--cache',required=True); parser.add_argument('--offset',type=int,default=0); parser.add_argument('--match'); parser.add_argument('--force',action='store_true'); args=parser.parse_args(argv)
    cache = Path(args.cache); cache.mkdir(parents=True,exist_ok=True)
    try:
        if args.match:
            url = match_url(args.match); name='match-'+re.search(r'/matches/(\d+)',url)[1]; ttl=900
        else:
            if args.offset < 0 or args.offset > 10000 or args.offset % 100: raise CatalogError('invalid_catalog_page')
            url=ORIGIN+'/results'+(f'?offset={args.offset}' if args.offset else ''); name='results-'+str(args.offset); ttl=900
        file=cache/(name+'.json')
        if not args.force and file.exists() and time.time()-file.stat().st_mtime < ttl: payload=json.loads(file.read_text(encoding='utf-8'))
        else:
            source=html(url,cache)
            payload=parse_match(source,url) if args.match else {'items':parse_results(source),'offset':args.offset,'next_offset':args.offset+100}
            payload['fetched_at']=datetime.now(timezone.utc).isoformat(); payload['source']=url
            file.write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
        print(json.dumps({'phase':'catalog_complete','data':payload},ensure_ascii=True),flush=True); return 0
    except Exception as error:
        print(json.dumps({'phase':'error','code':str(error) if isinstance(error,CatalogError) else 'catalog_failed'}),flush=True); return 1

if __name__=='__main__': raise SystemExit(main())
