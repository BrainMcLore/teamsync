# Road to 1.0 / До полного релиза

The published 0.95 Beta remains immutable. Development continues in a separate branch; 1.0 is released only after the following gates are demonstrated, not merely implemented in the UI.

## 1. Reliable shared workspace

- [x] Isolate legacy tasks with unlinked assignees so they cannot block other documents.
- [x] Let managers repair assignments using real team accounts; retain notes and progress.
- [ ] Exercise interruption, restart, conflict and account changes on two physical devices.
- [ ] Confirm Steam sign-in and linking with live consent.

## 2. Complete training workflow

- [x] Task discussion with authorship, permissions, cursor pagination and offline cache (development branch).
- [x] Training evidence attached to the correct task/version with bounded media storage (development branch).
- [x] Shared fixed-time events, self RSVP and coach attendance with history and durable retries (development branch).
- [x] Opt-in account-scoped native local reminders with explicit permission and offline behavior (development branch).
- [ ] Physical Windows/Android reminder delivery, reboot, permission changes and upgrade acceptance.
- [ ] Cloud push notifications and remote changes while the app is closed.
- [x] Current team/member workload snapshots derived from real assignment states, separating submitted and accepted work (development branch).

## 3. Demo and offline acceptance

- [ ] Current HLTV source verification/download acceptance on Windows.
- [ ] Real CS2 launch and review performance on representative demos.
- [x] Portable parsed reviews with tick/round note snapshots and scouting labels; legacy import and atomic rollback (development branch).
- [ ] Complete review edit/deletion history and physical cross-device offline acceptance.
- [ ] Live joint review with reconnect and access control.

## 4. Bootcamp

- [ ] Real installation/start/stop acceptance for CS2, practice/PUG and TeamSpeak.
- [ ] Remote agent with scoped commands, authentication and observable failures.

## 5. Release gate

- [ ] Windows installer upgrade and uninstall preserving user data.
- [ ] Android update over the persistent release signature on physical devices.
- [ ] Backup/restore, migration and multi-device regression matrix.
- [ ] Matching documentation, final CI, package integrity and secret audit.

Русский: пункты выше — критерии приёмки 1.0. Сначала надёжность общего пространства, затем полный цикл тренировок, демки/офлайн, буткемп и проверка обновлений. Непроверенные внешние интеграции не считаются готовыми по одному наличию кнопки.
