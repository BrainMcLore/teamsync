# TeamSync 0.8 — исправления синхронизации и HLTV

Дата: 2026-10-29. Предыдущая проверка: CHECKS_0.7.md.

## Синхронизация

Причина зависшей очереди: HttpClient.write использовал ISO-8859-1 для application/json без charset. Кириллица вызывала исключение до отправки HTTP-запроса. Запросы теперь кодируются в UTF-8 явно, с Content-Length в байтах. Проверка HTTP-сервером включает кириллицу, эмодзи и переносы строк.

Проверка с настоящим аккаунтом и публичным сервером: очередь ранее сохранённой тактики успешно обработана исправленным AccountClient/TacticalSync; outbox пуст, конфликтов нет. Для проверки использована копия SQLite, сессия расшифрована штатным Windows DPAPI только в памяти. Ключи не записывались в исходники, журналы или архивы. Серверный код менять не потребовалось.

## Аккаунты

Создание локальной команды из интерфейса удалено. В основной список попадают только команды, привязанные к серверному аккаунту. Кнопка добавления открывает аккаунт, создание команды выполняется на сервере. При выходе из аккаунта рабочая область скрывается. Старые локальные команды и файлы сохраняются и доступны для привязки к онлайн-команде. Локальный кэш общей команды и очередь на случай потери сети остаются.

## HLTV

При блокировке прямого HTTP-запроса каталог и карточки матчей загружаются тем же изолированным WebView2-сеансом, что и архивы. При необходимости показывается окно проверки сайта. HTML ограничен 4 MiB, временные файлы удаляются; лимит 429 соблюдается без повторной попытки через окно. Время ожидания клиента увеличено до шести минут.

Живая проверка: результаты HLTV получены; карточка BETBOOM — FURIA (2399755) содержит игроков, карты и ссылку /download/demo/113289; архив скачан целиком, 525648852 байта, проверен 7-Zip без ошибок. Собранный worker разобрал обе карты: Dust2 (29 раундов) и Cache (21 раунд), по 10 игроков, с позициями и событиями.

Проверки Python: 42 passed. Flutter: 56 функциональных/визуальных тестов прошли, 2 проверки пропущены без внешнего окружения; отдельная живая проверка очереди с настоящим аккаунтом прошла. Новые эталоны снимков проверены визуально. flutter analyze: без замечаний. Windows-инсталлятор 0.8.0 собран и успешно установлен 2026-10-30. Android release-оптимизированный тестовый APK собран, подпись v2 проверена. Исходный Android APK остался на Windows. Windows-инсталлятор повторно собран в CI 2026-11-01 и получен в текущую папку dist. Контрольные суммы отсутствующих файлов не выдумываются. Статус локальных пакетов отражает dist/TeamSync-0.8.0-manifest.json. Новая Windows-сборка через GitHub Actions успешно завершена: https://github.com/BrainMcLore/teamsync/actions/runs/41259787893.


## Инструменты выпуска — 2026-11-01

Linux используется для редактирования и упаковки исходников. Целевые приложения — Windows и Android, Linux-порт не создаётся. Две проверки стандартной библиотекой Python подтвердили повторяемость Source ZIP, исключение .env.local/хранилища авторизации/локальных баз/ключей и корректный отказ при обязательном, но отсутствующем Windows-инсталляторе. Эти проверки не заменяют Flutter-тесты или повторную сборку Windows.


## Windows CI — 2026-11-01

Коммит сборки: 626618797e64762aee89b657a2e2cb1a61caf7b7, Windows 2022. Проверки: 2 теста упаковки, 42 теста worker/сервера, 54 Flutter-теста; 4 пропуска — живая очередь настоящего аккаунта, живой HLTV, benchmark частного разбора пользователя и снимок частного записанного разбора. Нативный frozen worker успешно импортировал закреплённый настоящий DEM fixture. Flutter analyze: без замечаний. Установщик собран Inno Setup; скачанные Source/Server/EXE проверены по SHA-256 из manifest CI.

Windows installer: 132798073 байта; SHA-256 `4851259a2fba2fb11d96b462b4c6be156ef7d67dd4ca2d0e00c323072ff87949`. Новый installer в CI не запускался на пользовательском ПК; предыдущая сборка 0.8 устанавливалась и проверялась до переноса. Android APK не заменён случайно подписанной CI-сборкой и отсутствует в текущем Windows-пакете — это явно указано в manifest.

## Продолжение на Arch — 2026-11-01, изменения после 0.8

- Linux используется только как среда разработки и выполнения тестов; Linux runner приложения не добавлялся.
- Исправлена видимость кеша после смены аккаунта/сервера и выхода. Регрессия проверяет два аккаунта и два сервера; старые материалы сохраняются, но не открываются под другим пользователем.
- Задания включены в версионируемые командные документы: стабильная привязка к аккаунту исполнителя и тактике, очередь операций, конфликтные копии, получение и отправка статусов. Состав обновляется перед синхронизацией.
- Игрок может отправить только собственное существующее задание со статусом `todo` на проверку. Название, описание, назначение и связанные материалы изменять нельзя; подтверждение доступно управляющим ролям. Это проверяется сервером и локальным хранилищем.
- Локально: `flutter analyze` без замечаний; 55 Flutter-тестов прошли, 5 пропущены из-за платформы/отсутствия личных фикстур/явного opt-in. 13 серверных тестов прошли, включая отдельную проверку полномочий заданий. Две проверки упаковки прошли.
- Windows-эталоны скриншотов сохранены; для Linux test host добавлены отдельные изображения из-за различий растеризации текста. Это проверка Flutter UI, а не выпуск приложения для Linux.
- Gitleaks 8.30.1: сканирование всей истории Git до `a580843` не обнаружило секретов. Повторный аудит требуется перед публичным выпуском.
- Android CI добавлен: Android 15, fixture-вход/приглашения/синхронизация, release-оптимизированный тестовый APK и проверка подписи. Успешный итоговый запуск и APK ещё не подтверждены; первый запуск выявил различие Windows/Linux golden-изображений.
- Эти изменения пока не являются новым опубликованным установщиком. Полная приёмка исходного ТЗ остаётся открытой.

- Серверная правка заданий развёрнута через отдельный backend-репозиторий, commit `f29323d`; живой HTTPS health вернул `training_sync` и рабочие провайдеры Steam/Discord. Секреты и база не переносились.
- Настроен постоянный ключ подписи Android; закрытые материалы находятся вне Git, в Actions secrets и локальной защищённой резервной копии. В репозитории хранится только SHA-256 публичного сертификата. Подписанная сборка этим ключом ещё должна пройти CI.
- Устаревшая инструкция переноса среды убрана из текущего дерева исходников; приватная рабочая копия сохранена локально. История предыдущих коммитов сохранена.

### Проверка устройства и ограничение CI

- Windows workflow `41299807366` успешно собрал исходники с общими заданиями (`657582c`). Это не подтверждение последующих изменений раздела раскидок.
- Android workflow `41299838525` (`32e19fd`): unit/analyze и сквозной сценарий Android 15 прошли, включая сдачу и подтверждение задания. Затем runner завершился с `No space left on device` при release APK; артефакт не получен. Это ошибка CI, а не успешная приёмка APK.
- Для повторного запуска закреплён Ubuntu 24.04, добавлена очистка ненужных toolchains и debug/AVD данных перед release, настроен Gradle cache.

### Раскидки — рабочие исходники, после 0.8

- Добавлен нативный RU/EN-раздел: карта, T/CT, тип гранаты, начальная позиция/цель, бросок, инструкция, автор, дата/ревизия и исходная ссылка. YouTube-таймкоды сохраняются; CS2Tricks использует ручное заполнение с открытием оригинала.
- Карточки включены в общую версионируемую библиотеку, конфликтные копии и офлайн-экспорт/восстановление. Связи с картами и несколькими тактиками переводятся между локальными и серверными ID; чужие связи отклоняются сервером.
- SQLite мигрирует в v4 с резервной копией существующей базы. Ссылки допускают только HTTPS YouTube/CS2Tricks без credentials; чужое видео не скачивается.
- Локально: 58 Flutter-тестов прошли, 5 пропущены; отдельные проверки узкой формы RU/EN, синхронизации и восстановления связей прошли. Сервер: 15 тестов прошли, включая совместимость идемпотентных повторов от предыдущей версии API.
- Пиксельные снимки создаются на фикстуре синхронизации, чтобы сетевые ответы не делали визуальные тесты случайными. Реальная синхронизация проверяется отдельно HTTP и Android integration сценариями.
- Собственные видеовложения, изображения прицеливания и статусы изучения ещё не реализованы. Windows-снимки нового меню и платформенные сборки этого изменения ещё требуют проверки.

### Изображения раскидок и проверка подписи

- К раскидке можно прикрепить до десяти собственных PNG/JPEG, открыть масштабируемый просмотр, передать изображения через защищённое командное media API и включить их в офлайн-пакет. Импорт проверяет формат, размер и геометрию; локальные пути не попадают в пакет.
- Открытая форма раскидки защищена от перезаписи входящими изменениями. Сетевые операции выполняются без глобального обхода локальных прав `applyingSync`; отдельная проверка загрузки изображения читателем это контролирует.
- Windows UI snapshots workflow `41301692426` (`0d9ae42`) прошёл; новые снимки меню/раскидок просмотрены и перенесены в эталоны. Это визуальная проверка базовой карточки, не всего нового функционала изображений.
- Android workflow `41301052103` (`b7bec41`) прошёл устройство и собрал APK с постоянным ключом. `apksigner` подтвердил v2 и ожидаемый сертификат, но проверка строки отчёта ожидала старое имя `Signer #1` и остановила загрузку артефакта. Исправлена совместимость с `V2 Signer`, добавлена регрессия двух форматов; исправленный парсер успешно проверил фактический отчёт этого запуска.

### Собственные клипы и очередь после смены роли — рабочие исходники

- Добавлен импорт собственных MP4 до 20 МБ, проверка структуры контейнера и видеодорожки, синхронизация защищённых вложений, офлайн-пакет и открытие системным проигрывателем. На Android используется FileProvider только для каталога медиа приложения; внешние пути отклоняются. Нативный Android-сценарий ещё должен пройти повторный CI.
- Старый клиент при изменении инструкции сохраняет неизвестные ему новые вложения. Новые операции различают отсутствие поля и явное удаление вложения; повторы старых операций поддерживаются.
- После понижения роли недоступные для отправки операции сохраняются, получение новых материалов продолжается. Выход или смена аккаунта останавливает последующие запросы старого аккаунта. Переключение команды и изменения во время синхронизации запускают повтор без ожидания следующего интервала.
- Удалённый или повреждённый кеш вложений восстанавливается с проверкой SHA; восстановление не публикует новую версию документа. Импорт пакета не принимает переданные извне локальные пути.
- Локально: 63 Flutter-теста прошли, 5 пропущены; 17 серверных тестов прошли. Нативные изменения клипов пока не считаются проверенными на устройстве.

### Сохранённый кандидат 56f155a

- Windows workflow `41303650875` и Android workflow `41303249177` завершились успешно на одном коммите `56f155a`. Это сборки до последующих изменений видеоклипов и очереди.
- Артефакты скачаны и проверены по SHA-256: Windows Setup `75887fe5dde48b8f1fff6c60ea60e5cea9a51fc119e1f9c4ff117bc62a2a26fd`; Android APK `583fe0ea88469c8e0493cb82604aac62c0f0c255a1db3410735ffb4d5cd6c0b2`.
- APK подписан постоянным сертификатом. Новый публичный релиз этим результатом не объявлен.

### Utility study progress — development verification

- Server: 18 pytest cases pass, including role boundaries, optimistic conflicts,
  revision changes and author-attributed progress history.
- Client: 9 tactical sync tests pass, including a lost progress acknowledgement,
  retry without duplicate versions, coach confirmation and player self-retraining.
- RU mobile utility card with the study panel rendered and visually inspected on
  Linux; Windows baseline and Android device verification remain pending for this change.
- New feature is not yet deployed or included in a published release.

Windows UI snapshots run 41327200507 completed successfully at a6ba966; the new
utility panel was visually inspected and its Windows baseline accepted. The hosted
API health endpoint now advertises `utility_skills` after backend deployment
5826344. Client analysis is clean; the full suite passes 64 tests with 5 explicit
skips. Progress history also exposes prior verification cycles after a recheck.

### Four-stage assignments — development verification

- Previous native builds at 0e48fba succeeded: Windows 41327479709 and signed
  Android 41327466664, including player-ready / coach-confirmed utility progress.
- New task migration v5 -> v6 preserves assignments, notes and durable sync settings;
  a backup is created before migration. Store tests cover review comments after reopen.
- Two-client tests cover starting a task, submitting, approval and synchronizing the
  reason for return. Server: 19 tests pass, including old-client field preservation.
- New task native builds remain pending; this is not a published release.

Task history now supports paged server reads, author names and a bounded offline
cache. A regression test switches accounts while a request is pending and confirms
that neither the old response nor the old cache becomes available to the new user.
The offline-package test preserves an in-progress assignment and a returned task's
review comment. Full client suite: 67 passed, 5 skipped. Server suite: 19 passed.

Windows UI run 41329837357 passed at c4fd8e2; the task card with Start and History
was visually reviewed and its platform baseline accepted. Production OpenAPI now
reports all four task states and `task_review_reason`. Final native task/history
integration builds are still in progress at this checkpoint.

### Native assignment/history candidates — verified

- Android run 41329940368 succeeded at 6f674a1: emulator account/team integration,
  four assignment stages, return reason, author-attributed history and offline cache;
  signed release APK and pinned certificate verification succeeded.
- Windows run 41330154853 succeeded at d3729ce: parser/worker/server verification,
  Flutter checks, native build and installer packaging all passed.
- Downloaded artifacts and checked every SHA-256 entry against the actual files.
  Android APK: `ccea6bf85eef7477db420b162e63f8ff579a7e854318cdf4a8ef478d6150e735`.
  Windows installer: `4f435a711f7b5d02d419acbf5a0103cda731c191ab7d857f916baec199faaa69`.
  Source ZIP: `3f8992c637441390cfe007a9c77f4ce382f700941a769e32a7624dc956be4dd4`.
  Backend ZIP: `cde85989850a414005eec12f06e8a166f3285a7f208a00cde0e77f204ad78644`.
- These remain private CI candidates carrying the development 0.8.0 version;
  the existing v0.8.0 release assets were not overwritten. Application sources match
  across the candidates; the later Windows commit includes the accepted UI baseline.
- Hosted backend d9607f7 includes the four-stage workflow and author names in history.
  Gitleaks scan of the committed history found no secrets. Old UI capture branches
  were removed after their changes and baselines reached main.

Remaining training scope includes due dates, completion criteria, evidence,
independent comments, templates and the map-preparation wizard. Schedule,
notifications, joint review and the remote server agent remain separate unfinished
parts of the full requirements; passing this milestone does not close full acceptance.

### Assignment plans — development verification

- Added general and specialized training types, optional UTC deadline and completion
  criteria, with two-client synchronization and offline-package round trip.
- v6 -> v7 migration retains active task state and review reason; older migration
  coverage also preserves account assignments and durable sync settings.
- Server tests cover explicit time zones, invalid dates, old-client preservation,
  player immutability, clearing deadlines and locking plans after submission.
- RU/EN form tests at 320px pick a calendar/time deadline, save criteria, edit the
  plan without changing the assignee/progress, and reject a stale account form.
- New assignments offer only current roster accounts; legacy member records remain
  stored. Existing unbound legacy assignments still need an explicit migration path.
- Last full client run: 75 passed, 5 skipped; server: 20 passed. New form screenshot
  and native build checks are being prepared. No final release/publication yet.

Map preparation adds four built-in templates and explicit per-tactic account
assignments. Service tests cover distributed plans, rollback after an injected
failure, stale identity, revoked role, changed roster and foreign-map strategy IDs.
RU/EN 320px wizard tests select a tactic/player, require a deadline and create the
correct personal assignment. Android integration now also generates a preparation
plan and verifies its delivery to the second account.

Windows UI snapshots 41332887265 at c29c8cb passed; task/form PNGs were visually
reviewed and accepted. The hosted OpenAPI confirms all three assignment-plan fields
following backend deployment 74deb0b. Final native builds for this milestone remain
pending at this checkpoint.

After adding preparation: full Flutter suite 80 passed, 5 skipped; analysis clean.
The backend suite remains 20 passed. Local form snapshots remain stable after
extracting the shared deadline picker. No gameplay/voice-server acceptance is
implied by these client/server tests.
