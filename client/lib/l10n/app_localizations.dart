import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In ru, this message translates to:
  /// **'TeamSync'**
  String get appName;

  /// No description provided for @overview.
  ///
  /// In ru, this message translates to:
  /// **'Обзор'**
  String get overview;

  /// No description provided for @maps.
  ///
  /// In ru, this message translates to:
  /// **'Карты'**
  String get maps;

  /// No description provided for @strategies.
  ///
  /// In ru, this message translates to:
  /// **'Тактики'**
  String get strategies;

  /// No description provided for @training.
  ///
  /// In ru, this message translates to:
  /// **'Тренировки'**
  String get training;

  /// No description provided for @demos.
  ///
  /// In ru, this message translates to:
  /// **'Демки'**
  String get demos;

  /// No description provided for @team.
  ///
  /// In ru, this message translates to:
  /// **'Состав'**
  String get team;

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @more.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get more;

  /// No description provided for @localWorkspace.
  ///
  /// In ru, this message translates to:
  /// **'Локальная рабочая область'**
  String get localWorkspace;

  /// No description provided for @localNotice.
  ///
  /// In ru, this message translates to:
  /// **'Нужен аккаунт. Старые материалы сохранены: их можно привязать к онлайн-команде в разделе аккаунта.'**
  String get localNotice;

  /// No description provided for @createTeam.
  ///
  /// In ru, this message translates to:
  /// **'Создать команду'**
  String get createTeam;

  /// No description provided for @teamName.
  ///
  /// In ru, this message translates to:
  /// **'Название команды'**
  String get teamName;

  /// No description provided for @create.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить версию'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено локально'**
  String get saved;

  /// No description provided for @name.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get name;

  /// No description provided for @title.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get title;

  /// No description provided for @notes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get notes;

  /// No description provided for @addMap.
  ///
  /// In ru, this message translates to:
  /// **'Добавить карту'**
  String get addMap;

  /// No description provided for @addMember.
  ///
  /// In ru, this message translates to:
  /// **'Добавить участника'**
  String get addMember;

  /// No description provided for @newStrategy.
  ///
  /// In ru, this message translates to:
  /// **'Новая тактика'**
  String get newStrategy;

  /// No description provided for @newTask.
  ///
  /// In ru, this message translates to:
  /// **'Новое задание'**
  String get newTask;

  /// No description provided for @noTeams.
  ///
  /// In ru, this message translates to:
  /// **'Подготовка команды начинается здесь'**
  String get noTeams;

  /// No description provided for @noTeamsBody.
  ///
  /// In ru, this message translates to:
  /// **'Войди через Steam или Discord, создай команду или прими приглашение. Тактики команды синхронизируются между участниками.'**
  String get noTeamsBody;

  /// No description provided for @emptyMaps.
  ///
  /// In ru, this message translates to:
  /// **'Карт пока нет. Добавьте карту по названию, затем импортируйте собственное изображение радара.'**
  String get emptyMaps;

  /// No description provided for @emptyStrategies.
  ///
  /// In ru, this message translates to:
  /// **'Тактик пока нет. Добавьте карту, чтобы начать подготовку раунда.'**
  String get emptyStrategies;

  /// No description provided for @emptyTasks.
  ///
  /// In ru, this message translates to:
  /// **'Заданий пока нет. Создайте задание или назначьте его из тактики.'**
  String get emptyTasks;

  /// No description provided for @emptyMembers.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте игроков и их игровые роли в локальный состав.'**
  String get emptyMembers;

  /// No description provided for @emptyDemos.
  ///
  /// In ru, this message translates to:
  /// **'Демок пока нет. Импортируйте собственный файл CS2 .dem в локальную библиотеку.'**
  String get emptyDemos;

  /// No description provided for @selectMap.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get selectMap;

  /// No description provided for @side.
  ///
  /// In ru, this message translates to:
  /// **'Сторона'**
  String get side;

  /// No description provided for @role.
  ///
  /// In ru, this message translates to:
  /// **'Роль доступа'**
  String get role;

  /// No description provided for @gameRole.
  ///
  /// In ru, this message translates to:
  /// **'Игровая роль'**
  String get gameRole;

  /// No description provided for @owner.
  ///
  /// In ru, this message translates to:
  /// **'Владелец'**
  String get owner;

  /// No description provided for @captain.
  ///
  /// In ru, this message translates to:
  /// **'Капитан'**
  String get captain;

  /// No description provided for @coach.
  ///
  /// In ru, this message translates to:
  /// **'Тренер'**
  String get coach;

  /// No description provided for @player.
  ///
  /// In ru, this message translates to:
  /// **'Игрок'**
  String get player;

  /// No description provided for @viewer.
  ///
  /// In ru, this message translates to:
  /// **'Наблюдатель'**
  String get viewer;

  /// No description provided for @todo.
  ///
  /// In ru, this message translates to:
  /// **'К выполнению'**
  String get todo;

  /// No description provided for @submitted.
  ///
  /// In ru, this message translates to:
  /// **'На проверке'**
  String get submitted;

  /// No description provided for @approved.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждено'**
  String get approved;

  /// No description provided for @submit.
  ///
  /// In ru, this message translates to:
  /// **'Отправить на проверку'**
  String get submit;

  /// No description provided for @approve.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get approve;

  /// No description provided for @returnTask.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть в работу'**
  String get returnTask;

  /// No description provided for @assignee.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель'**
  String get assignee;

  /// No description provided for @unassigned.
  ///
  /// In ru, this message translates to:
  /// **'Не назначен'**
  String get unassigned;

  /// No description provided for @strategyLink.
  ///
  /// In ru, this message translates to:
  /// **'Связанная тактика'**
  String get strategyLink;

  /// No description provided for @noLink.
  ///
  /// In ru, this message translates to:
  /// **'Без тактики'**
  String get noLink;

  /// No description provided for @openStrategy.
  ///
  /// In ru, this message translates to:
  /// **'Открыть тактику'**
  String get openStrategy;

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @importRadar.
  ///
  /// In ru, this message translates to:
  /// **'Импортировать радар'**
  String get importRadar;

  /// No description provided for @radarHelp.
  ///
  /// In ru, this message translates to:
  /// **'Импортируйте собственный радар PNG или JPEG. Объекты привязаны к изображению. Калибровка игровых координат пока недоступна.'**
  String get radarHelp;

  /// No description provided for @invalidImage.
  ///
  /// In ru, this message translates to:
  /// **'Выберите корректное изображение PNG или JPEG размером до 20 МБ.'**
  String get invalidImage;

  /// No description provided for @marker.
  ///
  /// In ru, this message translates to:
  /// **'Позиция игрока'**
  String get marker;

  /// No description provided for @smoke.
  ///
  /// In ru, this message translates to:
  /// **'Дым'**
  String get smoke;

  /// No description provided for @flash.
  ///
  /// In ru, this message translates to:
  /// **'Световая'**
  String get flash;

  /// No description provided for @molotov.
  ///
  /// In ru, this message translates to:
  /// **'Молотов'**
  String get molotov;

  /// No description provided for @arrow.
  ///
  /// In ru, this message translates to:
  /// **'Перемещение'**
  String get arrow;

  /// No description provided for @undo.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get redo;

  /// No description provided for @clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить объекты'**
  String get clear;

  /// No description provided for @history.
  ///
  /// In ru, this message translates to:
  /// **'История версий'**
  String get history;

  /// No description provided for @restore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить новой версией'**
  String get restore;

  /// No description provided for @version.
  ///
  /// In ru, this message translates to:
  /// **'Версия {number}'**
  String version(int number);

  /// No description provided for @unsaved.
  ///
  /// In ru, this message translates to:
  /// **'Есть несохранённые изменения'**
  String get unsaved;

  /// No description provided for @leaveTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить изменения?'**
  String get leaveTitle;

  /// No description provided for @discard.
  ///
  /// In ru, this message translates to:
  /// **'Не сохранять'**
  String get discard;

  /// No description provided for @stay.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить редактирование'**
  String get stay;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык интерфейса'**
  String get language;

  /// No description provided for @storage.
  ///
  /// In ru, this message translates to:
  /// **'Каталог данных'**
  String get storage;

  /// No description provided for @stageNotice.
  ///
  /// In ru, this message translates to:
  /// **'Ранняя сборка с локальной подготовкой и подключаемыми онлайн-аккаунтами. Совместное редактирование, разбор демок, расписание и управление серверами ещё разрабатываются.'**
  String get stageNotice;

  /// No description provided for @importDemo.
  ///
  /// In ru, this message translates to:
  /// **'Импортировать .dem'**
  String get importDemo;

  /// No description provided for @demoNotice.
  ///
  /// In ru, this message translates to:
  /// **'Файлы копируются на это устройство. Парсинг, воспроизведение и запуск CS2 в этой сборке пока недоступны.'**
  String get demoNotice;

  /// No description provided for @invalidDemo.
  ///
  /// In ru, this message translates to:
  /// **'Файл не является поддерживаемой демкой CS2 (PBDEMS2) или превышает лимит импорта 2 ГБ.'**
  String get invalidDemo;

  /// No description provided for @fileMissing.
  ///
  /// In ru, this message translates to:
  /// **'Локальный файл отсутствует. Импортируйте его повторно.'**
  String get fileMissing;

  /// No description provided for @imported.
  ///
  /// In ru, this message translates to:
  /// **'Файл импортирован'**
  String get imported;

  /// No description provided for @error.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить действие. Существующие данные сохранены.'**
  String get error;

  /// No description provided for @invalidText.
  ///
  /// In ru, this message translates to:
  /// **'Введите значение в пределах ограничения длины поля.'**
  String get invalidText;

  /// No description provided for @conflict.
  ///
  /// In ru, this message translates to:
  /// **'Тактика уже изменена. Откройте её заново перед сохранением; сохраните копию своих заметок.'**
  String get conflict;

  /// No description provided for @startupError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть локальную базу. Проверьте свободное место и доступ к папке, затем повторите попытку. Существующие данные не сброшены.'**
  String get startupError;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @localRoles.
  ///
  /// In ru, this message translates to:
  /// **'Роли состава — локальные данные. Серверная проверка прав появится вместе с онлайн-командами.'**
  String get localRoles;

  /// No description provided for @preparation.
  ///
  /// In ru, this message translates to:
  /// **'Подготовка'**
  String get preparation;

  /// No description provided for @readiness.
  ///
  /// In ru, this message translates to:
  /// **'Выполнение заданий'**
  String get readiness;

  /// No description provided for @noData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get noData;

  /// No description provided for @readinessDetail.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждённые задания из всех локальных заданий. Подтверждение навыков и взвешенная готовность карт пока не рассчитываются.'**
  String get readinessDetail;

  /// No description provided for @nextSteps.
  ///
  /// In ru, this message translates to:
  /// **'Подготовьте следующую тренировку'**
  String get nextSteps;

  /// No description provided for @nextStepsBody.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте карты команды, запишите тактику и распределите обязанности. Все текущие материалы доступны офлайн на этом устройстве.'**
  String get nextStepsBody;

  /// No description provided for @teamCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Нет участников} one{{count} участник} few{{count} участника} many{{count} участников} other{{count} участника}}'**
  String teamCount(int count);

  /// No description provided for @taskCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Нет заданий} one{{count} задание} few{{count} задания} many{{count} заданий} other{{count} задания}}'**
  String taskCount(int count);

  /// No description provided for @imageRequired.
  ///
  /// In ru, this message translates to:
  /// **'Импортируйте радар, чтобы размещать тактические объекты.'**
  String get imageRequired;

  /// No description provided for @selectTeam.
  ///
  /// In ru, this message translates to:
  /// **'Сменить команду'**
  String get selectTeam;

  /// No description provided for @fileSize.
  ///
  /// In ru, this message translates to:
  /// **'{size} МБ'**
  String fileSize(String size);

  /// No description provided for @objectCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Нет объектов} one{{count} объект} few{{count} объекта} many{{count} объектов} other{{count} объекта}}'**
  String objectCount(int count);

  /// No description provided for @tipArrow.
  ///
  /// In ru, this message translates to:
  /// **'Потяните, чтобы нарисовать стрелку. Остальные объекты ставятся нажатием.'**
  String get tipArrow;

  /// No description provided for @taskDetails.
  ///
  /// In ru, this message translates to:
  /// **'Описание задания'**
  String get taskDetails;

  /// No description provided for @exportPdf.
  ///
  /// In ru, this message translates to:
  /// **'Экспортировать PDF-плейбук'**
  String get exportPdf;

  /// No description provided for @exportLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык плейбука'**
  String get exportLanguage;

  /// No description provided for @pdfHelp.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт всех текущих тактик и связанных заданий. Ваш контент останется на исходном языке. Радар включает тактические объекты.'**
  String get pdfHelp;

  /// No description provided for @backup.
  ///
  /// In ru, this message translates to:
  /// **'Экспортировать офлайн-пакет'**
  String get backup;

  /// No description provided for @backupHelp.
  ///
  /// In ru, this message translates to:
  /// **'Состав, карты, изображения радаров, тактики и задания этой команды. Исходные демки и внешние видео не включаются. Максимальный размер пакета: 100 МБ.'**
  String get backupHelp;

  /// No description provided for @restorePackage.
  ///
  /// In ru, this message translates to:
  /// **'Импортировать офлайн-пакет'**
  String get restorePackage;

  /// No description provided for @packageError.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный, неполный или слишком большой офлайн-пакет. Существующие команды не изменены.'**
  String get packageError;

  /// No description provided for @packageImported.
  ///
  /// In ru, this message translates to:
  /// **'Пакет импортирован как новая локальная команда'**
  String get packageImported;

  /// No description provided for @exported.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт сохранён'**
  String get exported;

  /// No description provided for @onlineAccount.
  ///
  /// In ru, this message translates to:
  /// **'Онлайн-аккаунт'**
  String get onlineAccount;

  /// No description provided for @accountHelp.
  ///
  /// In ru, this message translates to:
  /// **'Войди через Steam или Discord, чтобы работать с общими тактиками своей команды. Пароли вводятся только на странице провайдера.'**
  String get accountHelp;

  /// No description provided for @serverAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес API TeamSync'**
  String get serverAddress;

  /// No description provided for @connect.
  ///
  /// In ru, this message translates to:
  /// **'Подключить'**
  String get connect;

  /// No description provided for @connectionError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подключиться или выполнить запрос. Проверьте адрес сервера, сеть и настройку сервера.'**
  String get connectionError;

  /// No description provided for @invalidServer.
  ///
  /// In ru, this message translates to:
  /// **'Укажите HTTPS-адрес сервера без пути или http://127.0.0.1:8000 для локальной разработки.'**
  String get invalidServer;

  /// No description provided for @providerNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Этот способ входа ещё не настроен на сервере.'**
  String get providerNotConfigured;

  /// No description provided for @sessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла или отозвана. Войдите заново.'**
  String get sessionExpired;

  /// No description provided for @loginTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Время ожидания входа истекло. Попробуйте ещё раз.'**
  String get loginTimeout;

  /// No description provided for @loginCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Вход отменён.'**
  String get loginCancelled;

  /// No description provided for @reauthenticate.
  ///
  /// In ru, this message translates to:
  /// **'Войдите заново перед изменением привязанных аккаунтов.'**
  String get reauthenticate;

  /// No description provided for @lastIdentity.
  ///
  /// In ru, this message translates to:
  /// **'Привяжите другой способ входа перед отвязкой последнего.'**
  String get lastIdentity;

  /// No description provided for @loginComplete.
  ///
  /// In ru, this message translates to:
  /// **'Можно вернуться в TeamSync. Вход завершится в приложении.'**
  String get loginComplete;

  /// No description provided for @signInSteam.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Steam'**
  String get signInSteam;

  /// No description provided for @signInDiscord.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Discord'**
  String get signInDiscord;

  /// No description provided for @signOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get signOut;

  /// No description provided for @refresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get refresh;

  /// No description provided for @onlineTeams.
  ///
  /// In ru, this message translates to:
  /// **'Онлайн-команды'**
  String get onlineTeams;

  /// No description provided for @onlineTeamsHelp.
  ///
  /// In ru, this message translates to:
  /// **'Выбери команду, чтобы пригласить игроков и открыть общую библиотеку тактик.'**
  String get onlineTeamsHelp;

  /// No description provided for @joinTeam.
  ///
  /// In ru, this message translates to:
  /// **'Вступить по коду'**
  String get joinTeam;

  /// No description provided for @inviteCode.
  ///
  /// In ru, this message translates to:
  /// **'Код приглашения'**
  String get inviteCode;

  /// No description provided for @inviteExpiry.
  ///
  /// In ru, this message translates to:
  /// **'Одноразовое приглашение игрока. Действует 24 часа.'**
  String get inviteExpiry;

  /// No description provided for @inviteMember.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить игрока'**
  String get inviteMember;

  /// No description provided for @activeDevices.
  ///
  /// In ru, this message translates to:
  /// **'Активные устройства'**
  String get activeDevices;

  /// No description provided for @revokeSession.
  ///
  /// In ru, this message translates to:
  /// **'Завершить сессию'**
  String get revokeSession;

  /// No description provided for @linkProvider.
  ///
  /// In ru, this message translates to:
  /// **'Привязать аккаунт'**
  String get linkProvider;

  /// No description provided for @unlinkProvider.
  ///
  /// In ru, this message translates to:
  /// **'Отвязать аккаунт'**
  String get unlinkProvider;

  /// No description provided for @catalog.
  ///
  /// In ru, this message translates to:
  /// **'Каталог'**
  String get catalog;

  /// No description provided for @library.
  ///
  /// In ru, this message translates to:
  /// **'Моя библиотека'**
  String get library;

  /// No description provided for @downloads.
  ///
  /// In ru, this message translates to:
  /// **'Загрузки'**
  String get downloads;

  /// No description provided for @favorites.
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get favorites;

  /// No description provided for @mapsReady.
  ///
  /// In ru, this message translates to:
  /// **'Карты уже готовы к работе'**
  String get mapsReady;

  /// No description provided for @mapsReadyBody.
  ///
  /// In ru, this message translates to:
  /// **'Радары, уровни и обложки включены в приложение. Выберите карту и начните подготовку.'**
  String get mapsReadyBody;

  /// No description provided for @workspaceLabel.
  ///
  /// In ru, this message translates to:
  /// **'КОМАНДНОЕ ПРОСТРАНСТВО'**
  String get workspaceLabel;

  /// No description provided for @gameLibrary.
  ///
  /// In ru, this message translates to:
  /// **'БИБЛИОТЕКА CS2'**
  String get gameLibrary;

  /// No description provided for @searchWorkspace.
  ///
  /// In ru, this message translates to:
  /// **'Поиск в разделе…'**
  String get searchWorkspace;

  /// No description provided for @recentStrategies.
  ///
  /// In ru, this message translates to:
  /// **'Последние тактики'**
  String get recentStrategies;

  /// No description provided for @openMap.
  ///
  /// In ru, this message translates to:
  /// **'Открыть карту'**
  String get openMap;

  /// No description provided for @readyOffline.
  ///
  /// In ru, this message translates to:
  /// **'Доступно офлайн'**
  String get readyOffline;

  /// No description provided for @yourMapPool.
  ///
  /// In ru, this message translates to:
  /// **'Карты команды'**
  String get yourMapPool;

  /// No description provided for @allMaps.
  ///
  /// In ru, this message translates to:
  /// **'Все карты'**
  String get allMaps;

  /// No description provided for @upperLevel.
  ///
  /// In ru, this message translates to:
  /// **'Верхний уровень'**
  String get upperLevel;

  /// No description provided for @lowerLevel.
  ///
  /// In ru, this message translates to:
  /// **'Нижний уровень'**
  String get lowerLevel;

  /// No description provided for @chooseLevel.
  ///
  /// In ru, this message translates to:
  /// **'Уровень карты'**
  String get chooseLevel;

  /// No description provided for @customMap.
  ///
  /// In ru, this message translates to:
  /// **'Своя карта'**
  String get customMap;

  /// No description provided for @versionedRadar.
  ///
  /// In ru, this message translates to:
  /// **'Радар с привязкой координат'**
  String get versionedRadar;

  /// No description provided for @libraryDescription.
  ///
  /// In ru, this message translates to:
  /// **'Записи матчей, реальные события и подготовленные разборы — в одной библиотеке.'**
  String get libraryDescription;

  /// No description provided for @importArchive.
  ///
  /// In ru, this message translates to:
  /// **'Импортировать демо или архив'**
  String get importArchive;

  /// No description provided for @importLink.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить по ссылке'**
  String get importLink;

  /// No description provided for @sourcePage.
  ///
  /// In ru, this message translates to:
  /// **'Страница матча HLTV — необязательно'**
  String get sourcePage;

  /// No description provided for @downloadUrl.
  ///
  /// In ru, this message translates to:
  /// **'Прямая HTTPS-ссылка на демо или архив'**
  String get downloadUrl;

  /// No description provided for @importSourceHelp.
  ///
  /// In ru, this message translates to:
  /// **'Скачайте демку на странице матча HLTV и импортируйте .rar, .zip или .dem. Либо вставьте прямую ссылку на файл. Ссылка матча сохраняется как источник.'**
  String get importSourceHelp;

  /// No description provided for @hltvStatus.
  ///
  /// In ru, this message translates to:
  /// **'HLTV · импорт из источника'**
  String get hltvStatus;

  /// No description provided for @hltvManual.
  ///
  /// In ru, this message translates to:
  /// **'Откройте матч, скачайте запись, затем импортируйте её. Парсер извлекает состав, карту, раунды и события из самого файла. Автоматический каталог HLTV не подключён.'**
  String get hltvManual;

  /// No description provided for @openHLTV.
  ///
  /// In ru, this message translates to:
  /// **'Открыть HLTV'**
  String get openHLTV;

  /// No description provided for @sourceBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Источник ограничил автоматическую загрузку. Откройте ссылку в браузере, скачайте файл и импортируйте архив.'**
  String get sourceBlocked;

  /// No description provided for @openSource.
  ///
  /// In ru, this message translates to:
  /// **'Открыть источник'**
  String get openSource;

  /// No description provided for @analyzeDemo.
  ///
  /// In ru, this message translates to:
  /// **'Проанализировать'**
  String get analyzeDemo;

  /// No description provided for @watchReview.
  ///
  /// In ru, this message translates to:
  /// **'Смотреть разбор'**
  String get watchReview;

  /// No description provided for @parsed.
  ///
  /// In ru, this message translates to:
  /// **'Разбор готов'**
  String get parsed;

  /// No description provided for @notAnalyzed.
  ///
  /// In ru, this message translates to:
  /// **'Не проанализировано'**
  String get notAnalyzed;

  /// No description provided for @parserMissing.
  ///
  /// In ru, this message translates to:
  /// **'Модуль анализа не найден. Установите полную Windows-сборку TeamSync.'**
  String get parserMissing;

  /// No description provided for @desktopParser.
  ///
  /// In ru, this message translates to:
  /// **'Большие демки анализируются на ПК. Здесь можно импортировать подготовленный файл .teamsync-review и посмотреть 2D-разбор.'**
  String get desktopParser;

  /// No description provided for @parseFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось разобрать запись. Файл может быть повреждён или записан несовместимой версией CS2.'**
  String get parseFailed;

  /// No description provided for @unsafeArchive.
  ///
  /// In ru, this message translates to:
  /// **'Архив отклонён: небезопасные пути, пароль или превышение лимитов.'**
  String get unsafeArchive;

  /// No description provided for @unsafeDownload.
  ///
  /// In ru, this message translates to:
  /// **'Используйте публичную HTTPS-ссылку на файл. Локальные и служебные адреса не принимаются.'**
  String get unsafeDownload;

  /// No description provided for @parseTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Анализ превысил лимит времени. Попробуйте отдельную карту вместо большого архива.'**
  String get parseTimeout;

  /// No description provided for @jobStarting.
  ///
  /// In ru, this message translates to:
  /// **'Подготовка импорта'**
  String get jobStarting;

  /// No description provided for @jobDownload.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка файла'**
  String get jobDownload;

  /// No description provided for @jobExtract.
  ///
  /// In ru, this message translates to:
  /// **'Распаковка архива'**
  String get jobExtract;

  /// No description provided for @jobParse.
  ///
  /// In ru, this message translates to:
  /// **'Анализ записи'**
  String get jobParse;

  /// No description provided for @jobPositions.
  ///
  /// In ru, this message translates to:
  /// **'Чтение позиций игроков'**
  String get jobPositions;

  /// No description provided for @jobEvents.
  ///
  /// In ru, this message translates to:
  /// **'Чтение событий'**
  String get jobEvents;

  /// No description provided for @jobIndex.
  ///
  /// In ru, this message translates to:
  /// **'Подготовка воспроизведения'**
  String get jobIndex;

  /// No description provided for @jobComplete.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get jobComplete;

  /// No description provided for @jobCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Операция отменена'**
  String get jobCancelled;

  /// No description provided for @noDownloads.
  ///
  /// In ru, this message translates to:
  /// **'Активных загрузок нет'**
  String get noDownloads;

  /// No description provided for @measuredData.
  ///
  /// In ru, this message translates to:
  /// **'Измеренные позиции · тренерский обзор'**
  String get measuredData;

  /// No description provided for @sampledPlayback.
  ///
  /// In ru, this message translates to:
  /// **'Движение сглаживается между записанными снимками. Это визуальное приближение; события и заметки привязаны к тикам, переносы между раундами не сглаживаются.'**
  String get sampledPlayback;

  /// No description provided for @radarRevisionNotice.
  ///
  /// In ru, this message translates to:
  /// **'Используется версия радара из набора приложения. Геометрия старой записи может отличаться.'**
  String get radarRevisionNotice;

  /// No description provided for @play.
  ///
  /// In ru, this message translates to:
  /// **'Воспроизвести'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get pause;

  /// No description provided for @nextFrame.
  ///
  /// In ru, this message translates to:
  /// **'Следующий снимок'**
  String get nextFrame;

  /// No description provided for @previousFrame.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий снимок'**
  String get previousFrame;

  /// No description provided for @roundLabel.
  ///
  /// In ru, this message translates to:
  /// **'Раунд'**
  String get roundLabel;

  /// No description provided for @players.
  ///
  /// In ru, this message translates to:
  /// **'Игроки'**
  String get players;

  /// No description provided for @events.
  ///
  /// In ru, this message translates to:
  /// **'События'**
  String get events;

  /// No description provided for @allSides.
  ///
  /// In ru, this message translates to:
  /// **'Обе стороны'**
  String get allSides;

  /// No description provided for @annotations.
  ///
  /// In ru, this message translates to:
  /// **'Заметки разбора'**
  String get annotations;

  /// No description provided for @addAnnotation.
  ///
  /// In ru, this message translates to:
  /// **'Добавить заметку'**
  String get addAnnotation;

  /// No description provided for @createTaskFromNote.
  ///
  /// In ru, this message translates to:
  /// **'Задание из заметки'**
  String get createTaskFromNote;

  /// No description provided for @exportReview.
  ///
  /// In ru, this message translates to:
  /// **'Отправить разбор на телефон'**
  String get exportReview;

  /// No description provided for @reviewDataInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный файл разбора'**
  String get reviewDataInvalid;

  /// No description provided for @noCalibration.
  ///
  /// In ru, this message translates to:
  /// **'Для этой карты нет готовой привязки координат. Доступны события и статистика, позиции скрыты.'**
  String get noCalibration;

  /// No description provided for @matchDetails.
  ///
  /// In ru, this message translates to:
  /// **'Карты и игроки'**
  String get matchDetails;

  /// No description provided for @scoreboard.
  ///
  /// In ru, this message translates to:
  /// **'Статистика игроков'**
  String get scoreboard;

  /// No description provided for @followPlayer.
  ///
  /// In ru, this message translates to:
  /// **'Следовать за игроком'**
  String get followPlayer;

  /// No description provided for @showTrails.
  ///
  /// In ru, this message translates to:
  /// **'Траектории'**
  String get showTrails;

  /// No description provided for @tickLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тик'**
  String get tickLabel;

  /// No description provided for @killsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Убийства'**
  String get killsLabel;

  /// No description provided for @deathsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Смерти'**
  String get deathsLabel;

  /// No description provided for @assistsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Помощь'**
  String get assistsLabel;

  /// No description provided for @viewAll.
  ///
  /// In ru, this message translates to:
  /// **'Показать все'**
  String get viewAll;

  /// No description provided for @workspaceSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Подготовка, которая превращается в командную игру.'**
  String get workspaceSubtitle;

  /// No description provided for @bombPlanted.
  ///
  /// In ru, this message translates to:
  /// **'Бомба установлена'**
  String get bombPlanted;

  /// No description provided for @bombDefused.
  ///
  /// In ru, this message translates to:
  /// **'Бомба обезврежена'**
  String get bombDefused;

  /// No description provided for @bombExploded.
  ///
  /// In ru, this message translates to:
  /// **'Взрыв бомбы'**
  String get bombExploded;

  /// No description provided for @eventPoints.
  ///
  /// In ru, this message translates to:
  /// **'Гранаты показаны точками событий, без выдуманной формы дыма или огня.'**
  String get eventPoints;

  /// No description provided for @playerT.
  ///
  /// In ru, this message translates to:
  /// **'Игрок T · янтарный круг'**
  String get playerT;

  /// No description provided for @playerCT.
  ///
  /// In ru, this message translates to:
  /// **'Игрок CT · синий щит'**
  String get playerCT;

  /// No description provided for @playerLegend.
  ///
  /// In ru, this message translates to:
  /// **'T1–T5 — атака · CT1–CT5 — защита. Нумерация у каждой стороны своя.'**
  String get playerLegend;

  /// No description provided for @playbooks.
  ///
  /// In ru, this message translates to:
  /// **'Плейбуки / PDF'**
  String get playbooks;

  /// No description provided for @newPlaybook.
  ///
  /// In ru, this message translates to:
  /// **'Новый плейбук'**
  String get newPlaybook;

  /// No description provided for @attachToPlaybook.
  ///
  /// In ru, this message translates to:
  /// **'В плейбук / PDF'**
  String get attachToPlaybook;

  /// No description provided for @playbookHelp.
  ///
  /// In ru, this message translates to:
  /// **'Собирайте страницы раундов: план, экономика, роли и снимки тактик. Схема фиксируется при добавлении и не меняется вместе с тактикой.'**
  String get playbookHelp;

  /// No description provided for @roundPlan.
  ///
  /// In ru, this message translates to:
  /// **'План раунда'**
  String get roundPlan;

  /// No description provided for @economy.
  ///
  /// In ru, this message translates to:
  /// **'Экономика / закуп'**
  String get economy;

  /// No description provided for @responsibilities.
  ///
  /// In ru, this message translates to:
  /// **'Роли и тайминги'**
  String get responsibilities;

  /// No description provided for @addRound.
  ///
  /// In ru, this message translates to:
  /// **'Добавить страницу раунда'**
  String get addRound;

  /// No description provided for @attachTactic.
  ///
  /// In ru, this message translates to:
  /// **'Прикрепить схему тактики'**
  String get attachTactic;

  /// No description provided for @snapshotSaved.
  ///
  /// In ru, this message translates to:
  /// **'Снимок тактики добавлен в плейбук'**
  String get snapshotSaved;

  /// No description provided for @exportDocument.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить PDF'**
  String get exportDocument;

  /// No description provided for @moveUp.
  ///
  /// In ru, this message translates to:
  /// **'Выше'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In ru, this message translates to:
  /// **'Ниже'**
  String get moveDown;

  /// No description provided for @removePage.
  ///
  /// In ru, this message translates to:
  /// **'Удалить страницу'**
  String get removePage;

  /// No description provided for @removeAttachment.
  ///
  /// In ru, this message translates to:
  /// **'Убрать схему'**
  String get removeAttachment;

  /// No description provided for @bootcamp.
  ///
  /// In ru, this message translates to:
  /// **'Буткемп'**
  String get bootcamp;

  /// No description provided for @bootcampHelp.
  ///
  /// In ru, this message translates to:
  /// **'Установите CS2 и TeamSpeak прямо здесь, подключите MatchZy и запускайте локальные серверы кнопкой.'**
  String get bootcampHelp;

  /// No description provided for @csExecutable.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать cs2.exe'**
  String get csExecutable;

  /// No description provided for @tsExecutable.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать ts3server.exe'**
  String get tsExecutable;

  /// No description provided for @steamExecutable.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать steam.exe'**
  String get steamExecutable;

  /// No description provided for @startBoth.
  ///
  /// In ru, this message translates to:
  /// **'Запустить CS2 + TeamSpeak'**
  String get startBoth;

  /// No description provided for @startServer.
  ///
  /// In ru, this message translates to:
  /// **'Запустить'**
  String get startServer;

  /// No description provided for @stopServer.
  ///
  /// In ru, this message translates to:
  /// **'Остановить'**
  String get stopServer;

  /// No description provided for @restartServer.
  ///
  /// In ru, this message translates to:
  /// **'Перезапустить'**
  String get restartServer;

  /// No description provided for @connectServer.
  ///
  /// In ru, this message translates to:
  /// **'Подключиться'**
  String get connectServer;

  /// No description provided for @serverStopped.
  ///
  /// In ru, this message translates to:
  /// **'Остановлен'**
  String get serverStopped;

  /// No description provided for @serverStarting.
  ///
  /// In ru, this message translates to:
  /// **'Процесс запущен · проверяется порт'**
  String get serverStarting;

  /// No description provided for @serverReady.
  ///
  /// In ru, this message translates to:
  /// **'LAN-порт отвечает'**
  String get serverReady;

  /// No description provided for @serverFailed.
  ///
  /// In ru, this message translates to:
  /// **'Процесс завершился'**
  String get serverFailed;

  /// No description provided for @chooseExecutables.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выберите существующие серверные файлы.'**
  String get chooseExecutables;

  /// No description provided for @serverProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль CS2'**
  String get serverProfile;

  /// No description provided for @practiceProfile.
  ///
  /// In ru, this message translates to:
  /// **'Тренировка'**
  String get practiceProfile;

  /// No description provided for @scrimProfile.
  ///
  /// In ru, this message translates to:
  /// **'PUG / scrim · MatchZy'**
  String get scrimProfile;

  /// No description provided for @bootcampLimits.
  ///
  /// In ru, this message translates to:
  /// **'CS2 и TS3 скачиваются отдельными компонентами в выбранную папку. Лицензию TS3 нужно принять после чтения. PUG и расширенная тренировка используют MatchZy. Интернет-доступ не проверяется; firewall не меняется.'**
  String get bootcampLimits;

  /// No description provided for @getTeamspeak.
  ///
  /// In ru, this message translates to:
  /// **'Скачать сервер TeamSpeak'**
  String get getTeamspeak;

  /// No description provided for @serverLog.
  ///
  /// In ru, this message translates to:
  /// **'Журнал процессов'**
  String get serverLog;

  /// No description provided for @serverPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт CS2'**
  String get serverPort;

  /// No description provided for @lanAddress.
  ///
  /// In ru, this message translates to:
  /// **'LAN-адреса этого ПК'**
  String get lanAddress;

  /// No description provided for @localHostOnly.
  ///
  /// In ru, this message translates to:
  /// **'Запуск серверов доступен на Windows'**
  String get localHostOnly;

  /// No description provided for @openInCS.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в CS2'**
  String get openInCS;

  /// No description provided for @csLaunchHelp.
  ///
  /// In ru, this message translates to:
  /// **'Steam запускает демку. Если CS2 уже открыт, закройте игру и нажмите ещё раз либо вставьте скопированную команду в консоль.'**
  String get csLaunchHelp;

  /// No description provided for @csLaunchError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть демку. Проверьте пути CS2 и Steam в разделе «Буткемп» и наличие исходного DEM.'**
  String get csLaunchError;

  /// No description provided for @scouting.
  ///
  /// In ru, this message translates to:
  /// **'Разметка матча'**
  String get scouting;

  /// No description provided for @scoutingHelp.
  ///
  /// In ru, this message translates to:
  /// **'Команды, турнир, тир и роли отмечает тренер. Позиции указывайте в контексте карты и стороны; это не официальные роли HLTV.'**
  String get scoutingHelp;

  /// No description provided for @matchTeams.
  ///
  /// In ru, this message translates to:
  /// **'Команды (через запятую)'**
  String get matchTeams;

  /// No description provided for @tournament.
  ///
  /// In ru, this message translates to:
  /// **'Турнир'**
  String get tournament;

  /// No description provided for @tournamentTier.
  ///
  /// In ru, this message translates to:
  /// **'Тир турнира'**
  String get tournamentTier;

  /// No description provided for @playerPositions.
  ///
  /// In ru, this message translates to:
  /// **'Позиции / роли (по строке: игрок — сторона — позиция)'**
  String get playerPositions;

  /// No description provided for @filterTeam.
  ///
  /// In ru, this message translates to:
  /// **'Команда'**
  String get filterTeam;

  /// No description provided for @filterPosition.
  ///
  /// In ru, this message translates to:
  /// **'Позиция / роль'**
  String get filterPosition;

  /// No description provided for @allTiers.
  ///
  /// In ru, this message translates to:
  /// **'Все тиры'**
  String get allTiers;

  /// No description provided for @untagged.
  ///
  /// In ru, this message translates to:
  /// **'Не размечено'**
  String get untagged;

  /// No description provided for @hltvInbox.
  ///
  /// In ru, this message translates to:
  /// **'Каталог HLTV'**
  String get hltvInbox;

  /// No description provided for @hltvInboxHelp.
  ///
  /// In ru, this message translates to:
  /// **'Откройте матч, выберите папку загрузок и скачайте Demo в браузере. TeamSync подхватит новый DEM / RAR / ZIP из этой папки, распакует и добавит в библиотеку. Проверка браузера проходит в самом браузере.'**
  String get hltvInboxHelp;

  /// No description provided for @watchDownloads.
  ///
  /// In ru, this message translates to:
  /// **'Открыть матч и ждать загрузку'**
  String get watchDownloads;

  /// No description provided for @waitingDownload.
  ///
  /// In ru, this message translates to:
  /// **'Ожидается новая демка в выбранной папке. Не закрывайте этот раздел.'**
  String get waitingDownload;

  /// No description provided for @stopWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Перестать ждать'**
  String get stopWaiting;

  /// No description provided for @chooseDownloadFolder.
  ///
  /// In ru, this message translates to:
  /// **'Папка загрузок браузера'**
  String get chooseDownloadFolder;

  /// No description provided for @matchPage.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на матч HLTV'**
  String get matchPage;

  /// No description provided for @timelineNotes.
  ///
  /// In ru, this message translates to:
  /// **'Метки заметок · нажмите для перехода'**
  String get timelineNotes;

  /// No description provided for @noteAt.
  ///
  /// In ru, this message translates to:
  /// **'Заметка к текущему моменту'**
  String get noteAt;

  /// No description provided for @deleteNote.
  ///
  /// In ru, this message translates to:
  /// **'Удалить заметку'**
  String get deleteNote;

  /// No description provided for @invalidServerPort.
  ///
  /// In ru, this message translates to:
  /// **'Введите порт от 1024 до 65535'**
  String get invalidServerPort;

  /// No description provided for @serverBusy.
  ///
  /// In ru, this message translates to:
  /// **'Остановите серверы перед изменением настроек'**
  String get serverBusy;

  /// No description provided for @noServerLogs.
  ///
  /// In ru, this message translates to:
  /// **'Журнал появится после запуска'**
  String get noServerLogs;

  /// No description provided for @captureVersion.
  ///
  /// In ru, this message translates to:
  /// **'Снимок версии'**
  String get captureVersion;

  /// No description provided for @saveDraft.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить черновик'**
  String get saveDraft;

  /// No description provided for @draftSaved.
  ///
  /// In ru, this message translates to:
  /// **'Черновик сохранён'**
  String get draftSaved;

  /// No description provided for @tsLicenseHelp.
  ///
  /// In ru, this message translates to:
  /// **'TeamSpeak: установите сервер отдельно и один раз запустите его вручную, приняв лицензию. Затем выберите ts3server.exe.'**
  String get tsLicenseHelp;

  /// No description provided for @chooseServerInstallation.
  ///
  /// In ru, this message translates to:
  /// **'Для сервера и плагинов выберите отдельную установку CS2 Dedicated Server. Клиентская игра используется только для просмотра демок.'**
  String get chooseServerInstallation;

  /// No description provided for @serverExecutable.
  ///
  /// In ru, this message translates to:
  /// **'Сервер: выбрать cs2.exe'**
  String get serverExecutable;

  /// No description provided for @pluginHelp.
  ///
  /// In ru, this message translates to:
  /// **'Установка скачивает закреплённые официальные версии, проверяет SHA-256, сохраняет резервные копии и подключает Metamod в gameinfo.gi. Личные конфиги MatchZy сохраняются. После обновления CS2 проверьте загрузку плагина.'**
  String get pluginHelp;

  /// No description provided for @installPlugin.
  ///
  /// In ru, this message translates to:
  /// **'Установить MatchZy и зависимости'**
  String get installPlugin;

  /// No description provided for @pluginInstalled.
  ///
  /// In ru, this message translates to:
  /// **'Файлы MatchZy установлены. Запустите сервер и проверьте статус плагина.'**
  String get pluginInstalled;

  /// No description provided for @pluginInstallFailed.
  ///
  /// In ru, this message translates to:
  /// **'Установка не завершена. Проверьте путь отдельного сервера, доступ к сети и журнал.'**
  String get pluginInstallFailed;

  /// No description provided for @pluginCommands.
  ///
  /// In ru, this message translates to:
  /// **'PUG: .ready / .unready · .pause / .unpause · .stay / .switch.\nТренировка: .prac · .savenade имя · .loadnade имя · .rethrow · .traj · .clear · .bot · .ctspawn 1. Команды вводятся в чат CS2; административные требуют прав.'**
  String get pluginCommands;

  /// No description provided for @pluginLoaded.
  ///
  /// In ru, this message translates to:
  /// **'MatchZy загружен'**
  String get pluginLoaded;

  /// No description provided for @pluginNotVerified.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка MatchZy ещё не подтверждена'**
  String get pluginNotVerified;

  /// No description provided for @applyPractice.
  ///
  /// In ru, this message translates to:
  /// **'Включить тренировку на сервере'**
  String get applyPractice;

  /// No description provided for @applyScrim.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть PUG-режим'**
  String get applyScrim;

  /// No description provided for @pluginCommandFailed.
  ///
  /// In ru, this message translates to:
  /// **'Команда не подтверждена. Проверьте загрузку MatchZy и журнал сервера.'**
  String get pluginCommandFailed;

  /// No description provided for @commandSent.
  ///
  /// In ru, this message translates to:
  /// **'Команда отправлена серверу; результат смотрите в журнале.'**
  String get commandSent;

  /// No description provided for @matchSetup.
  ///
  /// In ru, this message translates to:
  /// **'Матч и veto'**
  String get matchSetup;

  /// No description provided for @matchSetupHelp.
  ///
  /// In ru, this message translates to:
  /// **'Введите настоящие SteamID64 игроков. Капитаны проходят veto в CS2, затем ready и knife. При выборе одной карты veto пропускается.'**
  String get matchSetupHelp;

  /// No description provided for @steamRoster.
  ///
  /// In ru, this message translates to:
  /// **'Состав: SteamID64 и ник, по одному в строке'**
  String get steamRoster;

  /// No description provided for @invalidMatchRoster.
  ///
  /// In ru, this message translates to:
  /// **'Нужны 1–5 уникальных SteamID64 в каждой команде без пересечений. Карт должно хватать на выбранный BO.'**
  String get invalidMatchRoster;

  /// No description provided for @loadMatch.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить матч на сервер'**
  String get loadMatch;

  /// No description provided for @refreshCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Обновить HLTV'**
  String get refreshCatalog;

  /// No description provided for @catalogPrevious.
  ///
  /// In ru, this message translates to:
  /// **'Новее'**
  String get catalogPrevious;

  /// No description provided for @catalogNext.
  ///
  /// In ru, this message translates to:
  /// **'Ранее'**
  String get catalogNext;

  /// No description provided for @anyStars.
  ///
  /// In ru, this message translates to:
  /// **'Любой рейтинг'**
  String get anyStars;

  /// No description provided for @catalogPosition.
  ///
  /// In ru, this message translates to:
  /// **'Позиция (моя разметка)'**
  String get catalogPosition;

  /// No description provided for @catalogFilterHelp.
  ///
  /// In ru, this message translates to:
  /// **'Поиск — по текущим 100 матчам. Звёзды — оценка матча HLTV, не тир турнира. Тир отмечается тренером у события; позиции берутся из вашей разметки импортированных демок.'**
  String get catalogFilterHelp;

  /// No description provided for @catalogUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Получено:'**
  String get catalogUpdated;

  /// No description provided for @downloadAndAnalyze.
  ///
  /// In ru, this message translates to:
  /// **'Скачать и разобрать'**
  String get downloadAndAnalyze;

  /// No description provided for @coachTier.
  ///
  /// In ru, this message translates to:
  /// **'Тир · разметка тренера'**
  String get coachTier;

  /// No description provided for @hltvNoDemo.
  ///
  /// In ru, this message translates to:
  /// **'На странице этого матча пока нет ссылки Demo.'**
  String get hltvNoDemo;

  /// No description provided for @hltvUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'HLTV не ответил или ограничил запрос. Сохранённый каталог доступен; можно открыть матч в браузере и повторить позднее.'**
  String get hltvUnavailable;

  /// No description provided for @hltvRateLimit.
  ///
  /// In ru, this message translates to:
  /// **'HLTV просит снизить частоту запросов. Каталог из кэша доступен; повторите через несколько минут.'**
  String get hltvRateLimit;

  /// No description provided for @hltvBrowserFallback.
  ///
  /// In ru, this message translates to:
  /// **'Каталог и ссылка получены, но сервер архива ограничил прямую загрузку. Скачайте файл в открывшемся браузере — TeamSync заберёт его из выбранной папки.'**
  String get hltvBrowserFallback;

  /// No description provided for @serverFolder.
  ///
  /// In ru, this message translates to:
  /// **'Папка для серверов'**
  String get serverFolder;

  /// No description provided for @serverFilesReady.
  ///
  /// In ru, this message translates to:
  /// **'Файлы сервера установлены, путь сохранён'**
  String get serverFilesReady;

  /// No description provided for @serverDiskSpace.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно места: для первой установки CS2 нужно не менее 110 ГБ свободного места, для обновления — 11 ГБ.'**
  String get serverDiskSpace;

  /// No description provided for @serverSetupError.
  ///
  /// In ru, this message translates to:
  /// **'Установка не завершена. Проверьте место и доступ к папке/сети. Повторная установка CS2 продолжит загрузку SteamCMD. Если официальный архив изменился, потребуется обновление TeamSync.'**
  String get serverSetupError;

  /// No description provided for @serverContentDownload.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка / проверка файлов сервера'**
  String get serverContentDownload;

  /// No description provided for @steamcmdPreparing.
  ///
  /// In ru, this message translates to:
  /// **'Подготовка SteamCMD и подключение к Steam'**
  String get steamcmdPreparing;

  /// No description provided for @downloadServerFiles.
  ///
  /// In ru, this message translates to:
  /// **'Установка серверов из TeamSync'**
  String get downloadServerFiles;

  /// No description provided for @serverDownloadHelp.
  ///
  /// In ru, this message translates to:
  /// **'CS2 загружается напрямую через Valve SteamCMD (большая загрузка: примерно 80–100 ГБ; нужно 110 ГБ свободного места). TeamSpeak 3.13.8 — официальный архив, около 9 МБ. Создаётся отдельная папка TeamSyncServers. Серверы сами не запускаются.'**
  String get serverDownloadHelp;

  /// No description provided for @downloadCsServer.
  ///
  /// In ru, this message translates to:
  /// **'Установить / продолжить CS2'**
  String get downloadCsServer;

  /// No description provided for @downloadTsServer.
  ///
  /// In ru, this message translates to:
  /// **'Установить TeamSpeak'**
  String get downloadTsServer;

  /// No description provided for @acceptTsLicense.
  ///
  /// In ru, this message translates to:
  /// **'Я прочитал и принимаю лицензию TeamSpeak'**
  String get acceptTsLicense;

  /// No description provided for @tsLicense.
  ///
  /// In ru, this message translates to:
  /// **'Лицензия TeamSpeak'**
  String get tsLicense;

  /// No description provided for @continueLabel.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get continueLabel;

  /// No description provided for @hltvDesktopCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Каталог HLTV загружается на Windows. На телефоне доступны подготовленные разборы и сайт HLTV в браузере.'**
  String get hltvDesktopCatalog;

  /// No description provided for @sourceVerification.
  ///
  /// In ru, this message translates to:
  /// **'Подключение и проверка источника HLTV'**
  String get sourceVerification;

  /// No description provided for @downloadRuntimeMissing.
  ///
  /// In ru, this message translates to:
  /// **'Не найден компонент загрузок. Повторите установку TeamSync с подключённым интернетом: установщик добавит необходимый компонент Microsoft.'**
  String get downloadRuntimeMissing;

  /// No description provided for @managedDownloadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка не завершена. Если появилось окно проверки источника, подтвердите доступ и повторите. Проверьте сеть и свободное место.'**
  String get managedDownloadFailed;

  /// No description provided for @accountId.
  ///
  /// In ru, this message translates to:
  /// **'ID аккаунта'**
  String get accountId;

  /// No description provided for @copyAccountId.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать ID аккаунта'**
  String get copyAccountId;

  /// No description provided for @accountInvite.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить по аккаунту'**
  String get accountInvite;

  /// No description provided for @accountLookup.
  ///
  /// In ru, this message translates to:
  /// **'ID аккаунта игрока'**
  String get accountLookup;

  /// No description provided for @acceptInvite.
  ///
  /// In ru, this message translates to:
  /// **'Принять'**
  String get acceptInvite;

  /// No description provided for @declineInvite.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить'**
  String get declineInvite;

  /// No description provided for @incomingInvites.
  ///
  /// In ru, this message translates to:
  /// **'Приглашения в команды'**
  String get incomingInvites;

  /// No description provided for @outgoingInvites.
  ///
  /// In ru, this message translates to:
  /// **'Отправленные приглашения'**
  String get outgoingInvites;

  /// No description provided for @cancelInvite.
  ///
  /// In ru, this message translates to:
  /// **'Отозвать приглашение'**
  String get cancelInvite;

  /// No description provided for @openRoster.
  ///
  /// In ru, this message translates to:
  /// **'Открыть состав'**
  String get openRoster;

  /// No description provided for @squad.
  ///
  /// In ru, this message translates to:
  /// **'Состав'**
  String get squad;

  /// No description provided for @mainSquad.
  ///
  /// In ru, this message translates to:
  /// **'Основной состав'**
  String get mainSquad;

  /// No description provided for @reserveSquad.
  ///
  /// In ru, this message translates to:
  /// **'Запас'**
  String get reserveSquad;

  /// No description provided for @staffSquad.
  ///
  /// In ru, this message translates to:
  /// **'Штаб'**
  String get staffSquad;

  /// No description provided for @leaveTeam.
  ///
  /// In ru, this message translates to:
  /// **'Покинуть команду'**
  String get leaveTeam;

  /// No description provided for @removePlayer.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из состава'**
  String get removePlayer;

  /// No description provided for @accountNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт не найден. Попроси игрока скопировать свой ID в профиле.'**
  String get accountNotFound;

  /// No description provided for @inviteInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение истекло или отозвано.'**
  String get inviteInvalid;

  /// No description provided for @alreadyMember.
  ///
  /// In ru, this message translates to:
  /// **'Этот аккаунт уже в команде.'**
  String get alreadyMember;

  /// No description provided for @accessDenied.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав для этого действия.'**
  String get accessDenied;

  /// No description provided for @writeConflict.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение уже отправлено или данные изменились. Обнови список.'**
  String get writeConflict;

  /// No description provided for @ownershipRequired.
  ///
  /// In ru, this message translates to:
  /// **'Сначала передай владение другому участнику.'**
  String get ownershipRequired;

  /// No description provided for @confirmAction.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить действие?'**
  String get confirmAction;

  /// No description provided for @transferOwner.
  ///
  /// In ru, this message translates to:
  /// **'Передать владение'**
  String get transferOwner;

  /// No description provided for @openInWorkspace.
  ///
  /// In ru, this message translates to:
  /// **'Открыть общие тактики'**
  String get openInWorkspace;

  /// No description provided for @rosterLocalHelp.
  ///
  /// In ru, this message translates to:
  /// **'Открой общие тактики команды на этом устройстве. Схемы и заметки синхронизируются между ПК и телефоном.'**
  String get rosterLocalHelp;

  /// No description provided for @editProfile.
  ///
  /// In ru, this message translates to:
  /// **'Изменить имя'**
  String get editProfile;

  /// No description provided for @serverWaking.
  ///
  /// In ru, this message translates to:
  /// **'Подключение к серверу. После простоя бесплатный сервер может запускаться около минуты.'**
  String get serverWaking;

  /// No description provided for @accountTeamHelp.
  ///
  /// In ru, this message translates to:
  /// **'Пригласи игрока по ID его аккаунта. Он увидит приглашение в профиле и сам подтвердит вступление.'**
  String get accountTeamHelp;

  /// No description provided for @accountRosterManaged.
  ///
  /// In ru, this message translates to:
  /// **'Управлять составом по аккаунтам'**
  String get accountRosterManaged;

  /// No description provided for @copied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get copied;

  /// No description provided for @inviteSent.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение отправлено'**
  String get inviteSent;

  /// No description provided for @syncTactics.
  ///
  /// In ru, this message translates to:
  /// **'Общие тактики'**
  String get syncTactics;

  /// No description provided for @syncNow.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать'**
  String get syncNow;

  /// No description provided for @syncWorking.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация…'**
  String get syncWorking;

  /// No description provided for @syncReady.
  ///
  /// In ru, this message translates to:
  /// **'Тактики синхронизированы'**
  String get syncReady;

  /// No description provided for @syncOffline.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи. Изменения сохранены на устройстве и будут отправлены после подключения.'**
  String get syncOffline;

  /// No description provided for @syncConflict.
  ///
  /// In ru, this message translates to:
  /// **'Сохранены обе версии. Проверь копию конфликта в тактиках.'**
  String get syncConflict;

  /// No description provided for @syncConflictCopy.
  ///
  /// In ru, this message translates to:
  /// **'Конфликтная копия'**
  String get syncConflictCopy;

  /// No description provided for @syncAccountMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Войди в аккаунт, к которому привязана эта команда.'**
  String get syncAccountMismatch;

  /// No description provided for @readOnlyTeam.
  ///
  /// In ru, this message translates to:
  /// **'Твоя роль позволяет просматривать общие тактики. Изменять их могут владелец, капитан и тренер.'**
  String get readOnlyTeam;

  /// No description provided for @syncTeamHelp.
  ///
  /// In ru, this message translates to:
  /// **'Тактики, схемы на картах и заметки общие для всей онлайн-команды. Сохранённые правки отправляются автоматически; без связи остаются на устройстве.'**
  String get syncTeamHelp;

  /// No description provided for @linkWorkspace.
  ///
  /// In ru, this message translates to:
  /// **'Подключить общие тактики'**
  String get linkWorkspace;

  /// No description provided for @newSharedWorkspace.
  ///
  /// In ru, this message translates to:
  /// **'Новая рабочая область'**
  String get newSharedWorkspace;

  /// No description provided for @linkTeamExplain.
  ///
  /// In ru, this message translates to:
  /// **'Выбери рабочую область. Её тактики станут общими для этой команды; правки участников будут загружаться сюда.'**
  String get linkTeamExplain;

  /// No description provided for @syncAccessLost.
  ///
  /// In ru, this message translates to:
  /// **'Доступ к команде отозван. Локальные материалы сохранены, синхронизация остановлена.'**
  String get syncAccessLost;

  /// No description provided for @utilityLibrary.
  ///
  /// In ru, this message translates to:
  /// **'Раскидки'**
  String get utilityLibrary;

  /// No description provided for @newUtility.
  ///
  /// In ru, this message translates to:
  /// **'Новая раскидка'**
  String get newUtility;

  /// No description provided for @editUtility.
  ///
  /// In ru, this message translates to:
  /// **'Изменить раскидку'**
  String get editUtility;

  /// No description provided for @utilityInstruction.
  ///
  /// In ru, this message translates to:
  /// **'Инструкция и тайминг'**
  String get utilityInstruction;

  /// No description provided for @utilitySource.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка YouTube / CS2Tricks'**
  String get utilitySource;

  /// No description provided for @utilitySourceHelp.
  ///
  /// In ru, this message translates to:
  /// **'Источник открывается в оригинале. Если видео недоступно, используйте сохранённую инструкцию. Медиа внешнего сайта не скачиваются.'**
  String get utilitySourceHelp;

  /// No description provided for @utilityEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте командную раскидку: карту, позицию, инструкцию и источник.'**
  String get utilityEmpty;

  /// No description provided for @utilityGrenade.
  ///
  /// In ru, this message translates to:
  /// **'Тип гранаты'**
  String get utilityGrenade;

  /// No description provided for @utilityStart.
  ///
  /// In ru, this message translates to:
  /// **'Начальная позиция'**
  String get utilityStart;

  /// No description provided for @utilityTarget.
  ///
  /// In ru, this message translates to:
  /// **'Цель'**
  String get utilityTarget;

  /// No description provided for @utilityThrow.
  ///
  /// In ru, this message translates to:
  /// **'Тип броска'**
  String get utilityThrow;

  /// No description provided for @utilityAuthor.
  ///
  /// In ru, this message translates to:
  /// **'Автор оригинала'**
  String get utilityAuthor;

  /// No description provided for @utilityVerified.
  ///
  /// In ru, this message translates to:
  /// **'Проверено, дата ISO'**
  String get utilityVerified;

  /// No description provided for @utilityRevision.
  ///
  /// In ru, this message translates to:
  /// **'Версия карты'**
  String get utilityRevision;

  /// No description provided for @utilityOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть оригинал'**
  String get utilityOpen;

  /// No description provided for @utilityUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть источник. Инструкция остаётся доступной.'**
  String get utilityUnavailable;

  /// No description provided for @utilityInvalidSource.
  ///
  /// In ru, this message translates to:
  /// **'Разрешены HTTPS-ссылки YouTube и CS2Tricks без логина и пароля.'**
  String get utilityInvalidSource;

  /// No description provided for @grenadeHe.
  ///
  /// In ru, this message translates to:
  /// **'Осколочная'**
  String get grenadeHe;

  /// No description provided for @grenadeDecoy.
  ///
  /// In ru, this message translates to:
  /// **'Ложная'**
  String get grenadeDecoy;

  /// No description provided for @editMaterial.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get editMaterial;

  /// No description provided for @utilityTactics.
  ///
  /// In ru, this message translates to:
  /// **'Связанные тактики'**
  String get utilityTactics;

  /// No description provided for @utilityScreenshots.
  ///
  /// In ru, this message translates to:
  /// **'Скриншоты прицеливания'**
  String get utilityScreenshots;

  /// No description provided for @utilityAddImage.
  ///
  /// In ru, this message translates to:
  /// **'Своё изображение'**
  String get utilityAddImage;

  /// No description provided for @utilityRemoveImage.
  ///
  /// In ru, this message translates to:
  /// **'Убрать изображение'**
  String get utilityRemoveImage;

  /// No description provided for @syncReadOnlyPending.
  ///
  /// In ru, this message translates to:
  /// **'Локальные правки сохранены. Текущая роль не разрешает их отправку.'**
  String get syncReadOnlyPending;

  /// No description provided for @syncMediaQuota.
  ///
  /// In ru, this message translates to:
  /// **'Лимит вложений команды исчерпан.'**
  String get syncMediaQuota;

  /// No description provided for @utilityVideo.
  ///
  /// In ru, this message translates to:
  /// **'Свой видеоклип'**
  String get utilityVideo;

  /// No description provided for @utilityAddVideo.
  ///
  /// In ru, this message translates to:
  /// **'Добавить свой MP4'**
  String get utilityAddVideo;

  /// No description provided for @utilityOpenVideo.
  ///
  /// In ru, this message translates to:
  /// **'Смотреть клип'**
  String get utilityOpenVideo;

  /// No description provided for @utilityShareVideo.
  ///
  /// In ru, this message translates to:
  /// **'Отправить файл'**
  String get utilityShareVideo;

  /// No description provided for @utilityRemoveVideo.
  ///
  /// In ru, this message translates to:
  /// **'Убрать клип'**
  String get utilityRemoveVideo;

  /// No description provided for @utilityVideoLimit.
  ///
  /// In ru, this message translates to:
  /// **'Свой MP4 до 20 МБ. Клип синхронизируется с командой и сохраняется для офлайн-просмотра.'**
  String get utilityVideoLimit;

  /// No description provided for @invalidVideo.
  ///
  /// In ru, this message translates to:
  /// **'Выберите MP4 с видеодорожкой размером до 20 МБ.'**
  String get invalidVideo;

  /// No description provided for @videoUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть клип. Выберите совместимый проигрыватель через отправку файла.'**
  String get videoUnavailable;

  /// No description provided for @skillTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изучение и проверка'**
  String get skillTitle;

  /// No description provided for @skillSelf.
  ///
  /// In ru, this message translates to:
  /// **'Мой статус'**
  String get skillSelf;

  /// No description provided for @skillNotStarted.
  ///
  /// In ru, this message translates to:
  /// **'Не изучено'**
  String get skillNotStarted;

  /// No description provided for @skillLearning.
  ///
  /// In ru, this message translates to:
  /// **'Изучаю'**
  String get skillLearning;

  /// No description provided for @skillReady.
  ///
  /// In ru, this message translates to:
  /// **'Готов проверить'**
  String get skillReady;

  /// No description provided for @skillConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждено'**
  String get skillConfirmed;

  /// No description provided for @skillTeam.
  ///
  /// In ru, this message translates to:
  /// **'Проверка состава'**
  String get skillTeam;

  /// No description provided for @skillRecheck.
  ///
  /// In ru, this message translates to:
  /// **'Нужна повторная проверка'**
  String get skillRecheck;

  /// No description provided for @skillRequestRecheck.
  ///
  /// In ru, this message translates to:
  /// **'Запросить повторную проверку навыков'**
  String get skillRequestRecheck;

  /// No description provided for @skillReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина повторной проверки'**
  String get skillReason;

  /// No description provided for @skillReturnReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина возврата на доработку'**
  String get skillReturnReason;

  /// No description provided for @skillConflict.
  ///
  /// In ru, this message translates to:
  /// **'Статус изменён на другом устройстве'**
  String get skillConflict;

  /// No description provided for @skillKeepRemote.
  ///
  /// In ru, this message translates to:
  /// **'Оставить серверный статус'**
  String get skillKeepRemote;

  /// No description provided for @skillKeepLocal.
  ///
  /// In ru, this message translates to:
  /// **'Отправить мой статус'**
  String get skillKeepLocal;

  /// No description provided for @skillPending.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено локально'**
  String get skillPending;

  /// No description provided for @skillMaterialChanged.
  ///
  /// In ru, this message translates to:
  /// **'Раскидка обновилась. Закройте окно и откройте проверку заново.'**
  String get skillMaterialChanged;

  /// No description provided for @skillEmptyHistory.
  ///
  /// In ru, this message translates to:
  /// **'Истории проверок пока нет.'**
  String get skillEmptyHistory;

  /// No description provided for @skillMember.
  ///
  /// In ru, this message translates to:
  /// **'Участник команды'**
  String get skillMember;

  /// No description provided for @skillReasonRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите причину повторной проверки.'**
  String get skillReasonRequired;

  /// No description provided for @taskInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В процессе'**
  String get taskInProgress;

  /// No description provided for @taskStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать задание'**
  String get taskStart;

  /// No description provided for @taskReturnReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина возврата задания'**
  String get taskReturnReason;

  /// No description provided for @historyMore.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить ещё'**
  String get historyMore;

  /// No description provided for @taskType.
  ///
  /// In ru, this message translates to:
  /// **'Тип задания'**
  String get taskType;

  /// No description provided for @taskTypeUtility.
  ///
  /// In ru, this message translates to:
  /// **'Изучить раскидку'**
  String get taskTypeUtility;

  /// No description provided for @taskTypeTactic.
  ///
  /// In ru, this message translates to:
  /// **'Выучить роль в тактике'**
  String get taskTypeTactic;

  /// No description provided for @taskTypeDryRun.
  ///
  /// In ru, this message translates to:
  /// **'Провести dry run'**
  String get taskTypeDryRun;

  /// No description provided for @taskTypeExecute.
  ///
  /// In ru, this message translates to:
  /// **'Отработать execute'**
  String get taskTypeExecute;

  /// No description provided for @taskTypeRetake.
  ///
  /// In ru, this message translates to:
  /// **'Отработать retake'**
  String get taskTypeRetake;

  /// No description provided for @taskTypeDemo.
  ///
  /// In ru, this message translates to:
  /// **'Посмотреть демку'**
  String get taskTypeDemo;

  /// No description provided for @taskTypeRound.
  ///
  /// In ru, this message translates to:
  /// **'Разобрать раунд'**
  String get taskTypeRound;

  /// No description provided for @taskTypeFix.
  ///
  /// In ru, this message translates to:
  /// **'Исправить ошибку'**
  String get taskTypeFix;

  /// No description provided for @taskTypeQuiz.
  ///
  /// In ru, this message translates to:
  /// **'Проверка знаний'**
  String get taskTypeQuiz;

  /// No description provided for @taskDeadline.
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get taskDeadline;

  /// No description provided for @taskNoDeadline.
  ///
  /// In ru, this message translates to:
  /// **'Без срока'**
  String get taskNoDeadline;

  /// No description provided for @taskClearDeadline.
  ///
  /// In ru, this message translates to:
  /// **'Убрать срок'**
  String get taskClearDeadline;

  /// No description provided for @taskDeadlineHelp.
  ///
  /// In ru, this message translates to:
  /// **'Выберите время на этом устройстве. Участники увидят срок в своём часовом поясе.'**
  String get taskDeadlineHelp;

  /// No description provided for @taskCriteria.
  ///
  /// In ru, this message translates to:
  /// **'Критерий выполнения'**
  String get taskCriteria;

  /// No description provided for @editTaskPlan.
  ///
  /// In ru, this message translates to:
  /// **'Изменить план'**
  String get editTaskPlan;

  /// No description provided for @taskOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено'**
  String get taskOverdue;

  /// No description provided for @taskTypeGeneral.
  ///
  /// In ru, this message translates to:
  /// **'Общее задание'**
  String get taskTypeGeneral;

  /// No description provided for @taskCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать задание'**
  String get taskCreate;

  /// No description provided for @taskSavePlan.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить план'**
  String get taskSavePlan;

  /// No description provided for @prepareMap.
  ///
  /// In ru, this message translates to:
  /// **'Подготовить карту'**
  String get prepareMap;

  /// No description provided for @prepNext.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get prepNext;

  /// No description provided for @prepCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать планы'**
  String get prepCreate;

  /// No description provided for @prepStrategies.
  ///
  /// In ru, this message translates to:
  /// **'Тактики'**
  String get prepStrategies;

  /// No description provided for @prepMembers.
  ///
  /// In ru, this message translates to:
  /// **'Игроки'**
  String get prepMembers;

  /// No description provided for @prepPlan.
  ///
  /// In ru, this message translates to:
  /// **'Шаблон и срок'**
  String get prepPlan;

  /// No description provided for @prepTemplate.
  ///
  /// In ru, this message translates to:
  /// **'Шаблон тренировки'**
  String get prepTemplate;

  /// No description provided for @prepChooseStrategies.
  ///
  /// In ru, this message translates to:
  /// **'Выберите хотя бы одну тактику.'**
  String get prepChooseStrategies;

  /// No description provided for @prepChooseMembers.
  ///
  /// In ru, this message translates to:
  /// **'Выберите хотя бы одного игрока.'**
  String get prepChooseMembers;

  /// No description provided for @prepDeadlineRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите срок подготовки.'**
  String get prepDeadlineRequired;

  /// No description provided for @prepNoStrategies.
  ///
  /// In ru, this message translates to:
  /// **'Сначала создайте тактику для этой карты.'**
  String get prepNoStrategies;

  /// No description provided for @prepNoMembers.
  ///
  /// In ru, this message translates to:
  /// **'Загрузите состав онлайн-команды и добавьте аккаунты игроков.'**
  String get prepNoMembers;

  /// No description provided for @prepBatchLimit.
  ///
  /// In ru, this message translates to:
  /// **'За один раз можно создать не более 500 заданий.'**
  String get prepBatchLimit;

  /// No description provided for @prepRosterChanged.
  ///
  /// In ru, this message translates to:
  /// **'Состав или тактики изменились. Откройте мастер заново.'**
  String get prepRosterChanged;

  /// No description provided for @prepCount.
  ///
  /// In ru, this message translates to:
  /// **'Будет создано заданий: {count}'**
  String prepCount(int count);

  /// No description provided for @prepCreated.
  ///
  /// In ru, this message translates to:
  /// **'Создано заданий: {count}'**
  String prepCreated(int count);

  /// No description provided for @prepCriteriaRole.
  ///
  /// In ru, this message translates to:
  /// **'Назвать стартовую позицию, маршрут, свои гранаты и действия после контакта.'**
  String get prepCriteriaRole;

  /// No description provided for @prepCriteriaDryRun.
  ///
  /// In ru, this message translates to:
  /// **'Пройти тактику без противника, проверить тайминги и порядок гранат.'**
  String get prepCriteriaDryRun;

  /// No description provided for @prepCriteriaExecute.
  ///
  /// In ru, this message translates to:
  /// **'Выполнить выход вместе с составом и разобрать ошибки после попытки.'**
  String get prepCriteriaExecute;

  /// No description provided for @prepCriteriaRetake.
  ///
  /// In ru, this message translates to:
  /// **'Согласовать позиции, размены и порядок выхода при возврате точки.'**
  String get prepCriteriaRetake;

  /// No description provided for @prepAssignTactics.
  ///
  /// In ru, this message translates to:
  /// **'Распределение по тактикам'**
  String get prepAssignTactics;

  /// No description provided for @prepAssigneeCount.
  ///
  /// In ru, this message translates to:
  /// **'Исполнителей: {count}'**
  String prepAssigneeCount(int count);

  /// No description provided for @prepChooseAssignments.
  ///
  /// In ru, this message translates to:
  /// **'Укажите исполнителя для каждой выбранной тактики.'**
  String get prepChooseAssignments;

  /// No description provided for @syncUnlinkedTasks.
  ///
  /// In ru, this message translates to:
  /// **'Остальные данные синхронизированы. У части заданий нет аккаунта исполнителя: откройте тренировки и измените их планы.'**
  String get syncUnlinkedTasks;

  /// No description provided for @taskUnlinkedAssignee.
  ///
  /// In ru, this message translates to:
  /// **'Прежний игрок — выберите аккаунт'**
  String get taskUnlinkedAssignee;

  /// No description provided for @taskDiscussion.
  ///
  /// In ru, this message translates to:
  /// **'Обсуждение'**
  String get taskDiscussion;

  /// No description provided for @discussionMessage.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get discussionMessage;

  /// No description provided for @discussionSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get discussionSend;

  /// No description provided for @discussionRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить / повторить'**
  String get discussionRefresh;

  /// No description provided for @discussionOffline.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить обсуждение. Загруженные комментарии и очередь остаются на устройстве. Откройте или обновите обсуждение для повтора.'**
  String get discussionOffline;

  /// No description provided for @discussionPending.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает отправки — сохранено на устройстве'**
  String get discussionPending;

  /// No description provided for @discussionFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить комментарий. Проверьте аккаунт, права и лимит очереди.'**
  String get discussionFailed;

  /// No description provided for @taskEvidence.
  ///
  /// In ru, this message translates to:
  /// **'Доказательства'**
  String get taskEvidence;

  /// No description provided for @evidenceImage.
  ///
  /// In ru, this message translates to:
  /// **'Скриншот'**
  String get evidenceImage;

  /// No description provided for @evidenceVideo.
  ///
  /// In ru, this message translates to:
  /// **'MP4'**
  String get evidenceVideo;

  /// No description provided for @evidenceHelp.
  ///
  /// In ru, this message translates to:
  /// **'Свои PNG/JPEG или MP4, до 20 МБ на файл. Загрузка не сдаёт и не принимает задание. Откройте полученный файл, чтобы сохранить локальную копию.'**
  String get evidenceHelp;

  /// No description provided for @evidenceFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прикрепить или открыть файл. Проверьте файл, связь, права и квоту хранилища команды.'**
  String get evidenceFailed;

  /// No description provided for @evidenceRemovePending.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из очереди'**
  String get evidenceRemovePending;

  /// No description provided for @evidenceLimits.
  ///
  /// In ru, this message translates to:
  /// **'Форматы и ограничения'**
  String get evidenceLimits;

  /// No description provided for @evidenceImageType.
  ///
  /// In ru, this message translates to:
  /// **'Изображение'**
  String get evidenceImageType;

  /// No description provided for @evidenceVideoType.
  ///
  /// In ru, this message translates to:
  /// **'Видео'**
  String get evidenceVideoType;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
