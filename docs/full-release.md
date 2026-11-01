# Road to 1.0 / До полного релиза

The published 0.95 Beta remains immutable. Development continues in a separate branch; 1.0 is released only after the following gates are demonstrated, not merely implemented in the UI.

## 1. Reliable shared workspace

- [x] Isolate legacy tasks with unlinked assignees so they cannot block other documents.
- [x] Let managers repair assignments using real team accounts; retain notes and progress.
- [ ] Exercise interruption, restart, conflict and account changes on two physical devices.
- [ ] Confirm Steam sign-in and linking with live consent.

## 2. Complete training workflow

- [x] Task discussion with authorship, permissions, cursor pagination and offline cache (development branch).
- [ ] Training evidence attached to the correct task with bounded media storage.
- [ ] Scheduling, attendance and reminders; explicit delivery/offline behavior.
- [ ] Team progress views that derive from real assignments and reviewed work.

## 3. Demo and offline acceptance

- [ ] Current HLTV source verification/download acceptance on Windows.
- [ ] Real CS2 launch and review performance on representative demos.
- [ ] Complete exported review/history packages for Android and offline use.
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
