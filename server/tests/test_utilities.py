from test_api import setup
from server.database import uid


def test_team_utility_sources_and_foreign_map_are_validated(setup):
    _, client, (owner, player, stranger) = setup
    team = client.post('/api/v1/teams', headers=owner[1], json={'name': 'Utilities'}).json()['id']
    base = f'/api/v1/teams/{team}'
    mapid = uid()
    mapbody = {'document_id': mapid, 'operation_id': uid(), 'expected_version': 0,
               'kind': 'map', 'payload': {'title': 'Mirage'}}
    assert client.post(base+'/documents', headers=owner[1], json=mapbody).status_code == 200
    utility = {'document_id': uid(), 'operation_id': uid(), 'expected_version': 0,
               'kind': 'utility', 'payload': {'title': 'Окно', 'map_id': mapid, 'side': 'T',
               'notes': '  Прицелиться\nJumpthrow', 'utility': {'grenade': 'smoke',
               'source_url': 'https://youtu.be/abc123?t=42', 'author': 'Original author'}}}
    assert client.post(base+'/documents', headers=owner[1], json=utility).status_code == 200
    bad = {**utility, 'document_id': uid(), 'operation_id': uid(), 'payload': {
        **utility['payload'], 'utility': {'grenade': 'smoke', 'source_url': 'https://youtube.com@127.0.0.1/private'}}}
    assert client.post(base+'/documents', headers=owner[1], json=bad).status_code == 422
    missing = {**utility, 'document_id': uid(), 'operation_id': uid(), 'payload': {
        **utility['payload'], 'map_id': uid()}}
    assert client.post(base+'/documents', headers=owner[1], json=missing).status_code == 422
    missing_tactic = {**utility, 'document_id': uid(), 'operation_id': uid(), 'payload': {
        **utility['payload'], 'utility': {**utility['payload']['utility'], 'strategy_ids': [uid()]}}}
    assert client.post(base+'/documents', headers=owner[1], json=missing_tactic).status_code == 422
    missing_image = {**utility, 'document_id': uid(), 'operation_id': uid(), 'payload': {
        **utility['payload'], 'utility': {**utility['payload']['utility'], 'image_ids': ['0'*64]}}}
    assert client.post(base+'/documents', headers=owner[1], json=missing_image).status_code == 422
    from pathlib import Path
    import hashlib
    image = (Path(__file__).resolve().parents[2]/'client/test/fixtures/radar.png').read_bytes()
    image_id = hashlib.sha256(image).hexdigest()
    assert client.put(base+'/media/'+image_id, headers=owner[1], content=image).status_code == 200
    with_image = {**missing_image, 'operation_id': uid(), 'payload': {
        **utility['payload'], 'utility': {**utility['payload']['utility'], 'image_ids': [image_id]}}}
    assert client.post(base+'/documents', headers=owner[1], json=with_image).status_code == 200


    assert client.get(base+'/documents', headers=stranger[1]).status_code == 404
    invite = client.post(base+'/invites', headers=owner[1], json={}).json()['code']
    client.post('/api/v1/invites/join', headers=player[1], json={'code': invite})
    assert client.get(base+'/documents', headers=player[1]).status_code == 200
    assert client.post(base+'/documents', headers=player[1], json={**utility, 'operation_id': uid(), 'expected_version': 1}).status_code == 403


def test_new_optional_utility_field_preserves_pre_upgrade_idempotency_hash(setup):
    import hashlib
    import json
    from sqlalchemy import select, update
    from server.database import operations
    app, client, (owner, _, _) = setup
    team = client.post('/api/v1/teams', headers=owner[1], json={'name': 'Legacy'}).json()['id']
    old_payload = {'title': 'Mirage', 'notes': 'План 😎', 'map_id': None, 'strategy_id': None,
                   'assignee_user_id': None, 'side': None, 'status': 'todo', 'objects': [],
                   'catalog_id': None, 'level': 'default', 'image_id': None, 'lower_image_id': None}
    body = {'operation_id': uid(), 'document_id': uid(), 'expected_version': 0,
            'kind': 'map', 'payload': old_payload}
    assert client.post(f'/api/v1/teams/{team}/documents', headers=owner[1], json=body).status_code == 200
    legacy_hash = hashlib.sha256(json.dumps(body, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()
    with app.state.engine.connect() as conn:
        actual = conn.execute(select(operations.c.request_hash).where(operations.c.id == body['operation_id'])).scalar_one()
    assert actual.startswith('v2:')
    with app.state.engine.begin() as conn:
        conn.execute(update(operations).where(operations.c.id == body['operation_id']).values(request_hash=legacy_hash))
    replay = client.post(f'/api/v1/teams/{team}/documents', headers=owner[1], json=body)
    assert replay.status_code == 200
    assert replay.json()['version'] == 1
