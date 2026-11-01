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


def test_four_stage_task_return_requires_an_explicit_reason(setup):
    _, client, (owner, player, _) = setup
    team = client.post('/api/v1/teams', headers=owner[1], json={'name': 'Practice'}).json()['id']
    base = f'/api/v1/teams/{team}'
    code = client.post(base+'/invites', headers=owner[1], json={}).json()['code']
    client.post('/api/v1/invites/join', headers=player[1], json={'code': code})
    task = {'operation_id': uid(), 'document_id': uid(), 'expected_version': 0,
            'kind': 'task', 'payload': {'title': 'Dry run', 'assignee_user_id': player[0]}}
    assert client.post(base+'/documents', headers=owner[1], json=task).status_code == 200
    for version, status in [(1, 'in_progress'), (2, 'submitted')]:
        task = {**task, 'operation_id': uid(), 'expected_version': version,
                'payload': {**task['payload'], 'status': status}}
        assert client.post(base+'/documents', headers=player[1], json=task).status_code == 200
    returned = {**task, 'operation_id': uid(), 'expected_version': 3,
                'payload': {**task['payload'], 'status': 'todo'}}
    assert client.post(base+'/documents', headers=owner[1], json=returned).status_code == 422
    returned['payload']['task_review_reason'] = 'Redo the first flash timing'
    response = client.post(base+'/documents', headers=owner[1], json=returned)
    assert response.status_code == 200
    # Older clients omitting the field retain the manager's review comment.
    resumed = {**task, 'operation_id': uid(), 'expected_version': 4,
               'payload': {**task['payload'], 'status': 'in_progress'}}
    response = client.post(base+'/documents', headers=player[1], json=resumed)
    assert response.status_code == 200
    saved = next(r for r in client.get(base+'/documents', headers=player[1]).json()['items'] if r['id']==task['document_id'])
    assert saved['payload']['task_review_reason'] == returned['payload']['task_review_reason']


def test_assignment_deadlines_and_criteria_survive_old_clients_and_are_manager_owned(setup):
    _, client, (owner, player, _) = setup
    team = client.post('/api/v1/teams', headers=owner[1], json={'name': 'Plan'}).json()['id']
    base = f'/api/v1/teams/{team}'
    code = client.post(base+'/invites', headers=owner[1], json={}).json()['code']
    client.post('/api/v1/invites/join', headers=player[1], json={'code': code})
    old_payload = {'title': 'Retake B', 'assignee_user_id': player[0]}
    task = {'operation_id': uid(), 'document_id': uid(), 'expected_version': 0,
            'kind': 'task', 'payload': {**old_payload, 'task_type': 'retake',
            'task_due_at': '2026-11-02T18:30:00.000Z', 'task_criteria': 'Three coordinated retakes'}}
    invalid = {**task, 'payload': {**task['payload'], 'task_due_at': '2026-11-02T18:30:00'}}
    assert client.post(base+'/documents', headers=owner[1], json=invalid).status_code == 422
    invalid['payload']['task_due_at']='2026-02-30T18:30:00Z'
    assert client.post(base+'/documents', headers=owner[1], json=invalid).status_code == 422
    assert client.post(base+'/documents', headers=owner[1], json=task).status_code == 200
    start = {**task, 'operation_id': uid(), 'expected_version': 1,
             'payload': {**old_payload, 'status': 'in_progress'}}
    rewrite = {**start, 'payload': {**start['payload'], 'task_criteria': 'Changed'}}
    assert client.post(base+'/documents', headers=player[1], json=rewrite).status_code == 403
    assert client.post(base+'/documents', headers=player[1], json=start).status_code == 200
    saved = next(r for r in client.get(base+'/documents', headers=player[1]).json()['items'] if r['id']==task['document_id'])
    for field in ('task_type','task_due_at','task_criteria'):
        assert saved['payload'][field] == task['payload'][field]
    clear = {**start, 'operation_id': uid(), 'expected_version': 2,
             'payload': {**start['payload'], 'task_due_at': None}}
    assert client.post(base+'/documents', headers=owner[1], json=clear).status_code == 200
    saved = next(r for r in client.get(base+'/documents', headers=player[1]).json()['items'] if r['id']==task['document_id'])
    assert saved['payload']['task_due_at'] is None
    assert saved['payload']['task_criteria'] == task['payload']['task_criteria']
    submitted={**clear,'operation_id':uid(),'expected_version':3,'payload':{**clear['payload'],'status':'submitted'}}
    assert client.post(base+'/documents',headers=player[1],json=submitted).status_code==200
    changed={**submitted,'operation_id':uid(),'expected_version':4,'payload':{**submitted['payload'],'task_criteria':'Different after submission'}}
    assert client.post(base+'/documents',headers=owner[1],json=changed).status_code==422
