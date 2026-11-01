from test_api import setup
from server.database import uid, task_comments
from sqlalchemy import update


def prepare(client, owner, player):
    team = client.post('/api/v1/teams', headers=owner[1], json={'name': 'Training'}).json()['id']
    base = f'/api/v1/teams/{team}'
    code = client.post(base+'/invites', headers=owner[1], json={'role': 'player'}).json()['code']
    client.post('/api/v1/invites/join', headers=player[1], json={'code': code})
    document = uid()
    assert client.post(base+'/documents', headers=owner[1], json={
        'operation_id': uid(), 'document_id': document, 'expected_version': 0,
        'kind': 'task', 'payload': {'title': 'Practice'}}).status_code == 200
    return base, document


def test_discussion_roles_idempotency_and_task_isolation(setup):
    app, c, (owner, player, stranger) = setup
    base, document = prepare(c, owner, player)
    path = base+f'/documents/{document}/comments'
    payload = {'id': uid(), 'text': '  Проверить тайминг  '}
    first = c.post(path, headers=player[1], json=payload)
    assert first.status_code == 200
    row = first.json()
    assert row['author_id'] == player[0] and row['author_name'] == 'Player'
    assert row['text'] == 'Проверить тайминг'
    assert c.post(path, headers=player[1], json=payload).json() == row
    assert c.post(path, headers=owner[1], json=payload).status_code == 409
    assert c.post(path, headers=player[1], json={**payload,'text':'Changed'}).status_code == 409
    for method in ['get', 'post']:
        kwargs = {'json': payload} if method == 'post' else {}
        assert getattr(c, method)(path, headers=stranger[1], **kwargs).status_code == 404
    assert len(c.get(path, headers=owner[1]).json()['items']) == 1
    for text in [' ', 'x'*5001]:
        assert c.post(path, headers=player[1], json={'id':uid(),'text':text}).status_code == 422
    assert c.post(path, headers=player[1], json={**payload,'author_id':owner[0]}).status_code == 422
    # Non-task documents and foreign cursor IDs cannot be used as a discussion.
    assert c.get(base+f'/documents/{uid()}/comments', headers=owner[1]).status_code == 404
    assert c.get(path+'?before='+uid(), headers=owner[1]).status_code == 404
    assert c.get(path+'?limit=101', headers=owner[1]).status_code == 422
    team = base.rsplit('/', 1)[-1]
    from server.database import memberships
    with app.state.engine.begin() as conn:
        conn.execute(update(memberships).where(memberships.c.team_id==team,
            memberships.c.user_id==player[0]).values(role='viewer'))
    assert c.get(path, headers=player[1]).status_code == 200
    assert c.post(path, headers=player[1], json={'id':uid(),'text':'No'}).status_code == 403
    c.delete(base+'/members/'+player[0], headers=owner[1])
    assert c.get(path, headers=player[1]).status_code == 404


def test_cursor_remains_stable_when_new_comments_arrive(setup):
    app, c, (owner, player, _) = setup
    base, doc = prepare(c, owner, player)
    path = base+f'/documents/{doc}/comments'
    ids = [uid() for _ in range(5)]
    for item in ids:
        assert c.post(path, headers=player[1], json={'id':item,'text':'Message'}).status_code == 200
    with app.state.engine.begin() as conn:
        conn.execute(update(task_comments).values(created=1))
    first = c.get(path+'?limit=2', headers=owner[1]).json()
    newest = uid()
    c.post(path, headers=owner[1], json={'id':newest,'text':'New arrival'})
    seen = [r['id'] for r in first['items']]
    cursor = first['next']
    while cursor:
        page = c.get(path+'?limit=2&before='+cursor, headers=owner[1]).json()
        seen.extend(r['id'] for r in page['items'])
        cursor = page['next']
    assert len(seen) == len(set(seen)) == 5
    assert set(seen) == set(ids)
