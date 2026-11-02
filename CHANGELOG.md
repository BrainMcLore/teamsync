# Changelog / Изменения

## Unreleased

- Offline team packages now retain local tactic revision history with remapped references, bounded validation and legacy schema compatibility.

- Portable review exports now include tick/round-linked notes, their creation times and scouting labels; legacy files remain compatible and failed imports roll back cleanly.

- Added team/member workload snapshots with real task states, unfinished deadlines, unassigned work and explicit cache limitations (English/Russian).

- Added opt-in native Windows/Android practice reminders, account-scoped preferences, generic notification text and cancellation/logout guards.
- Local reminders use the last synchronized schedule; cloud push and physical-device delivery acceptance remain pending.

- Added shared fixed-time events, self RSVP and separate coach attendance, with audited corrections and retained former-member records.
- Added account-scoped offline schedule caches and durable versioned mutations; open views refresh every 30 seconds.

- Added task evidence: own PNG/JPEG/MP4, task/version receipts, assignee/coach permissions, offline retries and verified local copies.

- Added per-task discussion with author/time, team permissions, stable cursor pagination and an account-scoped offline cache.
- Unsent comments have a persistent queue; opening or refreshing the discussion retries with the same ID.

- Legacy assignees no longer stop synchronization of unrelated tactics and tasks.
- Managers can repair an assignment through the task plan editor; task data is preserved.
- Added English/Russian synchronization guidance and regression coverage.

## 0.95 Beta

**English**

- Shared team tactics, utility materials and versioned synchronization with a durable offline queue.
- Personal training plans with types, deadlines, criteria, review states and authored history.
- Map preparation wizard: four templates and per-tactic player distribution.
- Windows demo tooling, tick-linked notes, PDF playbooks and local bootcamp controls.
- Signed Android package, English/Russian interface and refreshed bilingual documentation.
- Removed internal transfer notes, obsolete check logs and unused platform scaffolding.

**Русский**

- Общие тактики и раскидки команды, версии и очередь изменений без связи.
- Персональные тренировки: типы, сроки, критерии, проверка и история авторов.
- Мастер подготовки карты: четыре шаблона и распределение игроков по тактикам.
- Windows-инструменты демок, заметки к тикам, PDF и локальный буткемп.
- Подписанный APK, русский/английский интерфейс и новая документация.
- Убраны внутренние заметки переноса, старые журналы и лишние платформенные заготовки.

See [beta scope](README.md#beta-scope) before installing.
