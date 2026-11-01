// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'TeamSync';

  @override
  String get overview => 'Обзор';

  @override
  String get maps => 'Карты';

  @override
  String get strategies => 'Тактики';

  @override
  String get training => 'Тренировки';

  @override
  String get demos => 'Демки';

  @override
  String get team => 'Состав';

  @override
  String get settings => 'Настройки';

  @override
  String get more => 'Ещё';

  @override
  String get localWorkspace => 'Локальная рабочая область';

  @override
  String get localNotice =>
      'Нужен аккаунт. Старые материалы сохранены: их можно привязать к онлайн-команде в разделе аккаунта.';

  @override
  String get createTeam => 'Создать команду';

  @override
  String get teamName => 'Название команды';

  @override
  String get create => 'Создать';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить версию';

  @override
  String get saved => 'Сохранено локально';

  @override
  String get name => 'Имя';

  @override
  String get title => 'Название';

  @override
  String get notes => 'Заметки';

  @override
  String get addMap => 'Добавить карту';

  @override
  String get addMember => 'Добавить участника';

  @override
  String get newStrategy => 'Новая тактика';

  @override
  String get newTask => 'Новое задание';

  @override
  String get noTeams => 'Подготовка команды начинается здесь';

  @override
  String get noTeamsBody =>
      'Войди через Steam или Discord, создай команду или прими приглашение. Тактики команды синхронизируются между участниками.';

  @override
  String get emptyMaps =>
      'Карт пока нет. Добавьте карту по названию, затем импортируйте собственное изображение радара.';

  @override
  String get emptyStrategies =>
      'Тактик пока нет. Добавьте карту, чтобы начать подготовку раунда.';

  @override
  String get emptyTasks =>
      'Заданий пока нет. Создайте задание или назначьте его из тактики.';

  @override
  String get emptyMembers =>
      'Добавьте игроков и их игровые роли в локальный состав.';

  @override
  String get emptyDemos =>
      'Демок пока нет. Импортируйте собственный файл CS2 .dem в локальную библиотеку.';

  @override
  String get selectMap => 'Карта';

  @override
  String get side => 'Сторона';

  @override
  String get role => 'Роль доступа';

  @override
  String get gameRole => 'Игровая роль';

  @override
  String get owner => 'Владелец';

  @override
  String get captain => 'Капитан';

  @override
  String get coach => 'Тренер';

  @override
  String get player => 'Игрок';

  @override
  String get viewer => 'Наблюдатель';

  @override
  String get todo => 'К выполнению';

  @override
  String get submitted => 'На проверке';

  @override
  String get approved => 'Подтверждено';

  @override
  String get submit => 'Отправить на проверку';

  @override
  String get approve => 'Подтвердить';

  @override
  String get returnTask => 'Вернуть в работу';

  @override
  String get assignee => 'Исполнитель';

  @override
  String get unassigned => 'Не назначен';

  @override
  String get strategyLink => 'Связанная тактика';

  @override
  String get noLink => 'Без тактики';

  @override
  String get openStrategy => 'Открыть тактику';

  @override
  String get back => 'Назад';

  @override
  String get importRadar => 'Импортировать радар';

  @override
  String get radarHelp =>
      'Импортируйте собственный радар PNG или JPEG. Объекты привязаны к изображению. Калибровка игровых координат пока недоступна.';

  @override
  String get invalidImage =>
      'Выберите корректное изображение PNG или JPEG размером до 20 МБ.';

  @override
  String get marker => 'Позиция игрока';

  @override
  String get smoke => 'Дым';

  @override
  String get flash => 'Световая';

  @override
  String get molotov => 'Молотов';

  @override
  String get arrow => 'Перемещение';

  @override
  String get undo => 'Отменить';

  @override
  String get redo => 'Повторить';

  @override
  String get clear => 'Очистить объекты';

  @override
  String get history => 'История версий';

  @override
  String get restore => 'Восстановить новой версией';

  @override
  String version(int number) {
    return 'Версия $number';
  }

  @override
  String get unsaved => 'Есть несохранённые изменения';

  @override
  String get leaveTitle => 'Сохранить изменения?';

  @override
  String get discard => 'Не сохранять';

  @override
  String get stay => 'Продолжить редактирование';

  @override
  String get language => 'Язык интерфейса';

  @override
  String get storage => 'Каталог данных';

  @override
  String get stageNotice =>
      'Ранняя сборка с локальной подготовкой и подключаемыми онлайн-аккаунтами. Совместное редактирование, разбор демок, расписание и управление серверами ещё разрабатываются.';

  @override
  String get importDemo => 'Импортировать .dem';

  @override
  String get demoNotice =>
      'Файлы копируются на это устройство. Парсинг, воспроизведение и запуск CS2 в этой сборке пока недоступны.';

  @override
  String get invalidDemo =>
      'Файл не является поддерживаемой демкой CS2 (PBDEMS2) или превышает лимит импорта 2 ГБ.';

  @override
  String get fileMissing =>
      'Локальный файл отсутствует. Импортируйте его повторно.';

  @override
  String get imported => 'Файл импортирован';

  @override
  String get error =>
      'Не удалось выполнить действие. Существующие данные сохранены.';

  @override
  String get invalidText =>
      'Введите значение в пределах ограничения длины поля.';

  @override
  String get conflict =>
      'Тактика уже изменена. Откройте её заново перед сохранением; сохраните копию своих заметок.';

  @override
  String get startupError =>
      'Не удалось открыть локальную базу. Проверьте свободное место и доступ к папке, затем повторите попытку. Существующие данные не сброшены.';

  @override
  String get retry => 'Повторить';

  @override
  String get localRoles =>
      'Роли состава — локальные данные. Серверная проверка прав появится вместе с онлайн-командами.';

  @override
  String get preparation => 'Подготовка';

  @override
  String get readiness => 'Выполнение заданий';

  @override
  String get noData => 'Нет данных';

  @override
  String get readinessDetail =>
      'Подтверждённые задания из всех локальных заданий. Подтверждение навыков и взвешенная готовность карт пока не рассчитываются.';

  @override
  String get nextSteps => 'Подготовьте следующую тренировку';

  @override
  String get nextStepsBody =>
      'Добавьте карты команды, запишите тактику и распределите обязанности. Все текущие материалы доступны офлайн на этом устройстве.';

  @override
  String teamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
      zero: 'Нет участников',
    );
    return '$_temp0';
  }

  @override
  String taskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задания',
      many: '$count заданий',
      few: '$count задания',
      one: '$count задание',
      zero: 'Нет заданий',
    );
    return '$_temp0';
  }

  @override
  String get imageRequired =>
      'Импортируйте радар, чтобы размещать тактические объекты.';

  @override
  String get selectTeam => 'Сменить команду';

  @override
  String fileSize(String size) {
    return '$size МБ';
  }

  @override
  String objectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count объекта',
      many: '$count объектов',
      few: '$count объекта',
      one: '$count объект',
      zero: 'Нет объектов',
    );
    return '$_temp0';
  }

  @override
  String get tipArrow =>
      'Потяните, чтобы нарисовать стрелку. Остальные объекты ставятся нажатием.';

  @override
  String get taskDetails => 'Описание задания';

  @override
  String get exportPdf => 'Экспортировать PDF-плейбук';

  @override
  String get exportLanguage => 'Язык плейбука';

  @override
  String get pdfHelp =>
      'Экспорт всех текущих тактик и связанных заданий. Ваш контент останется на исходном языке. Радар включает тактические объекты.';

  @override
  String get backup => 'Экспортировать офлайн-пакет';

  @override
  String get backupHelp =>
      'Состав, карты, изображения радаров, тактики и задания этой команды. Исходные демки и внешние видео не включаются. Максимальный размер пакета: 100 МБ.';

  @override
  String get restorePackage => 'Импортировать офлайн-пакет';

  @override
  String get packageError =>
      'Некорректный, неполный или слишком большой офлайн-пакет. Существующие команды не изменены.';

  @override
  String get packageImported =>
      'Пакет импортирован как новая локальная команда';

  @override
  String get exported => 'Экспорт сохранён';

  @override
  String get onlineAccount => 'Онлайн-аккаунт';

  @override
  String get accountHelp =>
      'Войди через Steam или Discord, чтобы работать с общими тактиками своей команды. Пароли вводятся только на странице провайдера.';

  @override
  String get serverAddress => 'Адрес API TeamSync';

  @override
  String get connect => 'Подключить';

  @override
  String get connectionError =>
      'Не удалось подключиться или выполнить запрос. Проверьте адрес сервера, сеть и настройку сервера.';

  @override
  String get invalidServer =>
      'Укажите HTTPS-адрес сервера без пути или http://127.0.0.1:8000 для локальной разработки.';

  @override
  String get providerNotConfigured =>
      'Этот способ входа ещё не настроен на сервере.';

  @override
  String get sessionExpired => 'Сессия истекла или отозвана. Войдите заново.';

  @override
  String get loginTimeout =>
      'Время ожидания входа истекло. Попробуйте ещё раз.';

  @override
  String get loginCancelled => 'Вход отменён.';

  @override
  String get reauthenticate =>
      'Войдите заново перед изменением привязанных аккаунтов.';

  @override
  String get lastIdentity =>
      'Привяжите другой способ входа перед отвязкой последнего.';

  @override
  String get loginComplete =>
      'Можно вернуться в TeamSync. Вход завершится в приложении.';

  @override
  String get signInSteam => 'Войти через Steam';

  @override
  String get signInDiscord => 'Войти через Discord';

  @override
  String get signOut => 'Выйти';

  @override
  String get refresh => 'Обновить';

  @override
  String get onlineTeams => 'Онлайн-команды';

  @override
  String get onlineTeamsHelp =>
      'Выбери команду, чтобы пригласить игроков и открыть общую библиотеку тактик.';

  @override
  String get joinTeam => 'Вступить по коду';

  @override
  String get inviteCode => 'Код приглашения';

  @override
  String get inviteExpiry =>
      'Одноразовое приглашение игрока. Действует 24 часа.';

  @override
  String get inviteMember => 'Пригласить игрока';

  @override
  String get activeDevices => 'Активные устройства';

  @override
  String get revokeSession => 'Завершить сессию';

  @override
  String get linkProvider => 'Привязать аккаунт';

  @override
  String get unlinkProvider => 'Отвязать аккаунт';

  @override
  String get catalog => 'Каталог';

  @override
  String get library => 'Моя библиотека';

  @override
  String get downloads => 'Загрузки';

  @override
  String get favorites => 'Избранное';

  @override
  String get mapsReady => 'Карты уже готовы к работе';

  @override
  String get mapsReadyBody =>
      'Радары, уровни и обложки включены в приложение. Выберите карту и начните подготовку.';

  @override
  String get workspaceLabel => 'КОМАНДНОЕ ПРОСТРАНСТВО';

  @override
  String get gameLibrary => 'БИБЛИОТЕКА CS2';

  @override
  String get searchWorkspace => 'Поиск в разделе…';

  @override
  String get recentStrategies => 'Последние тактики';

  @override
  String get openMap => 'Открыть карту';

  @override
  String get readyOffline => 'Доступно офлайн';

  @override
  String get yourMapPool => 'Карты команды';

  @override
  String get allMaps => 'Все карты';

  @override
  String get upperLevel => 'Верхний уровень';

  @override
  String get lowerLevel => 'Нижний уровень';

  @override
  String get chooseLevel => 'Уровень карты';

  @override
  String get customMap => 'Своя карта';

  @override
  String get versionedRadar => 'Радар с привязкой координат';

  @override
  String get libraryDescription =>
      'Записи матчей, реальные события и подготовленные разборы — в одной библиотеке.';

  @override
  String get importArchive => 'Импортировать демо или архив';

  @override
  String get importLink => 'Загрузить по ссылке';

  @override
  String get sourcePage => 'Страница матча HLTV — необязательно';

  @override
  String get downloadUrl => 'Прямая HTTPS-ссылка на демо или архив';

  @override
  String get importSourceHelp =>
      'Скачайте демку на странице матча HLTV и импортируйте .rar, .zip или .dem. Либо вставьте прямую ссылку на файл. Ссылка матча сохраняется как источник.';

  @override
  String get hltvStatus => 'HLTV · импорт из источника';

  @override
  String get hltvManual =>
      'Откройте матч, скачайте запись, затем импортируйте её. Парсер извлекает состав, карту, раунды и события из самого файла. Автоматический каталог HLTV не подключён.';

  @override
  String get openHLTV => 'Открыть HLTV';

  @override
  String get sourceBlocked =>
      'Источник ограничил автоматическую загрузку. Откройте ссылку в браузере, скачайте файл и импортируйте архив.';

  @override
  String get openSource => 'Открыть источник';

  @override
  String get analyzeDemo => 'Проанализировать';

  @override
  String get watchReview => 'Смотреть разбор';

  @override
  String get parsed => 'Разбор готов';

  @override
  String get notAnalyzed => 'Не проанализировано';

  @override
  String get parserMissing =>
      'Модуль анализа не найден. Установите полную Windows-сборку TeamSync.';

  @override
  String get desktopParser =>
      'Большие демки анализируются на ПК. Здесь можно импортировать подготовленный файл .teamsync-review и посмотреть 2D-разбор.';

  @override
  String get parseFailed =>
      'Не удалось разобрать запись. Файл может быть повреждён или записан несовместимой версией CS2.';

  @override
  String get unsafeArchive =>
      'Архив отклонён: небезопасные пути, пароль или превышение лимитов.';

  @override
  String get unsafeDownload =>
      'Используйте публичную HTTPS-ссылку на файл. Локальные и служебные адреса не принимаются.';

  @override
  String get parseTimeout =>
      'Анализ превысил лимит времени. Попробуйте отдельную карту вместо большого архива.';

  @override
  String get jobStarting => 'Подготовка импорта';

  @override
  String get jobDownload => 'Загрузка файла';

  @override
  String get jobExtract => 'Распаковка архива';

  @override
  String get jobParse => 'Анализ записи';

  @override
  String get jobPositions => 'Чтение позиций игроков';

  @override
  String get jobEvents => 'Чтение событий';

  @override
  String get jobIndex => 'Подготовка воспроизведения';

  @override
  String get jobComplete => 'Готово';

  @override
  String get jobCancelled => 'Операция отменена';

  @override
  String get noDownloads => 'Активных загрузок нет';

  @override
  String get measuredData => 'Измеренные позиции · тренерский обзор';

  @override
  String get sampledPlayback =>
      'Движение сглаживается между записанными снимками. Это визуальное приближение; события и заметки привязаны к тикам, переносы между раундами не сглаживаются.';

  @override
  String get radarRevisionNotice =>
      'Используется версия радара из набора приложения. Геометрия старой записи может отличаться.';

  @override
  String get play => 'Воспроизвести';

  @override
  String get pause => 'Пауза';

  @override
  String get nextFrame => 'Следующий снимок';

  @override
  String get previousFrame => 'Предыдущий снимок';

  @override
  String get roundLabel => 'Раунд';

  @override
  String get players => 'Игроки';

  @override
  String get events => 'События';

  @override
  String get allSides => 'Обе стороны';

  @override
  String get annotations => 'Заметки разбора';

  @override
  String get addAnnotation => 'Добавить заметку';

  @override
  String get createTaskFromNote => 'Задание из заметки';

  @override
  String get exportReview => 'Отправить разбор на телефон';

  @override
  String get reviewDataInvalid => 'Некорректный файл разбора';

  @override
  String get noCalibration =>
      'Для этой карты нет готовой привязки координат. Доступны события и статистика, позиции скрыты.';

  @override
  String get matchDetails => 'Карты и игроки';

  @override
  String get scoreboard => 'Статистика игроков';

  @override
  String get followPlayer => 'Следовать за игроком';

  @override
  String get showTrails => 'Траектории';

  @override
  String get tickLabel => 'Тик';

  @override
  String get killsLabel => 'Убийства';

  @override
  String get deathsLabel => 'Смерти';

  @override
  String get assistsLabel => 'Помощь';

  @override
  String get viewAll => 'Показать все';

  @override
  String get workspaceSubtitle =>
      'Подготовка, которая превращается в командную игру.';

  @override
  String get bombPlanted => 'Бомба установлена';

  @override
  String get bombDefused => 'Бомба обезврежена';

  @override
  String get bombExploded => 'Взрыв бомбы';

  @override
  String get eventPoints =>
      'Гранаты показаны точками событий, без выдуманной формы дыма или огня.';

  @override
  String get playerT => 'Игрок T · янтарный круг';

  @override
  String get playerCT => 'Игрок CT · синий щит';

  @override
  String get playerLegend =>
      'T1–T5 — атака · CT1–CT5 — защита. Нумерация у каждой стороны своя.';

  @override
  String get playbooks => 'Плейбуки / PDF';

  @override
  String get newPlaybook => 'Новый плейбук';

  @override
  String get attachToPlaybook => 'В плейбук / PDF';

  @override
  String get playbookHelp =>
      'Собирайте страницы раундов: план, экономика, роли и снимки тактик. Схема фиксируется при добавлении и не меняется вместе с тактикой.';

  @override
  String get roundPlan => 'План раунда';

  @override
  String get economy => 'Экономика / закуп';

  @override
  String get responsibilities => 'Роли и тайминги';

  @override
  String get addRound => 'Добавить страницу раунда';

  @override
  String get attachTactic => 'Прикрепить схему тактики';

  @override
  String get snapshotSaved => 'Снимок тактики добавлен в плейбук';

  @override
  String get exportDocument => 'Сохранить PDF';

  @override
  String get moveUp => 'Выше';

  @override
  String get moveDown => 'Ниже';

  @override
  String get removePage => 'Удалить страницу';

  @override
  String get removeAttachment => 'Убрать схему';

  @override
  String get bootcamp => 'Буткемп';

  @override
  String get bootcampHelp =>
      'Установите CS2 и TeamSpeak прямо здесь, подключите MatchZy и запускайте локальные серверы кнопкой.';

  @override
  String get csExecutable => 'Выбрать cs2.exe';

  @override
  String get tsExecutable => 'Выбрать ts3server.exe';

  @override
  String get steamExecutable => 'Выбрать steam.exe';

  @override
  String get startBoth => 'Запустить CS2 + TeamSpeak';

  @override
  String get startServer => 'Запустить';

  @override
  String get stopServer => 'Остановить';

  @override
  String get restartServer => 'Перезапустить';

  @override
  String get connectServer => 'Подключиться';

  @override
  String get serverStopped => 'Остановлен';

  @override
  String get serverStarting => 'Процесс запущен · проверяется порт';

  @override
  String get serverReady => 'LAN-порт отвечает';

  @override
  String get serverFailed => 'Процесс завершился';

  @override
  String get chooseExecutables =>
      'Сначала выберите существующие серверные файлы.';

  @override
  String get serverProfile => 'Профиль CS2';

  @override
  String get practiceProfile => 'Тренировка';

  @override
  String get scrimProfile => 'PUG / scrim · MatchZy';

  @override
  String get bootcampLimits =>
      'CS2 и TS3 скачиваются отдельными компонентами в выбранную папку. Лицензию TS3 нужно принять после чтения. PUG и расширенная тренировка используют MatchZy. Интернет-доступ не проверяется; firewall не меняется.';

  @override
  String get getTeamspeak => 'Скачать сервер TeamSpeak';

  @override
  String get serverLog => 'Журнал процессов';

  @override
  String get serverPort => 'Порт CS2';

  @override
  String get lanAddress => 'LAN-адреса этого ПК';

  @override
  String get localHostOnly => 'Запуск серверов доступен на Windows';

  @override
  String get openInCS => 'Открыть в CS2';

  @override
  String get csLaunchHelp =>
      'Steam запускает демку. Если CS2 уже открыт, закройте игру и нажмите ещё раз либо вставьте скопированную команду в консоль.';

  @override
  String get csLaunchError =>
      'Не удалось открыть демку. Проверьте пути CS2 и Steam в разделе «Буткемп» и наличие исходного DEM.';

  @override
  String get scouting => 'Разметка матча';

  @override
  String get scoutingHelp =>
      'Команды, турнир, тир и роли отмечает тренер. Позиции указывайте в контексте карты и стороны; это не официальные роли HLTV.';

  @override
  String get matchTeams => 'Команды (через запятую)';

  @override
  String get tournament => 'Турнир';

  @override
  String get tournamentTier => 'Тир турнира';

  @override
  String get playerPositions =>
      'Позиции / роли (по строке: игрок — сторона — позиция)';

  @override
  String get filterTeam => 'Команда';

  @override
  String get filterPosition => 'Позиция / роль';

  @override
  String get allTiers => 'Все тиры';

  @override
  String get untagged => 'Не размечено';

  @override
  String get hltvInbox => 'Каталог HLTV';

  @override
  String get hltvInboxHelp =>
      'Откройте матч, выберите папку загрузок и скачайте Demo в браузере. TeamSync подхватит новый DEM / RAR / ZIP из этой папки, распакует и добавит в библиотеку. Проверка браузера проходит в самом браузере.';

  @override
  String get watchDownloads => 'Открыть матч и ждать загрузку';

  @override
  String get waitingDownload =>
      'Ожидается новая демка в выбранной папке. Не закрывайте этот раздел.';

  @override
  String get stopWaiting => 'Перестать ждать';

  @override
  String get chooseDownloadFolder => 'Папка загрузок браузера';

  @override
  String get matchPage => 'Ссылка на матч HLTV';

  @override
  String get timelineNotes => 'Метки заметок · нажмите для перехода';

  @override
  String get noteAt => 'Заметка к текущему моменту';

  @override
  String get deleteNote => 'Удалить заметку';

  @override
  String get invalidServerPort => 'Введите порт от 1024 до 65535';

  @override
  String get serverBusy => 'Остановите серверы перед изменением настроек';

  @override
  String get noServerLogs => 'Журнал появится после запуска';

  @override
  String get captureVersion => 'Снимок версии';

  @override
  String get saveDraft => 'Сохранить черновик';

  @override
  String get draftSaved => 'Черновик сохранён';

  @override
  String get tsLicenseHelp =>
      'TeamSpeak: установите сервер отдельно и один раз запустите его вручную, приняв лицензию. Затем выберите ts3server.exe.';

  @override
  String get chooseServerInstallation =>
      'Для сервера и плагинов выберите отдельную установку CS2 Dedicated Server. Клиентская игра используется только для просмотра демок.';

  @override
  String get serverExecutable => 'Сервер: выбрать cs2.exe';

  @override
  String get pluginHelp =>
      'Установка скачивает закреплённые официальные версии, проверяет SHA-256, сохраняет резервные копии и подключает Metamod в gameinfo.gi. Личные конфиги MatchZy сохраняются. После обновления CS2 проверьте загрузку плагина.';

  @override
  String get installPlugin => 'Установить MatchZy и зависимости';

  @override
  String get pluginInstalled =>
      'Файлы MatchZy установлены. Запустите сервер и проверьте статус плагина.';

  @override
  String get pluginInstallFailed =>
      'Установка не завершена. Проверьте путь отдельного сервера, доступ к сети и журнал.';

  @override
  String get pluginCommands =>
      'PUG: .ready / .unready · .pause / .unpause · .stay / .switch.\nТренировка: .prac · .savenade имя · .loadnade имя · .rethrow · .traj · .clear · .bot · .ctspawn 1. Команды вводятся в чат CS2; административные требуют прав.';

  @override
  String get pluginLoaded => 'MatchZy загружен';

  @override
  String get pluginNotVerified => 'Загрузка MatchZy ещё не подтверждена';

  @override
  String get applyPractice => 'Включить тренировку на сервере';

  @override
  String get applyScrim => 'Вернуть PUG-режим';

  @override
  String get pluginCommandFailed =>
      'Команда не подтверждена. Проверьте загрузку MatchZy и журнал сервера.';

  @override
  String get commandSent =>
      'Команда отправлена серверу; результат смотрите в журнале.';

  @override
  String get matchSetup => 'Матч и veto';

  @override
  String get matchSetupHelp =>
      'Введите настоящие SteamID64 игроков. Капитаны проходят veto в CS2, затем ready и knife. При выборе одной карты veto пропускается.';

  @override
  String get steamRoster => 'Состав: SteamID64 и ник, по одному в строке';

  @override
  String get invalidMatchRoster =>
      'Нужны 1–5 уникальных SteamID64 в каждой команде без пересечений. Карт должно хватать на выбранный BO.';

  @override
  String get loadMatch => 'Загрузить матч на сервер';

  @override
  String get refreshCatalog => 'Обновить HLTV';

  @override
  String get catalogPrevious => 'Новее';

  @override
  String get catalogNext => 'Ранее';

  @override
  String get anyStars => 'Любой рейтинг';

  @override
  String get catalogPosition => 'Позиция (моя разметка)';

  @override
  String get catalogFilterHelp =>
      'Поиск — по текущим 100 матчам. Звёзды — оценка матча HLTV, не тир турнира. Тир отмечается тренером у события; позиции берутся из вашей разметки импортированных демок.';

  @override
  String get catalogUpdated => 'Получено:';

  @override
  String get downloadAndAnalyze => 'Скачать и разобрать';

  @override
  String get coachTier => 'Тир · разметка тренера';

  @override
  String get hltvNoDemo => 'На странице этого матча пока нет ссылки Demo.';

  @override
  String get hltvUnavailable =>
      'HLTV не ответил или ограничил запрос. Сохранённый каталог доступен; можно открыть матч в браузере и повторить позднее.';

  @override
  String get hltvRateLimit =>
      'HLTV просит снизить частоту запросов. Каталог из кэша доступен; повторите через несколько минут.';

  @override
  String get hltvBrowserFallback =>
      'Каталог и ссылка получены, но сервер архива ограничил прямую загрузку. Скачайте файл в открывшемся браузере — TeamSync заберёт его из выбранной папки.';

  @override
  String get serverFolder => 'Папка для серверов';

  @override
  String get serverFilesReady => 'Файлы сервера установлены, путь сохранён';

  @override
  String get serverDiskSpace =>
      'Недостаточно места: для первой установки CS2 нужно не менее 110 ГБ свободного места, для обновления — 11 ГБ.';

  @override
  String get serverSetupError =>
      'Установка не завершена. Проверьте место и доступ к папке/сети. Повторная установка CS2 продолжит загрузку SteamCMD. Если официальный архив изменился, потребуется обновление TeamSync.';

  @override
  String get serverContentDownload => 'Загрузка / проверка файлов сервера';

  @override
  String get steamcmdPreparing => 'Подготовка SteamCMD и подключение к Steam';

  @override
  String get downloadServerFiles => 'Установка серверов из TeamSync';

  @override
  String get serverDownloadHelp =>
      'CS2 загружается напрямую через Valve SteamCMD (большая загрузка: примерно 80–100 ГБ; нужно 110 ГБ свободного места). TeamSpeak 3.13.8 — официальный архив, около 9 МБ. Создаётся отдельная папка TeamSyncServers. Серверы сами не запускаются.';

  @override
  String get downloadCsServer => 'Установить / продолжить CS2';

  @override
  String get downloadTsServer => 'Установить TeamSpeak';

  @override
  String get acceptTsLicense => 'Я прочитал и принимаю лицензию TeamSpeak';

  @override
  String get tsLicense => 'Лицензия TeamSpeak';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String get hltvDesktopCatalog =>
      'Каталог HLTV загружается на Windows. На телефоне доступны подготовленные разборы и сайт HLTV в браузере.';

  @override
  String get sourceVerification => 'Подключение и проверка источника HLTV';

  @override
  String get downloadRuntimeMissing =>
      'Не найден компонент загрузок. Повторите установку TeamSync с подключённым интернетом: установщик добавит необходимый компонент Microsoft.';

  @override
  String get managedDownloadFailed =>
      'Загрузка не завершена. Если появилось окно проверки источника, подтвердите доступ и повторите. Проверьте сеть и свободное место.';

  @override
  String get accountId => 'ID аккаунта';

  @override
  String get copyAccountId => 'Скопировать ID аккаунта';

  @override
  String get accountInvite => 'Пригласить по аккаунту';

  @override
  String get accountLookup => 'ID аккаунта игрока';

  @override
  String get acceptInvite => 'Принять';

  @override
  String get declineInvite => 'Отклонить';

  @override
  String get incomingInvites => 'Приглашения в команды';

  @override
  String get outgoingInvites => 'Отправленные приглашения';

  @override
  String get cancelInvite => 'Отозвать приглашение';

  @override
  String get openRoster => 'Открыть состав';

  @override
  String get squad => 'Состав';

  @override
  String get mainSquad => 'Основной состав';

  @override
  String get reserveSquad => 'Запас';

  @override
  String get staffSquad => 'Штаб';

  @override
  String get leaveTeam => 'Покинуть команду';

  @override
  String get removePlayer => 'Удалить из состава';

  @override
  String get accountNotFound =>
      'Аккаунт не найден. Попроси игрока скопировать свой ID в профиле.';

  @override
  String get inviteInvalid => 'Приглашение истекло или отозвано.';

  @override
  String get alreadyMember => 'Этот аккаунт уже в команде.';

  @override
  String get accessDenied => 'Недостаточно прав для этого действия.';

  @override
  String get writeConflict =>
      'Приглашение уже отправлено или данные изменились. Обнови список.';

  @override
  String get ownershipRequired => 'Сначала передай владение другому участнику.';

  @override
  String get confirmAction => 'Подтвердить действие?';

  @override
  String get transferOwner => 'Передать владение';

  @override
  String get openInWorkspace => 'Открыть общие тактики';

  @override
  String get rosterLocalHelp =>
      'Открой общие тактики команды на этом устройстве. Схемы и заметки синхронизируются между ПК и телефоном.';

  @override
  String get editProfile => 'Изменить имя';

  @override
  String get serverWaking =>
      'Подключение к серверу. После простоя бесплатный сервер может запускаться около минуты.';

  @override
  String get accountTeamHelp =>
      'Пригласи игрока по ID его аккаунта. Он увидит приглашение в профиле и сам подтвердит вступление.';

  @override
  String get accountRosterManaged => 'Управлять составом по аккаунтам';

  @override
  String get copied => 'Скопировано';

  @override
  String get inviteSent => 'Приглашение отправлено';

  @override
  String get syncTactics => 'Общие тактики';

  @override
  String get syncNow => 'Синхронизировать';

  @override
  String get syncWorking => 'Синхронизация…';

  @override
  String get syncReady => 'Тактики синхронизированы';

  @override
  String get syncOffline =>
      'Нет связи. Изменения сохранены на устройстве и будут отправлены после подключения.';

  @override
  String get syncConflict =>
      'Сохранены обе версии. Проверь копию конфликта в тактиках.';

  @override
  String get syncConflictCopy => 'Конфликтная копия';

  @override
  String get syncAccountMismatch =>
      'Войди в аккаунт, к которому привязана эта команда.';

  @override
  String get readOnlyTeam =>
      'Твоя роль позволяет просматривать общие тактики. Изменять их могут владелец, капитан и тренер.';

  @override
  String get syncTeamHelp =>
      'Тактики, схемы на картах и заметки общие для всей онлайн-команды. Сохранённые правки отправляются автоматически; без связи остаются на устройстве.';

  @override
  String get linkWorkspace => 'Подключить общие тактики';

  @override
  String get newSharedWorkspace => 'Новая рабочая область';

  @override
  String get linkTeamExplain =>
      'Выбери рабочую область. Её тактики станут общими для этой команды; правки участников будут загружаться сюда.';

  @override
  String get syncAccessLost =>
      'Доступ к команде отозван. Локальные материалы сохранены, синхронизация остановлена.';

  @override
  String get utilityLibrary => 'Раскидки';

  @override
  String get newUtility => 'Новая раскидка';

  @override
  String get editUtility => 'Изменить раскидку';

  @override
  String get utilityInstruction => 'Инструкция и тайминг';

  @override
  String get utilitySource => 'Ссылка YouTube / CS2Tricks';

  @override
  String get utilitySourceHelp =>
      'Источник открывается в оригинале. Если видео недоступно, используйте сохранённую инструкцию. Медиа внешнего сайта не скачиваются.';

  @override
  String get utilityEmpty =>
      'Добавьте командную раскидку: карту, позицию, инструкцию и источник.';

  @override
  String get utilityGrenade => 'Тип гранаты';

  @override
  String get utilityStart => 'Начальная позиция';

  @override
  String get utilityTarget => 'Цель';

  @override
  String get utilityThrow => 'Тип броска';

  @override
  String get utilityAuthor => 'Автор оригинала';

  @override
  String get utilityVerified => 'Проверено, дата ISO';

  @override
  String get utilityRevision => 'Версия карты';

  @override
  String get utilityOpen => 'Открыть оригинал';

  @override
  String get utilityUnavailable =>
      'Не удалось открыть источник. Инструкция остаётся доступной.';

  @override
  String get utilityInvalidSource =>
      'Разрешены HTTPS-ссылки YouTube и CS2Tricks без логина и пароля.';

  @override
  String get grenadeHe => 'Осколочная';

  @override
  String get grenadeDecoy => 'Ложная';

  @override
  String get editMaterial => 'Изменить';

  @override
  String get utilityTactics => 'Связанные тактики';

  @override
  String get utilityScreenshots => 'Скриншоты прицеливания';

  @override
  String get utilityAddImage => 'Своё изображение';

  @override
  String get utilityRemoveImage => 'Убрать изображение';

  @override
  String get syncReadOnlyPending =>
      'Локальные правки сохранены. Текущая роль не разрешает их отправку.';

  @override
  String get syncMediaQuota => 'Лимит вложений команды исчерпан.';

  @override
  String get utilityVideo => 'Свой видеоклип';

  @override
  String get utilityAddVideo => 'Добавить свой MP4';

  @override
  String get utilityOpenVideo => 'Смотреть клип';

  @override
  String get utilityShareVideo => 'Отправить файл';

  @override
  String get utilityRemoveVideo => 'Убрать клип';

  @override
  String get utilityVideoLimit =>
      'Свой MP4 до 20 МБ. Клип синхронизируется с командой и сохраняется для офлайн-просмотра.';

  @override
  String get invalidVideo => 'Выберите MP4 с видеодорожкой размером до 20 МБ.';

  @override
  String get videoUnavailable =>
      'Не удалось открыть клип. Выберите совместимый проигрыватель через отправку файла.';

  @override
  String get skillTitle => 'Изучение и проверка';

  @override
  String get skillSelf => 'Мой статус';

  @override
  String get skillNotStarted => 'Не изучено';

  @override
  String get skillLearning => 'Изучаю';

  @override
  String get skillReady => 'Готов проверить';

  @override
  String get skillConfirmed => 'Подтверждено';

  @override
  String get skillTeam => 'Проверка состава';

  @override
  String get skillRecheck => 'Нужна повторная проверка';

  @override
  String get skillRequestRecheck => 'Запросить повторную проверку навыков';

  @override
  String get skillReason => 'Причина повторной проверки';

  @override
  String get skillReturnReason => 'Причина возврата на доработку';

  @override
  String get skillConflict => 'Статус изменён на другом устройстве';

  @override
  String get skillKeepRemote => 'Оставить серверный статус';

  @override
  String get skillKeepLocal => 'Отправить мой статус';

  @override
  String get skillPending => 'Сохранено локально';

  @override
  String get skillMaterialChanged =>
      'Раскидка обновилась. Закройте окно и откройте проверку заново.';

  @override
  String get skillEmptyHistory => 'Истории проверок пока нет.';

  @override
  String get skillMember => 'Участник команды';

  @override
  String get skillReasonRequired => 'Укажите причину повторной проверки.';

  @override
  String get taskInProgress => 'В процессе';

  @override
  String get taskStart => 'Начать задание';

  @override
  String get taskReturnReason => 'Причина возврата задания';
}
