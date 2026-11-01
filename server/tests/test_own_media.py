from pathlib import Path
import hashlib

from test_api import setup
from server.database import uid
from server.media_types import valid_mp4

CLIP = Path(__file__).resolve().parents[2]/'client/test/fixtures/own_clip.mp4'


def test_mp4_requires_a_bounded_movie_with_an_actual_video_track():
    data = CLIP.read_bytes()
    assert valid_mp4(data)
    assert not valid_mp4(data[:-1])
    assert not valid_mp4(b'\0\0\0\1ftyp'+b'\xff'*24)
    assert not valid_mp4(data.replace(b'vide',b'soun',1))


def test_own_clip_is_private_and_cannot_be_used_as_a_radar(setup):
    _, client, (owner, player, stranger) = setup
    team=client.post('/api/v1/teams', headers=owner[1], json={'name':'Own clips'}).json()['id']
    base=f'/api/v1/teams/{team}'
    data=CLIP.read_bytes()
    identifier=hashlib.sha256(data).hexdigest()
    assert client.put(base+'/media/'+identifier, headers=owner[1], content=data).status_code == 200
    assert client.get(base+'/media/'+identifier, headers=stranger[1]).status_code == 404
    code=client.post(base+'/invites', headers=owner[1], json={}).json()['code']
    client.post('/api/v1/invites/join', headers=player[1], json={'code':code})
    received=client.get(base+'/media/'+identifier, headers=player[1])
    assert received.content==data
    assert received.headers['content-type']=='video/mp4'
    assert client.put(base+'/media/'+identifier, headers=player[1], content=data).status_code==403
    body={'operation_id':uid(),'document_id':uid(),'expected_version':0,'kind':'map',
          'payload':{'title':'Wrong radar','image_id':identifier}}
    assert client.post(base+'/documents', headers=owner[1], json=body).status_code==422
    body['payload']={'title':'Mirage'}
    assert client.post(base+'/documents', headers=owner[1], json=body).status_code==200
    utility={'operation_id':uid(),'document_id':uid(),'expected_version':0,'kind':'utility',
             'payload':{'title':'Own clip','map_id':body['document_id'],'side':'T',
                        'utility':{'grenade':'smoke','video_id':identifier}}}
    assert client.post(base+'/documents', headers=owner[1], json=utility).status_code==200

    legacy_edit={**utility,'operation_id':uid(),'expected_version':1,'payload':{
        **utility['payload'],'notes':'Revised by older client','utility':{'grenade':'smoke'}}}
    assert client.post(base+'/documents',headers=owner[1],json=legacy_edit).status_code==200
    rows=client.get(base+'/documents',headers=player[1]).json()['items']
    assert next(r for r in rows if r['kind']=='utility')['payload']['utility']['video_id']==identifier
    changed_presence={**legacy_edit,'payload':{**legacy_edit['payload'],'utility':{'grenade':'smoke','video_id':None}}}
    assert client.post(base+'/documents',headers=owner[1],json=changed_presence).status_code==409
    removal={**changed_presence,'operation_id':uid(),'expected_version':2}
    assert client.post(base+'/documents',headers=owner[1],json=removal).status_code==200
    rows=client.get(base+'/documents',headers=player[1]).json()['items']
    assert next(r for r in rows if r['kind']=='utility')['payload']['utility']['video_id'] is None
