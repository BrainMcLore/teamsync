from pathlib import Path
from sqlalchemy import select, update, func
from test_api import setup
from test_discussion import prepare
from server.database import uid, documents, task_evidence, media, memberships

ROOT = Path(__file__).resolve().parents[2]
PNG = (ROOT/'client/test/fixtures/radar.png').read_bytes()
MP4 = (ROOT/'client/test/fixtures/own_clip.mp4').read_bytes()


def test_player_evidence_is_task_bound_private_and_retry_safe(setup):
    app, c, (owner, player, stranger) = setup
    base, document = prepare(c, owner, player)
    path = base+f'/documents/{document}/evidence'
    identifier = uid()
    upload = path+'/media/'+identifier
    assert c.put(upload, headers=player[1], content=PNG).status_code == 403
    with app.state.engine.begin() as conn:
        payload = dict(conn.execute(select(documents.c.payload).where(documents.c.id==document)).scalar_one())
        payload['assignee_user_id'] = player[0]
        conn.execute(update(documents).where(documents.c.id==document).values(payload=payload))
    proof = c.put(upload, headers=player[1], content=PNG)
    assert proof.status_code == 200, proof.text
    record = proof.json()
    assert record['author_id'] == player[0] and record['mime']=='image/png'
    assert record['task_version'] == 1
    assert c.put(upload, headers=player[1], content=PNG).json() == record
    assert c.put(upload, headers=player[1], content=MP4).status_code == 409
    assert c.put(upload, headers=owner[1], content=PNG).status_code == 409
    assert c.get(upload, headers=owner[1]).content == PNG
    assert c.get(upload, headers=stranger[1]).status_code == 404
    assert c.get(path, headers=stranger[1]).status_code == 404
    assert c.put(path+'/media/'+uid(), headers=stranger[1], content=PNG).status_code == 404
    other_doc = uid()
    assert c.get(base+f'/documents/{other_doc}/evidence/media/{identifier}',headers=owner[1]).status_code==404
    assert c.put(path+'/media/'+uid(),headers=player[1],content=b'\x89PNG\r\n\x1a\n').status_code==422
    assert c.put(path+'/media/'+uid(),headers=player[1],content=PNG[:-1]).status_code==422
    assert c.put(path+'/media/'+uid(),headers=player[1],content=MP4[:-1]).status_code==422
    assert c.put(path+'/media/'+uid(),headers=owner[1],content=b'x'*(20*1024*1024+1)).status_code==413
    # Once approved: existing receipt still retries, but no new evidence may appear.
    with app.state.engine.begin() as conn:
        conn.execute(update(documents).where(documents.c.id==document).values(payload={**payload,'status':'approved'}))
    assert c.put(upload,headers=player[1],content=PNG).json()==record
    assert c.put(path+'/media/'+uid(),headers=owner[1],content=PNG).status_code==409
    with app.state.engine.begin() as conn:
        assert conn.execute(select(func.count()).select_from(task_evidence)).scalar_one()==1
        assert conn.execute(select(func.count()).select_from(media)).scalar_one()==1
        conn.execute(update(memberships).where(memberships.c.user_id==player[0]).values(role='viewer'))
        conn.execute(update(documents).where(documents.c.id==document).values(payload=payload))
    assert c.put(path+'/media/'+uid(),headers=player[1],content=PNG).status_code==403
    assert c.get(upload,headers=player[1]).status_code==200
    c.delete(base+'/members/'+player[0],headers=owner[1])
    assert c.get(upload,headers=player[1]).status_code==404


def test_quota_failure_does_not_create_an_orphan_receipt_and_mp4_is_supported(setup):
    app,c,(owner,player,_)=setup
    base,document=prepare(c,owner,player)
    path=base+f'/documents/{document}/evidence'
    clip=c.put(path+'/media/'+uid(),headers=owner[1],content=MP4)
    assert clip.status_code==200
    assert clip.json()['mime']=='video/mp4'
    # Use a synthetic quota row without allocating a 100 MiB test blob.
    with app.state.engine.begin() as conn:
        conn.execute(media.insert().values(id='f'*64,team_id=base.split('/')[-1],content=b'x',mime='image/png',size=100*1024*1024))
    failed=uid()
    assert c.put(path+'/media/'+failed,headers=owner[1],content=PNG).status_code==413
    with app.state.engine.connect() as conn:
        assert not conn.execute(select(task_evidence).where(task_evidence.c.id==failed)).first()
    assert c.get(path+'?limit=1',headers=player[1]).json()['items'][0]['id']==clip.json()['id']
    assert c.get(path+'?before='+uid(),headers=player[1]).status_code==404


def test_image_containers_reject_corruption_and_oversized_dimensions():
    import struct
    import zlib
    from server.media_types import valid_evidence_image
    jpeg = (ROOT/'client/test/fixtures/evidence.jpg').read_bytes()
    assert valid_evidence_image(jpeg)
    assert not valid_evidence_image(jpeg[:-1])
    assert valid_evidence_image(PNG)
    corrupt = bytearray(PNG)
    corrupt[-1] ^= 1
    assert not valid_evidence_image(bytes(corrupt))
    large = bytearray(PNG)
    struct.pack_into('>I', large, 16, 8193)
    struct.pack_into('>I', large, 29, zlib.crc32(large[12:29]))
    assert not valid_evidence_image(bytes(large))
