import 'package:flutter/material.dart';

import '../data/account.dart';
import '../data/account_roster.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';

String accountError(AppLocalizations l, Object e) =>
    switch (e is DomainError ? e.code : '') {
      'account_not_found' => l.accountNotFound,
      'invalid_invite' => l.inviteInvalid,
      'already_member' => l.alreadyMember,
      'forbidden' => l.accessDenied,
      'write_conflict' => l.writeConflict,
      'transfer_ownership_first' => l.ownershipRequired,
      'unauthorized' => l.sessionExpired,
      _ => l.connectionError,
    };

String accountRole(AppLocalizations l, String role) => switch (role) {
  'owner' => l.owner,
  'captain' => l.captain,
  'coach' => l.coach,
  'viewer' => l.viewer,
  _ => l.player,
};

class OnlineTeamPage extends StatefulWidget {
  final AccountClient api;
  final Store store;
  final Map<String, dynamic> team;
  final String user;
  const OnlineTeamPage({
    super.key,
    required this.api,
    required this.store,
    required this.team,
    required this.user,
  });
  @override
  State<OnlineTeamPage> createState() => _OnlineTeamPageState();
}

class _OnlineTeamPageState extends State<OnlineTeamPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  List<dynamic> members = [], pending = [];
  bool busy = false;
  String? failure;
  String get path => '/api/v1/teams/${widget.team['id']}';
  String get role =>
      members.where((r) => r['id'] == widget.user).firstOrNull?['role']
          as String? ??
      widget.team['role'] as String;
  bool get manager => ['owner', 'captain', 'coach'].contains(role);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => act(reload));
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => failure = accountError(l, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reload() async {
    final result = <dynamic>[];
    for (var offset = 0; ; offset += 100) {
      final page = await widget.api.request(
        'GET',
        '$path/members?offset=$offset&limit=100',
      );
      final rows = page['items'] as List;
      result.addAll(rows);
      if (rows.length < 100) break;
    }
    final mine = result.where((r) => r['id'] == widget.user).firstOrNull;
    final outgoing =
        mine != null && ['owner', 'captain', 'coach'].contains(mine['role'])
        ? await widget.api.request('GET', '$path/account-invites')
        : {'items': []};
    if (mounted) {
      setState(() {
        members = result;
        pending = outgoing['items'] as List;
      });
    }
  }

  Future<void> openShared() async {
    await reload();
    final existing = widget.store.teams.where((t) {
      final raw = widget.store.setting('account_team_${t['id']}');
      return raw != null &&
          raw.contains(widget.team['id'] as String) &&
          raw.contains(widget.user);
    }).firstOrNull;
    String? selected = existing?['id'] as String?;
    if (existing == null) {
      final available = widget.store.teams
          .where((t) => widget.store.setting('account_team_${t['id']}') == null)
          .toList();
      var choice =
          available
                  .where((t) => t['id'] == widget.store.setting('team'))
                  .firstOrNull?['id']
              as String? ??
          '';
      if (!mounted) return;
      selected = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            title: Text(l.linkWorkspace),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.linkTeamExplain),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: choice,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(l.newSharedWorkspace),
                    ),
                    for (final row in available)
                      DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text(
                          row['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => set(() => choice = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, choice),
                child: Text(l.syncTactics),
              ),
            ],
          ),
        ),
      );
      if (selected == null) return;
    }
    final localTeam = saveAccountRoster(
      widget.store,
      widget.api.base.toString(),
      widget.user,
      {...widget.team, 'role': role},
      members,
      localTeam: selected == null || selected.isEmpty ? null : selected,
    );
    if (mounted) Navigator.pop(context, localTeam);
  }

  Future<bool> confirm(String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.confirmAction),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.save),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> invite() async {
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => _AccountIdDialog(),
    );
    if (target == null) return;
    final user = await widget.api.request(
      'GET',
      '/api/v1/users/lookup?user_id=${Uri.encodeQueryComponent(target)}',
    );
    if (!mounted ||
        !await confirm('${l.inviteMember}: ${user['name']}\n${user['id']}')) {
      return;
    }
    await widget.api.request(
      'POST',
      '$path/account-invites',
      body: {'user_id': user['id'], 'role': 'player', 'expires_hours': 24},
    );
    await reload();
  }

  Future<void> edit(Map row) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _MemberDialog(row: row, owner: role == 'owner'),
    );
    if (result == null) return;
    await widget.api.request(
      'PATCH',
      '$path/members/${row['id']}',
      body: result,
    );
    await reload();
  }

  Future<void> remove(Map row) async {
    if (!await confirm('${l.removePlayer}: ${row['name']}')) return;
    await widget.api.request('DELETE', '$path/members/${row['id']}');
    await reload();
  }

  Future<void> transfer(Map row) async {
    if (!await confirm('${l.transferOwner}: ${row['name']}')) return;
    await widget.api.request(
      'POST',
      '$path/ownership',
      body: {'user_id': row['id']},
    );
    await reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.team['name'] as String),
      actions: [
        IconButton(
          tooltip: l.refresh,
          onPressed: busy ? null : () => act(reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (failure != null)
            Text(
              failure!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Text(l.accountTeamHelp),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (manager)
                FilledButton.icon(
                  onPressed: busy ? null : () => act(invite),
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text(l.accountInvite),
                ),
              OutlinedButton(
                onPressed: busy || members.isEmpty
                    ? null
                    : () => act(openShared),
                child: Text(l.openInWorkspace),
              ),
              if (role != 'owner')
                TextButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          if (!await confirm(l.leaveTeam)) return;
                          await widget.api.request('POST', '$path/leave');
                          if (mounted) Navigator.pop(this.context);
                        }),
                  child: Text(l.leaveTeam),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l.rosterLocalHelp),
          const Divider(height: 32),
          for (final raw in members)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(raw['name'] as String),
                subtitle: Text(
                  '${accountRole(l, raw['role'] as String)} · ${raw['game_role'] ?? '—'}\n${switch (raw['squad']) {
                    'reserve' => l.reserveSquad,
                    'staff' => l.staffSquad,
                    _ => l.mainSquad,
                  }}',
                ),
                trailing:
                    manager &&
                        (role == 'owner' ||
                            ![
                              'owner',
                              'captain',
                              'coach',
                            ].contains(raw['role']))
                    ? PopupMenuButton<String>(
                        enabled: !busy,
                        onSelected: (v) => act(
                          () => switch (v) {
                            'edit' => edit(raw as Map),
                            'transfer' => transfer(raw as Map),
                            _ => remove(raw as Map),
                          },
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'edit', child: Text(l.role)),
                          if (role == 'owner' && raw['role'] != 'owner')
                            PopupMenuItem(
                              value: 'transfer',
                              child: Text(l.transferOwner),
                            ),
                          if (raw['role'] != 'owner')
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(l.removePlayer),
                            ),
                        ],
                      )
                    : null,
              ),
            ),
          if (pending.isNotEmpty) ...[
            const Divider(height: 32),
            Text(l.outgoingInvites),
            for (final raw in pending)
              ListTile(
                title: Text(raw['name'] as String),
                subtitle: Text(accountRole(l, raw['role'] as String)),
                trailing: IconButton(
                  tooltip: l.cancelInvite,
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          await widget.api.request(
                            'DELETE',
                            '$path/account-invites/${raw['id']}',
                          );
                          await reload();
                        }),
                  icon: const Icon(Icons.close),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class _AccountIdDialog extends StatefulWidget {
  @override
  State<_AccountIdDialog> createState() => _AccountIdDialogState();
}

class _AccountIdDialogState extends State<_AccountIdDialog> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.accountInvite),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: 36,
        decoration: InputDecoration(labelText: l.accountLookup),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, text.text.trim()),
          child: Text(l.inviteMember),
        ),
      ],
    );
  }
}

class _MemberDialog extends StatefulWidget {
  final Map row;
  final bool owner;
  const _MemberDialog({required this.row, required this.owner});
  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late String role = widget.row['role'] as String,
      squad = widget.row['squad'] as String? ?? 'main';
  late final game = TextEditingController(
    text: widget.row['game_role'] as String? ?? '',
  );
  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.row['name'] as String),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: role,
              items: [
                for (final r in [
                  if (widget.row['role'] == 'owner')
                    'owner'
                  else ...[
                    'player',
                    'viewer',
                    if (widget.owner) ...['captain', 'coach'],
                  ],
                ])
                  DropdownMenuItem(value: r, child: Text(accountRole(l, r))),
              ],
              onChanged: (v) => role = v!,
            ),
            TextField(
              controller: game,
              maxLength: 40,
              decoration: InputDecoration(labelText: l.gameRole),
            ),
            DropdownButtonFormField<String>(
              initialValue: squad,
              items: [
                DropdownMenuItem(value: 'main', child: Text(l.mainSquad)),
                DropdownMenuItem(value: 'reserve', child: Text(l.reserveSquad)),
                DropdownMenuItem(value: 'staff', child: Text(l.staffSquad)),
              ],
              onChanged: (v) => squad = v!,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'role': role,
            'game_role': game.text.trim(),
            'squad': squad,
          }),
          child: Text(l.save),
        ),
      ],
    );
  }
}
