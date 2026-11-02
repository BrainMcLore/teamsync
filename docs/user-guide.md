# User guide / Руководство

## Team workspace / Команда

Sign in with Steam or Discord, create a team or accept an invitation. Use player accounts for membership and assignments. Coaches/managers maintain shared materials; players work with their assigned practice plans.

Войдите через Steam или Discord, создайте команду или примите приглашение. Добавляйте игроков по аккаунтам. Роли определяют права на редактирование общих материалов и проверку заданий.

## Tactics / Тактики

Choose a ready map, including Cache. Place T/CT players, utility markers, arrows and notes. Save the tactic and check the synchronization indicator. Pending changes stay on the device until reconnection; conflicts preserve a copy.

Выберите карту, расставьте T/CT, гранаты, стрелки и заметки. Сохраните и проверьте индикатор синхронизации. При отсутствии сети дождитесь отправки очереди после подключения.

## Practice / Тренировки

Use Prepare map to select tactics, distribute players per tactic, pick one of four templates, set criteria and a deadline, then review the generated assignments. Players start and submit work; managers approve or return it with a reason. History records who changed the task.

Подготовка карты создаёт персональные задания по выбранным тактикам и игрокам. Укажите шаблон, критерии и срок. Игрок начинает и сдаёт работу, тренер принимает или возвращает с причиной. Срок отображается по местному времени.

## Demos and playbooks / Демки и PDF

On Windows, import DEM/ZIP/RAR or use the HLTV catalog. Complete source verification when prompted. Attach notes to ticks/rounds; launch the demo in an installed CS2. Export a prepared review for Android. Build PDF round plans from tactic snapshots.

На Windows импортируйте демку/архив либо используйте каталог HLTV. При необходимости пройдите проверку источника. Заметки привязываются к тику/раунду. Подготовленный разбор можно импортировать на Android. В PDF-заготовки добавляйте снимки тактик.

## Bootcamp / Буткемп

Windows provides local CS2/TeamSpeak installation and practice/PUG controls. Remote server-agent control is not part of this beta. Real game/server sessions require local configuration and acceptance.

Раздел буткемпа предназначен для локальной установки и запуска на Windows. Удалённый серверный агент пока не выпущен.

Export important local materials before reinstalling. See [beta limitations](../README.md#beta-scope).

## Task discussion (development toward 1.0)

Open **Discussion** on a synchronized assignment. Participants can post a comment; viewers can read. A pending message is saved on the current account's device. Opening the discussion or pressing **Refresh / retry** retries its delivery with the same ID, so a lost acknowledgement does not create a duplicate. Up to 200 previously loaded comments remain cached offline. Discussion is append-only; evidence attachments are a separate upcoming step.

В разработке 1.0: кнопка **Обсуждение** открывает переписку к синхронизированному заданию. Участники могут писать, наблюдатели — читать. Очередь сохраняется на устройстве текущего аккаунта и отправляется при открытии обсуждения или нажатии **Обновить / повторить**. Загруженные комментарии доступны без связи; вложения-доказательства пока не подключены.

## Training evidence (development toward 1.0)

Use **Evidence** on a synchronized assignment to add your own PNG/JPEG screenshot or MP4 clip. A player uploads to their own task; managers can attach evidence across the team. The upload records the task version but does not submit or approve the assignment. Return an approved task to work before adding new evidence. Limits: 20 MiB/file, 100 MiB/team, 100 evidence receipts/task, 10 queued files/task.

Files queued on the device retry when you open or refresh the evidence dialog. Open a received file to keep a verified offline copy. Removing a local retry only stops that retry; it cannot undo an upload already received by the server.

В разделе **Доказательства** прикрепляйте свои PNG/JPEG или MP4. Игрок — к своему заданию, тренер — к заданиям команды. Файл связан с версией задания; загрузка не заменяет сдачу и проверку. Для нового вложения к принятому заданию сначала верните его в работу. Полученный файл нужно открыть для сохранения локальной копии. Очередь повторяется при открытии или обновлении раздела; удаление из очереди не удаляет уже принятое сервером вложение.

## Schedule & attendance (development toward 1.0)

Open **Schedule** in the sidebar or the mobile **More** menu. Managers create practice, scrim, review and bootcamp events, set their start/end, location/server and notes. Choose dates/times in the device zone; teammates see the same UTC instant converted to their own local time. Use the date-range selector for other periods.

Open **Participation & attendance** to answer Going/Maybe/Not going for yourself. This does not mark actual attendance. A manager records Present/Late/Absent/Excused; changing a recorded mark requires a reason. Event/attendance history identifies the author and preserves former members. Cancellation requires a reason and blocks new responses.

Saved operations retry while an open foreground view refreshes, or on manual refresh. A version conflict keeps your local copy: compare it with current data, discard the superseded local operation explicitly, then re-enter the intended change. Offline views contain previously loaded records. Fixed events are supported; recurring events and cloud push remain planned.

Раздел **Расписание** доступен в боковом меню и в мобильном **Ещё**. Тренер создаёт событие с датой, временем, сервером и заметками. Время выбирается в часовом поясе устройства и отображается у каждого участника в его местном времени. Ответ игрока **Буду / Возможно / Не буду** отделён от отметки тренера о фактическом присутствии. Исправление отметки и отмена события требуют причины; история сохраняет автора, время и данные бывших участников. Открытые окна обновляются раз в 30 секунд, очередь переживает отсутствие сети. Повторяющиеся события и облачные push-уведомления пока не подключены.


## Local practice reminders (development toward 1.0)

Open **Schedule → Reminders** on Windows or Android. Enable notifications for the current account on this device and choose 0, 5, 10, 15, 30, 60 or 120 minutes before an event. Grant Android notification permission when prompted; use **Test notification** and system settings to check permission. Windows installation supplies the notification shortcut identity.

The app plans up to 64 events across the current account’s teams for the next 30 days. Cancelled events and your “Not going” responses are excluded. Notifications contain generic text, without team names, notes or account details. Signing out clears the device plan; simply closing the app preserves scheduled reminders.

These are local reminders based on the last synchronized schedule. Keep the app open to receive schedule changes; foreground refresh runs about once a minute. A remote cancellation cannot reach a closed/offline app until it synchronizes again. The displayed last-sync time advances only after a complete successful refresh. Android battery management can delay inexact alarms, and force-stop can prevent delivery. Windows can drop reminders if the computer is off past its delivery window. Physical-device delivery, reboot and upgrade acceptance are still pending; cloud push is not implemented.

**Русский.** Откройте **Расписание → Напоминания**, включите уведомления для текущего аккаунта на этом устройстве и выберите время до начала. На Android разрешите уведомления; проверить их можно кнопкой теста и в системных настройках. Планируется до 64 событий на 30 дней. Отменённые события и ваш ответ «Не буду» исключаются. Текст уведомлений общий, без названий команды и личных заметок. Выход из аккаунта очищает план; закрытие приложения оставляет его активным.

Изменения с сервера применяются после синхронизации: при открытом приложении проверка выполняется примерно раз в минуту. Закрытое приложение без облачного push не узнает об удалённой отмене. Время последнего обновления меняется только после полной успешной загрузки. Энергосбережение Android может задержать сигнал, принудительная остановка — заблокировать его. Выключенный Windows может пропустить уведомление. Проверка фактического показа, перезагрузки и обновления на физических устройствах ещё впереди.

Platform behavior: [Android alarms](https://developer.android.com/develop/background-work/services/alarms), [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission), [Windows scheduled notifications](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-scheduled), [Windows desktop notification identity](https://learn.microsoft.com/en-us/windows/win32/shell/enable-desktop-toast-with-appusermodelid).


## Team progress (development toward 1.0)

Open **Training → Team progress** for the current team's full assignment snapshot, independent of the search filter. The report separates Todo, In progress, Submitted and Approved, and lists every current member including those with no tasks. Unassigned/unavailable members remain visible as a separate group. Only Todo/In progress tasks past their deadline are overdue; waiting for coach review is shown as Submitted. Unknown legacy statuses remain counted rather than appearing approved.

The report uses this device's current synchronized/cached data, including pending local edits. Refresh synchronization before evaluating it. It is a current workload snapshot, not a historical completion rate, attendance score or player ranking; deleted assignments are absent.

**Русский.** В разделе **Тренировки → Прогресс команды** показаны все текущие задания выбранной команды независимо от поиска. Видны задачи каждого участника, включая игроков без заданий, и отдельная группа без исполнителя. Сданное на проверку отделено от принятого тренером; просрочены только незавершённые задания. Данные берутся со снимка на устройстве, включая локальные изменения: перед оценкой обновите синхронизацию. Это текущая нагрузка, а не рейтинг игрока или статистика за прошлые периоды.
