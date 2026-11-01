from test_api import setup
from server.database import uid, documents
from sqlalchemy import select, update


def test_player_can_submit_only_own_assignment_but_cannot_approve_or_rewrite(setup):
    app, client, (owner, player, stranger) = setup
    team = client.post('/api/v1/teams', headers=owner[1], json={'name': 'Training'}).json()['id']
    base = f'/api/v1/teams/{team}'
    code = client.post(base+'/invites', headers=owner[1], json={}).json()['code']
    client.post('/api/v1/invites/join', headers=player[1], json={'code': code})
    body = {'operation_id': uid(), 'document_id': uid(), 'expected_version': 0,
            'kind': 'task', 'payload': {'title': 'Выучить выход', 'notes': 'На B',
                                      'assignee_user_id': player[0]}}
    assert client.post(base+'/documents', headers=owner[1], json=body).status_code == 200
    # A task persisted by the previous API has no utility field.
    with app.state.engine.begin() as conn:
        previous = dict(conn.execute(select(documents.c.payload).where(documents.c.id == body['document_id'])).scalar_one())
        previous.pop('utility', None)
        conn.execute(update(documents).where(documents.c.id == body['document_id']).values(payload=previous))

    submit = {**body, 'operation_id': uid(), 'expected_version': 1,
              'payload': {**body['payload'], 'status': 'submitted'}}
    assert client.post(base+'/documents', headers=stranger[1], json=submit).status_code == 404
    rewrite = {**submit, 'payload': {**submit['payload'], 'title': 'Rewritten'}}
    assert client.post(base+'/documents', headers=player[1], json=rewrite).status_code == 403
    result = client.post(base+'/documents', headers=player[1], json=submit)
    assert result.status_code == 200
    assert client.post(base+'/documents', headers=player[1], json=submit).json() == result.json()
    approve = {**submit, 'operation_id': uid(), 'expected_version': 2,
               'payload': {**submit['payload'], 'status': 'approved'}}
    assert client.post(base+'/documents', headers=player[1], json=approve).status_code == 403
    assert client.post(base+'/documents', headers=owner[1], json=approve).status_code == 200
    foreign = {**body, 'operation_id': uid(), 'document_id': uid(),
               'payload': {**body['payload'], 'assignee_user_id': owner[0]}}
    assert client.post(base+'/documents', headers=owner[1], json=foreign).status_code == 200
    forged = {**foreign, 'operation_id': uid(), 'expected_version': 1,
              'payload': {**foreign['payload'], 'status': 'submitted'}}
    assert client.post(base+'/documents', headers=player[1], json=forged).status_code == 403
    assert client.post(base+'/documents', headers=player[1], json={**body, 'document_id': uid(), 'operation_id': uid()}).status_code == 403
