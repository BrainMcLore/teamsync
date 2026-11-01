# Модель данных

SQLite schema v1: settings(key PK,value); teams(id PK,name,description,created_at); members(id PK,team_id FK,name,role,game_role); maps(id PK,team_id FK,name,image_path); strategies(id PK,map_id FK,title,side,notes,objects JSON,version,updated_at); strategy_versions(id PK,strategy_id FK,version,payload JSON,created_at, UNIQUE(strategy_id,version)); tasks(id PK,team_id FK,strategy_id FK nullable,member_id FK nullable,title,notes,status,updated_at); demos(id PK,team_id FK,name,path,size,imported_at).

FK включены. Удаление родителей ограничено RESTRICT; каскад используется только для истории удаляемой тактики. Индексы по FK и updated_at. Запись тактики и её версии — одна транзакция. Задание не может ссылаться на участника или тактику другой команды. Названия обязательны, длина ограничена. Статусы заданий: todo → submitted → approved или submitted → todo. Локальные роли — метаданные состава, не доказательство полномочий.

Миграции клиента управляются PRAGMA user_version. Версия 2 добавляет maps.catalog_id/lower_image_path, strategies.level, demos.source_page/analysis_path/map_key/sha256/match_id/participants и demo_annotations(id,demo_id,tick,round,note,created_at). Снимки кадров и событий хранятся отдельным проверяемым JSON в локальном каталоге. Одна демка соответствует карте записи, а не отдельному игроку. match_id объединяет карты одного импорта; полная сущность профессионального матча остаётся следующей серверной миграцией.

Фикстура схемы 0.1 извлечена из ранее поставленного исходного ZIP; тест обновления проверяет сохранение команды, собственной карты, тактики, заметок и связанных заданий. Пакет переносит оба изображения уровня и выбранный уровень тактики. Локальная схема не подменяет серверную модель.

## Реализованная серверная схема v1

SQLAlchemy Core / PostgreSQL, DDL: server/migrations/001_initial_postgresql.sql. SQLite используется только как dev/test вариант. На новой базе bootstrap создаёт начальную схему; обновления между будущими версиями ещё требуют отдельной миграции.

- users: UUID, имя и язык ru/en. external_identities: provider + subject уникальны; по одному провайдеру каждого типа на user_id. Совпадение имени не объединяет аккаунты.
- sessions: случайный bearer хранится только как SHA-256 digest, user FK, device, created/expires. auth_states: хэш state, provider, PKCE challenge, разрешённый redirect, link_user и expiry 5 минут. auth_codes: хэш одноразового кода, user FK, challenge, expiry 60 секунд.
- teams: name, owner FK и created. memberships: UNIQUE(team_id,user_id), отдельная роль доступа. invites: хэш одноразового кода, team FK, роль и expiry, отзыв удалением.
- documents: UUID, team FK/index, kind map/strategy/task, валидируемый JSON payload, version и updated. document_versions: UNIQUE(document_id,version), author FK и неизменяемый снимок.
- sync_operations: уникальный operation UUID, team/user FK, request digest и сохранённый ответ. Повтор той же операции возвращает тот же результат; изменённый запрос под тем же ID отклоняется. Это серверная идемпотентность, клиентская outbox ещё не реализована.
- audit_events: team/user FK, action, object_id, timestamp. Все операции командных данных повторно проверяют членство. Чужие объекты возвращают not_found; запись разрешена owner/captain/coach, передача владения — owner. Удаление владельца через remove запрещено.

История документов сохраняется отдельными строками. FK ограничивают удаление; API удаления пользовательских данных с соблюдением истории ещё не реализован. Worker/jobs, object storage, расписание и остальные сущности полного ТЗ остаются следующими миграциями.

## Локальная схема v3

Перед миграцией существующей дисковой v1/v2 создаётся VACUUM INTO backup с уникальным именем. demos.scouting — ограниченный JSON: teams, event, tier, positions и source=coach. Метки общие для карт одного match_id внутри команды, без пересечения команд. demo_annotations по-прежнему привязаны к demo_id, tick и round; удаление проверяет demo_id. t и ct — отдельные типы объектов тактики, сохраняются в истории и .teamsync.

Черновики плейбуков находятся в settings под playbooks:<team_id>; страницы имеют UUID, title/economy/plan/roles и attachments. Снимок содержит локальный PNG, strategy_id, title/map/side/level/version/notes/captured_at; PNG материализуется при добавлении, оригинальная тактика не перечитывается при экспорте черновика. Черновики пока не включены в offline package. pc.* содержит пути и несекретные LAN-настройки. RCON-секрет случайный на запуск и хранится только в памяти.

## 0.4: runtime индексы, catalog cache, server setup

Схема SQLite остаётся v3. ReviewIndex создаётся в isolate из исходного JSON: sorted timeline, интервалы с реальными start/end, сортировка scoreboard. Он существует только в памяти, не записывается в portable file. WeakReference-cache и объединение одновременных чтений исключают повторную загрузку без удержания всех просмотренных матчей навсегда. Player interpolation не меняет исходные frame maps.

HLTV cache — app-support/hltv-cache/results-<offset>.json и match-<id>.json; offset, fetched_at и source сохраняются. hltv.eventTiers в settings — ручные метки событий. Официальные команды/событие при импорте сохраняются в scouting, уже введённые позиции/тир не стираются при повторном импорте. Cookie-состояние HTTPS-сеанса только анонимное и в памяти worker, не личные browser cookies.

pc.installRoot сохраняет выбранный родительский каталог даже при отмене. TeamSyncServers/<kind> содержит .teamsync-install.json с ownership/state. SteamCMD app 730 и TS3 ZIP имеют отдельные пути. Managed pending install блокирует запуск; отмена сохраняет content для SteamCMD resume. TS license marker создаётся только после принятия пользователем диалога с загруженным текстом.


## Миграция SQLite v4

Таблица `utilities`: UUID, внешний ключ команды и карты, название, сторона T/CT, инструкция, ограниченные JSON-метаданные и UTC-время обновления. Индекс `(team_id,map_id)` обслуживает библиотеку. Метаданные содержат источник, автора, параметры броска и локальные ID связанных тактик; при синхронизации/экспорте связи переводятся явно. Серверные версии хранятся в `documents`/`document_versions`; запись доступна управляющим ролям. Перед обновлением существующей базы создаётся `.pre-v4-*.sqlite`.

### Utility study progress (schema v5)

`utility_progress_cache` keeps account-bound remote states, durable pending operations,
local intentions and explicit conflicts per team, remote utility, user and material
revision. Server tables `utility_progress` and `utility_progress_versions` retain
current state and author-attributed history. Players update their own preparation;
only managers confirm a ready member. Returning another member to preparation
requires a comment. An explicit material revision starts a new verification cycle;
ordinary text edits preserve the current cycle. Progress history is currently kept
on the server and in the local cache, and is not included in offline exports.

### Task workflow (schema v6)

The task table now accepts `in_progress` in addition to `todo`, `submitted` and
`approved`, and stores `review_reason` (wire field `task_review_reason`). The
migration backs up existing on-disk databases and rebuilds the table in one SQLite
transaction, preserving task IDs, links and sync settings. Returning a task requires
an explicit nonempty reason. Players can start and submit their own assignments;
manager approval remains protected on the API. Existing three-stage clients may
still submit directly from `todo`. Older task edits omitting the review field retain
the saved comment. Offline exports retain both the new stage and review comment.

### Assignment plans (schema v7)

Tasks add `task_type`, `due_at` and `criteria`, represented as `task_type`,
`task_due_at` and `task_criteria` in versioned documents. Existing tasks migrate
as general assignments with no deadline and empty criteria. The on-disk database
is backed up before upgrade; existing IDs, progress, review reasons and sync queues
remain intact. Deadlines carry an explicit offset and are stored as UTC by the
client. Imported deadlines reject invalid calendar dates and missing time zones.
Managers can change plans before submission. Submitted/approved plans require a
return with a comment first. Player status updates cannot rewrite plan metadata.
Older clients omitting these fields preserve the server values; explicit null clears
a deadline. Offline packages carry the plan alongside progress and review reasons.

### Map-preparation batches

Preparation is a client-side transaction over ordinary versioned tasks. Each
selected tactic has its own explicit set of current account members. The batch
requires a deadline and criteria, permits four built-in training templates, and
creates at most 500 personal assignments. Account binding, role, map ownership,
strategy ownership and the current roster are revalidated before writing. A failed
local transaction leaves no partial tasks. Network delivery uses the existing
durable queue per task; the batch is not a new atomic server-side API operation.

## Task discussion (development)

`task_comments` stores immutable UUID, team, task document, author, text (1–5000 characters) and server time. The API verifies team membership and task kind; viewers read only. A repeated ID is accepted only for the same author, team, task and text. Pages use a stable `(created, id)` cursor. Per-task and per-author limits bound writes. PostgreSQL migration: `004_task_comments_postgresql.sql`.

The client scopes cached comments and the pending queue to server/account/team/task. It caches up to 200 loaded comments and queues up to 50 sends. Opening or refreshing the discussion retries queued messages; there is no background-delivery promise. Account changes reject late responses before cache writes or queue acknowledgement. Text discussion does not yet include training evidence attachments.
