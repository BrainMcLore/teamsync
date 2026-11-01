import hashlib
from pathlib import Path
from test_api import setup
from server.database import uid

def test_shared_map_media_and_tactic_levels_are_authorized_and_versioned(setup):
    _,c,(owner,player,stranger)=setup
    team=c.post('/api/v1/teams',headers=owner[1],json={'name':'Shared tactics'}).json()['id']
    base=f'/api/v1/teams/{team}'
    invitation=c.post(base+'/invites',headers=owner[1],json={}).json()['code']
    c.post('/api/v1/invites/join',headers=player[1],json={'code':invitation})
    image=(Path(__file__).resolve().parents[2]/'client/test/fixtures/radar.png').read_bytes()
    digest=hashlib.sha256(image).hexdigest()
    assert c.put(base+'/media/'+digest,headers=player[1],content=image).status_code==403
    assert c.put(base+'/media/'+digest,headers=owner[1],content=image).status_code==200
    assert c.put(base+'/media/'+digest,headers=owner[1],content=image).status_code==200
    assert c.get(base+'/media/'+digest,headers=player[1]).content==image
    assert c.get(base+'/media/'+digest,headers=stranger[1]).status_code==404
    assert c.put(base+'/media/'+digest,headers=owner[1],content=b'wrong').status_code==422
    mapid=uid()
    body={'operation_id':uid(),'document_id':mapid,'expected_version':0,'kind':'map','payload':{'title':'Custom map','image_id':digest}}
    assert c.post(base+'/documents',headers=owner[1],json=body).status_code==200
    tactic={'operation_id':uid(),'document_id':uid(),'expected_version':0,'kind':'strategy','payload':{'title':'CT lower hold','map_id':mapid,'side':'CT','level':'lower','notes':'  Hold ramp\n\n','objects':[{'type':'ct','x':.5,'y':.4}]}}
    assert c.post(base+'/documents',headers=owner[1],json=tactic).status_code==200
    shared=c.get(base+'/documents',headers=player[1]).json()['items']
    assert next(d for d in shared if d['kind']=='strategy')['payload']['level']=='lower'
    assert next(d for d in shared if d['kind']=='strategy')['payload']['notes']=='  Hold ramp\n\n'
    assert c.post(base+'/documents',headers=player[1],json={**tactic,'operation_id':uid(),'expected_version':1}).status_code==403
    assert c.post(base+'/documents',headers=owner[1],json={**tactic,'operation_id':uid()}).status_code==409
