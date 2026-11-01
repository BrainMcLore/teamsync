"""Pin and vendor real Valve radar assets and overview calibration metadata."""
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen
from concurrent.futures import ThreadPoolExecutor

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'client/assets/maps'
KEYS=['de_mirage','de_dust2','de_inferno','de_nuke','de_ancient','de_anubis','de_train','de_overpass','de_vertigo','de_cache']
def get(url):
    with urlopen(Request(url,headers={'User-Agent':'TeamSync-build/0.2'}),timeout=40) as response:
        return response.read()

def main():
    commit=json.loads(get('https://api.github.com/repos/MurkyYT/cs2-map-icons/commits/main'))['sha']
    base=f'https://raw.githubusercontent.com/MurkyYT/cs2-map-icons/{commit}/'
    available=json.loads(get(base+'data/available.json'))['maps']
    DEST.mkdir(parents=True,exist_ok=True)
    manifest={'revision':commit,'source':'https://github.com/MurkyYT/cs2-map-icons','copyright':'Map graphics and overview data © Valve Corporation. Not affiliated with Valve.','maps':[]}
    jobs=[]
    for key in KEYS:
        source=available[key]
        radars=source.get('radar_paths',[])
        default=next(p for p in radars if '_lower_' not in p)
        paths=[default,*[p for p in radars if '_lower_' in p]]
        item={'key':key,'name':source['display_name'],'calibration':source['radar_info'],'levels':[]}
        for path in paths:
            filename=path.rsplit('/',1)[-1]
            item['levels'].append({'key':'lower' if '_lower_' in path else 'default','asset':'assets/maps/'+filename})
            jobs.append((base+'images/radars/'+filename,filename))
        if source.get('thumb_paths'):
            filename=source['thumb_paths'][0].rsplit('/',1)[-1]
            item['thumbnail']='assets/maps/'+filename
            jobs.append((base+'images/thumbs/'+filename,filename))
        manifest['maps'].append(item)
    def download(job):
        url,name=job;data=get(url);(DEST/name).write_bytes(data)
        return name,hashlib.sha256(data).hexdigest()
    with ThreadPoolExecutor(max_workers=6) as pool:
        manifest['sha256']=dict(pool.map(download,jobs))
    (DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (DEST/'ATTRIBUTION.txt').write_text(manifest['copyright']+'\n'+manifest['source']+'\nRevision: '+commit,encoding='utf-8')
    print('Map pack:',len(manifest['maps']),'maps,',len(jobs),'images, revision',commit)

if __name__=='__main__':main()
