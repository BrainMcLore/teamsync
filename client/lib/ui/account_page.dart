import '../data/reminders.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account.dart';
import '../data/account_roster.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';
import 'online_team_page.dart';

class AccountPage extends StatefulWidget {
  final Store store;
  final ValueChanged<String> onLocale;
  final Uri? callback;
  final AccountClient Function(String)? clientFactory;
  const AccountPage({
    super.key,
    required this.store,
    required this.onLocale,
    this.callback,
    this.clientFactory,
  });
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with WidgetsBindingObserver {
  AppLocalizations get l => AppLocalizations.of(context);
  late TextEditingController address;
  AccountClient? api;
  Map<String, dynamic>? profile;
  List<dynamic> teams = [], devices = [], invitations = [];
  Map<String, dynamic> providers = {'steam': true, 'discord': true};
  bool busy = false;
  String? failure;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    address = TextEditingController(
      text: widget.store.setting('api_url') ?? AccountClient.defaultServer,
    );
    if (address.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) act(connect);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    api?.cancelLogin?.call();
    address.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && profile != null && !busy) {
      act(reload);
    }
  }

  String error(Object error) =>
      switch (error is DomainError ? error.code : 'error') {
        'invalidServer' => l.invalidServer,
        'provider_not_configured' => l.providerNotConfigured,
        'unauthorized' => l.sessionExpired,
        'loginTimeout' => l.loginTimeout,
        'loginCancelled' => l.loginCancelled,
        'reauthentication_required' => l.reauthenticate,
        'last_identity' => l.lastIdentity,
        _ => accountError(l, error),
      };
  Future<void> act(Future<void> Function() fn) async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await fn();
    } catch (e) {
      if (e is DomainError && e.code == 'unauthorized') {
        try {
          await ReminderCoordinator.of(widget.store)?.clearForLogout();
        } catch (_) {}
        widget.store.setSetting('account_signed_out', '1');
        await api?.storage.delete(key: api!.storageKey);
        api?.token = null;
        if (mounted) {
          setState(() {
            profile = null;
            teams = [];
            devices = [];
            invitations = [];
          });
        }
      }
      if (mounted) setState(() => failure = error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connect() async {
    final client =
        widget.clientFactory?.call(address.text) ?? AccountClient(address.text);
    // Free hosting may take a minute to wake up; only retry this read-only probe.
    Map<String, dynamic>? health;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        health = await client.request(
          'GET',
          '/api/v1/health',
          authorize: false,
        );
        break;
      } catch (_) {
        if (attempt == 3) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }
    }
    await client.loadToken();
    widget.store.setSetting('api_url', client.base.toString());
    if (mounted) {
      setState(() {
        api = client;
        providers = health?['providers'] as Map<String, dynamic>? ?? providers;
      });
    }
    if (widget.callback != null) await client.completeLogin(widget.callback!);
    if (client.token != null) await reload();
  }

  Future<void> reload() async {
    final me = await api!.request('GET', '/api/v1/me');
    rememberAccountIdentity(
      widget.store,
      api!.base.toString(),
      me['id'] as String,
    );
    final all = await api!.request('GET', '/api/v1/teams');
    final sessions = await api!.request('GET', '/api/v1/me/sessions');
    final inbox = await api!.request('GET', '/api/v1/me/invitations');
    if (mounted) {
      setState(() {
        profile = me;
        teams = all['items'] as List;
        devices = sessions['items'] as List;
        invitations = inbox['items'] as List;
      });
    }
  }

  Future<String?> input(String label) => showDialog<String>(
    context: context,
    builder: (ctx) => _InputDialog(label: label),
  );
  Future<void> teamCreate() async {
    final name = await input(l.teamName);
    if (name != null) {
      await api!.request('POST', '/api/v1/teams', body: {'name': name});
      await reload();
    }
  }

  Future<void> join() async {
    final code = await input(l.inviteCode);
    if (code != null) {
      await api!.request('POST', '/api/v1/invites/join', body: {'code': code});
      await reload();
    }
  }

  Future<void> invite(Map team) async {
    final result = await api!.request(
      'POST',
      '/api/v1/teams/${team['id']}/invites',
      body: {'role': 'player', 'expires_hours': 24},
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.inviteCode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(result['code'] as String),
            const SizedBox(height: 16),
            Text(l.inviteExpiry),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.back)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(l.onlineAccount),
      actions: [
        DropdownButton<String>(
          value: Localizations.localeOf(context).languageCode,
          items: const [
            DropdownMenuItem(value: 'ru', child: Text('Русский')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (value) {
            if (value != null) widget.onLocale(value);
          },
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l.accountHelp),
          const SizedBox(height: 20),
          TextField(
            controller: address,
            enabled: !busy && api == null,
            decoration: InputDecoration(
              labelText: l.serverAddress,
              hintText: 'https://api.example.com',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          if (api == null)
            FilledButton(
              onPressed: busy ? null : () => act(connect),
              child: Text(l.connect),
            ),
          if (api != null && profile == null && !busy)
            TextButton(
              onPressed: () => setState(() => api = null),
              child: Text(l.serverAddress),
            ),
          if (busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            Text(l.serverWaking),
            TextButton(
              onPressed: () => api?.cancelLogin?.call(),
              child: Text(l.cancel),
            ),
          ],
          if (failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (api != null && profile == null) ...[
            const SizedBox(height: 20),
            for (final provider in ['steam', 'discord'])
              if (providers[provider] == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.tonal(
                    onPressed: busy
                        ? null
                        : () => act(() async {
                            await api!.login(provider, l.loginComplete);
                            await reload();
                          }),
                    child: Text(
                      provider == 'steam' ? l.signInSteam : l.signInDiscord,
                    ),
                  ),
                ),
          ],
          if (profile != null) ...[
            const SizedBox(height: 24),
            Text(
              profile!['name'] as String,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            SelectableText('${l.accountId}: ${profile!['id']}'),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: profile!['id'] as String),
                  ),
                  icon: const Icon(Icons.copy),
                  label: Text(l.copyAccountId),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          final name = await input(l.editProfile);
                          if (name == null) return;
                          await api!.request(
                            'PATCH',
                            '/api/v1/me',
                            body: {'name': name},
                          );
                          await reload();
                        }),
                  child: Text(l.editProfile),
                ),
              ],
            ),
            Text(
              (profile!['identities'] as List)
                  .map((e) => e['provider'])
                  .join(' · '),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => act(reload),
                  child: Text(l.refresh),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          try {
                            try {
                              await ReminderCoordinator.of(widget.store)
                                  ?.clearForLogout();
                            } catch (_) {}
                            await api!.logout();
                          } finally {
                            widget.store.setSetting('account_signed_out', '1');
                            if (mounted) {
                              setState(() {
                                profile = null;
                                teams = [];
                                devices = [];
                                invitations = [];
                              });
                            }
                          }
                        }),
                  child: Text(l.signOut),
                ),
              ],
            ),
            for (final provider in ['steam', 'discord'])
              if (providers[provider] == true)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(provider == 'steam' ? 'Steam' : 'Discord'),
                  trailing: TextButton(
                    onPressed: busy
                        ? null
                        : () => act(() async {
                            final linked = (profile!['identities'] as List).any(
                              (identity) => identity['provider'] == provider,
                            );
                            if (linked) {
                              await api!.request(
                                'DELETE',
                                '/api/v1/me/identities/$provider',
                              );
                            } else {
                              await api!.login(
                                provider,
                                l.loginComplete,
                                link: true,
                              );
                            }
                            await reload();
                          }),
                    child: Text(
                      (profile!['identities'] as List).any(
                            (identity) => identity['provider'] == provider,
                          )
                          ? l.unlinkProvider
                          : l.linkProvider,
                    ),
                  ),
                ),
            const Divider(height: 40),
            if (invitations.isNotEmpty) ...[
              Text(
                l.incomingInvites,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final invitation in invitations)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invitation['name'] as String),
                        Text(accountRole(l, invitation['role'] as String)),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => act(() async {
                                      await api!.request(
                                        'POST',
                                        '/api/v1/me/invitations/${invitation['id']}/accept',
                                      );
                                      await reload();
                                    }),
                              child: Text(l.acceptInvite),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => act(() async {
                                      await api!.request(
                                        'DELETE',
                                        '/api/v1/me/invitations/${invitation['id']}',
                                      );
                                      await reload();
                                    }),
                              child: Text(l.declineInvite),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 32),
            ],
            Text(l.onlineTeams, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l.onlineTeamsHelp),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => act(teamCreate),
                  child: Text(l.createTeam),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => act(join),
                  child: Text(l.joinTeam),
                ),
              ],
            ),
            for (final raw in teams)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(raw['name'] as String),
                onTap: busy
                    ? null
                    : () async {
                        final opened = await Navigator.of(context).push<String>(
                          MaterialPageRoute<String>(
                            builder: (_) => OnlineTeamPage(
                              api: api!,
                              store: widget.store,
                              team: Map<String, dynamic>.from(raw as Map),
                              user: profile!['id'] as String,
                            ),
                          ),
                        );
                        if (!mounted) return;
                        if (opened != null) {
                          Navigator.pop(this.context);
                          return;
                        }
                        await act(reload);
                      },
                subtitle: Text(switch (raw['role']) {
                  'owner' => l.owner,
                  'captain' => l.captain,
                  'coach' => l.coach,
                  'viewer' => l.viewer,
                  _ => l.player,
                }),
                trailing: ['owner', 'captain', 'coach'].contains(raw['role'])
                    ? IconButton(
                        tooltip: l.inviteMember,
                        onPressed: busy
                            ? null
                            : () => act(() => invite(raw as Map)),
                        icon: const Icon(Icons.person_add_outlined),
                      )
                    : null,
              ),
            const Divider(height: 40),
            Text(
              l.activeDevices,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final raw in devices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(raw['device'] as String),
                trailing: TextButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          await api!.request(
                            'DELETE',
                            '/api/v1/me/sessions/${raw['id']}',
                          );
                          if (raw['id'] == profile!['session_id']) {
                            await api!.storage.delete(key: api!.storageKey);
                            api!.token = null;
                            if (mounted) setState(() => profile = null);
                          } else {
                            await reload();
                          }
                        }),
                  child: Text(l.revokeSession),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class _InputDialog extends StatefulWidget {
  final String label;
  const _InputDialog({required this.label});
  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
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
      title: Text(widget.label),
      content: TextField(controller: text, autofocus: true, maxLength: 120),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (text.text.trim().isNotEmpty) {
              Navigator.pop(context, text.text.trim());
            }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
