import hashlib
import io
import json
from pathlib import Path
import zipfile

import pytest

import hltv_catalog as catalog
import server_installer as setup

def test_result_parser_deduplicates_matches_and_does_not_invent_tiers():
    card='''<div class="result-con"><a href="/matches/123/team-a-vs-team-b"><div class="team">Team A</div><div class="team">Team B</div><span class="event-name">Actual tournament</span><div class="stars"><i class="star"></i><i class="star"></i></div><td class="result-score">2 - 1</td><div class="map-text">bo3</div></a></div>'''
    result=catalog.parse_results(card+card)
    assert len(result)==1 and result[0]['teams']==['Team A','Team B']
    assert result[0]['stars']==2 and result[0]['demo_status']=='unchecked' and 'tier' not in result[0]

def test_match_reader_supports_data_demo_link_and_rejects_external_links():
    source='''<div class="teamName">A</div><div class="teamName">B</div><div class="mapname">Cache</div><span class="player-nick">Entry</span><a data-demo-link="/download/demo/42"></a><a data-demo-link="https://private.invalid/file"></a>'''
    value=catalog.parse_match(source,'https://www.hltv.org/matches/123/a-vs-b')
    assert value['demo_urls']==['https://www.hltv.org/download/demo/42']
    assert value['players']==['Entry'] and value['maps']==['Cache']
    for url in ['https://evil.invalid/matches/123/a','http://www.hltv.org/matches/123/a','https://user@www.hltv.org/matches/123/a']:
        with pytest.raises(catalog.CatalogError): catalog.match_url(url)

def test_cooldown_is_respected_without_a_network_request(tmp_path,monkeypatch):
    (tmp_path/'cooldown.json').write_text(json.dumps({'until':9999999999}))
    monkeypatch.setattr(catalog,'response',lambda *_:pytest.fail('rate limited host must not be queried'))
    with pytest.raises(catalog.CatalogError,match='hltv_rate_limited'):catalog.html(catalog.ORIGIN+'/results',tmp_path)

@pytest.mark.parametrize('bad',['../escape','/absolute','folder/../../escape',r'folder\evil','folder/ads:payload'])
def test_server_zip_validation_happens_before_any_write(tmp_path,bad):
    archive=tmp_path/'payload.zip';destination=tmp_path/'target';destination.mkdir()
    with zipfile.ZipFile(archive,'w') as z:
        z.writestr('legit.txt','ok')
        info=zipfile.ZipInfo();info.filename=bad;z.writestr(info,'bad')
    with pytest.raises(ValueError):setup.safe_extract(archive,destination)
    assert list(destination.iterdir())==[]

def test_server_setup_refuses_non_owned_folder_and_preserves_database(tmp_path):
    target=tmp_path/'TeamSyncServers'/'teamspeak';target.mkdir(parents=True);(target/'personal.txt').write_text('keep')
    with pytest.raises(ValueError,match='server_folder_not_owned'):setup.owned_folder(target,'teamspeak')
    assert (target/'personal.txt').read_text()=='keep'
    (target/'.teamsync-install.json').write_text(json.dumps({'kind':'teamspeak'}))
    assert setup.owned_folder(target,'teamspeak')==target
    archive=tmp_path/'ts.zip'
    with zipfile.ZipFile(archive,'w') as z:z.writestr('teamspeak3-server_win64/ts3server.sqlitedb','new');z.writestr('teamspeak3-server_win64/ts3server.exe','MZfixture')
    (target/'ts3server.sqlitedb').write_text('personal database')
    setup.safe_extract(archive,target,'teamspeak3-server_win64/')
    assert (target/'ts3server.sqlitedb').read_text()=='personal database'
    assert not (target/'.ts3server_license_accepted').exists()

def test_cs2_uses_only_anonymous_valve_730_arguments_and_checks_success(tmp_path,monkeypatch):
    target=tmp_path/'TeamSyncServers'/'cs2';cache=tmp_path/'cache';cache.mkdir()
    archive=cache/'steamcmd.zip'
    with zipfile.ZipFile(archive,'w') as z:z.writestr('steamcmd.exe','MZfixture')
    monkeypatch.setattr(setup,'download',lambda name,folder:archive)
    calls=[]
    class Process:
        stdout=io.StringIO("Update state downloading, progress: 50.00\nSuccess! App '730' fully installed.\n")
        def wait(self,timeout=None):return 0
        def poll(self):return 0
    def runner(args,**kwargs):
        calls.append(args);(target/'game/bin/win64').mkdir(parents=True);(target/'game/bin/win64/cs2.exe').write_bytes(b'MZfixture');return Process()
    result=setup.install('cs2',target,cache,minimum_cs_bytes=0,runner=runner)
    assert result.is_file() and calls[0][1:]==setup.steam_arguments(target)
    assert 'anonymous' in calls[0] and '730' in calls[0] and '740' not in calls[0]
    assert json.loads((target/'.teamsync-install.json').read_text())['state']=='installed'

def test_steamcmd_self_update_exit_7_restarts_without_dropping_install_arguments(tmp_path,monkeypatch):
    target=tmp_path/'TeamSyncServers'/'cs2';cache=tmp_path/'cache';cache.mkdir()
    archive=cache/'steamcmd.zip'
    with zipfile.ZipFile(archive,'w') as z:z.writestr('steamcmd.exe','MZfixture')
    monkeypatch.setattr(setup,'download',lambda *_:archive)
    calls=[]
    class Process:
        def __init__(self,code):
            self.code=code
            self.stdout=io.StringIO('Update complete, launching Steamcmd...\n' if code==7 else "Success! App '730' fully installed.\n")
        def wait(self,timeout=None):return self.code
        def poll(self):return self.code
    def runner(args,**kwargs):
        calls.append(args)
        if len(calls)==1:return Process(7)
        (target/'game/bin/win64').mkdir(parents=True);(target/'game/bin/win64/cs2.exe').write_bytes(b'MZfixture')
        return Process(0)
    assert setup.install('cs2',target,cache,minimum_cs_bytes=0,runner=runner).is_file()
    assert len(calls)==2 and calls[0]==calls[1]
