import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'kit.dart';

class StudioShell extends StatelessWidget {
  final Widget content, teamSelector, language;
  final List<(String, IconData)> destinations;
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onSearch;
  final bool busy;
  final VoidCallback more;
  const StudioShell({
    super.key,
    required this.content,
    required this.teamSelector,
    required this.language,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onSearch,
    required this.busy,
    required this.more,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 226,
                decoration: const BoxDecoration(
                  color: Color(0xff0d1420),
                  border: Border(right: BorderSide(color: Studio.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 28, 24, 30),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hub_rounded,
                            color: Studio.accent,
                            size: 27,
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'TeamSync',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.7,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        l.workspaceLabel,
                        style: const TextStyle(
                          color: Studio.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          for (var i = 0; i < destinations.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 3,
                              ),
                              child: Material(
                                color: selected == i
                                    ? Studio.elevated
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => onSelect(i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          destinations[i].$2,
                                          size: 19,
                                          color: selected == i
                                              ? Studio.accent
                                              : Studio.muted,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            destinations[i].$1,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: selected == i
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: selected == i
                                                  ? Studio.text
                                                  : Studio.muted,
                                            ),
                                          ),
                                        ),
                                        if (selected == i)
                                          Container(
                                            width: 4,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: Studio.accent,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusTag(
                            l.readyOffline,
                            icon: Icons.computer_outlined,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'CS2 / TEAMSYNC 1.0',
                            style: TextStyle(
                              color: Studio.muted,
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: wide ? 76 : 66,
                    padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Studio.border)),
                    ),
                    child: Row(
                      children: [
                        if (wide) ...[
                          const Icon(
                            Icons.groups_2_outlined,
                            size: 18,
                            color: Studio.muted,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: teamSelector),
                        if (wide) ...[
                          const SizedBox(width: 32),
                          SizedBox(
                            width: 240,
                            child: TextField(
                              onChanged: onSearch,
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(Icons.search, size: 18),
                                hintText: l.searchWorkspace,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 16),
                        language,
                      ],
                    ),
                  ),
                  if (busy) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 32 : 16),
                      child: content,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: switch (selected) {
                0 => 0,
                3 => 1,
                1 => 2,
                5 => 3,
                _ => 4,
              },
              onDestinationSelected: (index) {
                if (index == 4) {
                  more();
                } else {
                  onSelect([0, 3, 1, 5][index]);
                }
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  label: l.overview,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.checklist),
                  label: l.preparation,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  label: l.maps,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups_outlined),
                  label: l.team,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.more_horiz),
                  label: l.more,
                ),
              ],
            ),
    );
  }
}
