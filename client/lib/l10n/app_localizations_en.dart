// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'TeamSync';

  @override
  String get overview => 'Overview';

  @override
  String get maps => 'Maps';

  @override
  String get strategies => 'Strategies';

  @override
  String get training => 'Training';

  @override
  String get demos => 'Demos';

  @override
  String get team => 'Team';

  @override
  String get settings => 'Settings';

  @override
  String get more => 'More';

  @override
  String get localWorkspace => 'Local workspace';

  @override
  String get localNotice =>
      'An account is required. Existing materials are preserved and can be linked to an online team in the account section.';

  @override
  String get createTeam => 'Create team';

  @override
  String get teamName => 'Team name';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save version';

  @override
  String get saved => 'Saved locally';

  @override
  String get name => 'Name';

  @override
  String get title => 'Title';

  @override
  String get notes => 'Notes';

  @override
  String get addMap => 'Add map';

  @override
  String get addMember => 'Add member';

  @override
  String get newStrategy => 'New strategy';

  @override
  String get newTask => 'New task';

  @override
  String get noTeams => 'Your team\'s preparation starts here';

  @override
  String get noTeamsBody =>
      'Sign in with Steam or Discord, create a team or accept an invitation. Team tactics sync between members.';

  @override
  String get emptyMaps =>
      'No maps yet. Add a map by name, then import your own radar image.';

  @override
  String get emptyStrategies =>
      'No strategies yet. Add a map to start preparing a round.';

  @override
  String get emptyTasks =>
      'No tasks yet. Create a task or assign one from a strategy.';

  @override
  String get emptyMembers =>
      'Add players and their game roles to your local roster.';

  @override
  String get emptyDemos =>
      'No demo files. Import your own CS2 .dem file to keep it in the local library.';

  @override
  String get selectMap => 'Map';

  @override
  String get side => 'Side';

  @override
  String get role => 'Access role';

  @override
  String get gameRole => 'Game role';

  @override
  String get owner => 'Owner';

  @override
  String get captain => 'Captain';

  @override
  String get coach => 'Coach';

  @override
  String get player => 'Player';

  @override
  String get viewer => 'Viewer';

  @override
  String get todo => 'To do';

  @override
  String get submitted => 'Awaiting review';

  @override
  String get approved => 'Approved';

  @override
  String get submit => 'Submit for review';

  @override
  String get approve => 'Approve';

  @override
  String get returnTask => 'Return to work';

  @override
  String get assignee => 'Assignee';

  @override
  String get unassigned => 'Unassigned';

  @override
  String get strategyLink => 'Linked strategy';

  @override
  String get noLink => 'No linked strategy';

  @override
  String get openStrategy => 'Open strategy';

  @override
  String get back => 'Back';

  @override
  String get importRadar => 'Import radar image';

  @override
  String get radarHelp =>
      'Import your own PNG or JPEG radar. Objects are positioned relative to the image. Game coordinate calibration is not available yet.';

  @override
  String get invalidImage => 'Choose a valid PNG or JPEG image under 20 MB.';

  @override
  String get marker => 'Player marker';

  @override
  String get smoke => 'Smoke';

  @override
  String get flash => 'Flashbang';

  @override
  String get molotov => 'Molotov';

  @override
  String get arrow => 'Movement';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get clear => 'Clear objects';

  @override
  String get history => 'Version history';

  @override
  String get restore => 'Restore as new version';

  @override
  String version(int number) {
    return 'Version $number';
  }

  @override
  String get unsaved => 'Unsaved changes';

  @override
  String get leaveTitle => 'Save your changes?';

  @override
  String get discard => 'Discard';

  @override
  String get stay => 'Keep editing';

  @override
  String get language => 'Interface language';

  @override
  String get storage => 'Data directory';

  @override
  String get stageNotice =>
      'Early build with local preparation and configurable online accounts. Shared editing, demo parsing, scheduling and server management are still in development.';

  @override
  String get importDemo => 'Import .dem';

  @override
  String get demoNotice =>
      'Files are copied to this device. Parsing, playback and launching CS2 are not available in this build.';

  @override
  String get invalidDemo =>
      'This file is not a supported CS2 demo (PBDEMS2) or exceeds the 2 GB import limit.';

  @override
  String get fileMissing => 'The local file is missing. Import it again.';

  @override
  String get imported => 'File imported';

  @override
  String get error =>
      'The operation could not be completed. Your existing data has been kept.';

  @override
  String get invalidText => 'Enter a value within the field\'s length limit.';

  @override
  String get conflict =>
      'This strategy has changed. Reopen it before saving; keep a copy of your notes.';

  @override
  String get startupError =>
      'The local database could not be opened. Check available disk space and folder permissions, then retry. Existing data has not been reset.';

  @override
  String get retry => 'Retry';

  @override
  String get localRoles =>
      'Roster roles are local metadata. Server access control will be enabled with online teams.';

  @override
  String get preparation => 'Preparation';

  @override
  String get readiness => 'Task completion';

  @override
  String get noData => 'No data';

  @override
  String get readinessDetail =>
      'Approved tasks out of all local tasks. Skill confirmation and weighted map readiness are not calculated yet.';

  @override
  String get nextSteps => 'Prepare your next practice';

  @override
  String get nextStepsBody =>
      'Add the team\'s maps, write a strategy and assign responsibilities. All current materials remain available offline on this device.';

  @override
  String teamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String taskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
      zero: 'No tasks',
    );
    return '$_temp0';
  }

  @override
  String get imageRequired => 'Import a radar image to place tactical objects.';

  @override
  String get selectTeam => 'Switch team';

  @override
  String fileSize(String size) {
    return '$size MB';
  }

  @override
  String objectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objects',
      one: '1 object',
      zero: 'No objects',
    );
    return '$_temp0';
  }

  @override
  String get tipArrow =>
      'Drag to draw a movement arrow. Tap for other objects.';

  @override
  String get taskDetails => 'Task details';

  @override
  String get exportPdf => 'Export PDF playbook';

  @override
  String get exportLanguage => 'Playbook language';

  @override
  String get pdfHelp =>
      'Export all current strategies and their linked tasks. Your content stays in its original language. Radar images include tactical objects.';

  @override
  String get backup => 'Export offline package';

  @override
  String get backupHelp =>
      'Includes this team\'s roster, maps, radar images, strategies and tasks. Original demo files and external videos are excluded. Maximum package size: 100 MB.';

  @override
  String get restorePackage => 'Import offline package';

  @override
  String get packageError =>
      'Invalid, incomplete or oversized offline package. Existing teams have not been changed.';

  @override
  String get packageImported => 'Package imported as a new local team';

  @override
  String get exported => 'Export saved';

  @override
  String get onlineAccount => 'Online account';

  @override
  String get accountHelp =>
      'Sign in with Steam or Discord to work on your team’s shared tactics. Passwords are entered only on the provider’s page.';

  @override
  String get serverAddress => 'TeamSync API address';

  @override
  String get connect => 'Connect';

  @override
  String get connectionError =>
      'Could not connect or complete the request. Check the server address, network and server configuration.';

  @override
  String get invalidServer =>
      'Use an HTTPS server address without a path, or http://127.0.0.1:8000 for local development.';

  @override
  String get providerNotConfigured =>
      'This login provider has not been configured on the server.';

  @override
  String get sessionExpired =>
      'Your session has expired or been revoked. Sign in again.';

  @override
  String get loginTimeout => 'Sign-in timed out. Try again.';

  @override
  String get loginCancelled => 'Sign-in cancelled.';

  @override
  String get reauthenticate => 'Sign in again before changing linked accounts.';

  @override
  String get lastIdentity =>
      'Link another login provider before unlinking the last one.';

  @override
  String get loginComplete =>
      'You can return to TeamSync. Sign-in will finish in the app.';

  @override
  String get signInSteam => 'Sign in with Steam';

  @override
  String get signInDiscord => 'Sign in with Discord';

  @override
  String get signOut => 'Sign out';

  @override
  String get refresh => 'Refresh';

  @override
  String get onlineTeams => 'Online teams';

  @override
  String get onlineTeamsHelp =>
      'Choose a team to invite players and open its shared tactics library.';

  @override
  String get joinTeam => 'Join by code';

  @override
  String get inviteCode => 'Invitation code';

  @override
  String get inviteExpiry =>
      'Single-use player invitation. Expires in 24 hours.';

  @override
  String get inviteMember => 'Invite player';

  @override
  String get activeDevices => 'Active devices';

  @override
  String get revokeSession => 'End session';

  @override
  String get linkProvider => 'Link account';

  @override
  String get unlinkProvider => 'Unlink account';

  @override
  String get catalog => 'Catalog';

  @override
  String get library => 'My library';

  @override
  String get downloads => 'Downloads';

  @override
  String get favorites => 'Favorites';

  @override
  String get mapsReady => 'Maps ready to prepare';

  @override
  String get mapsReadyBody =>
      'Radars, levels and covers ship with the app. Choose a map and start preparing.';

  @override
  String get workspaceLabel => 'TEAM WORKSPACE';

  @override
  String get gameLibrary => 'CS2 LIBRARY';

  @override
  String get searchWorkspace => 'Search this section…';

  @override
  String get recentStrategies => 'Recent strategies';

  @override
  String get openMap => 'Open map';

  @override
  String get readyOffline => 'Available offline';

  @override
  String get yourMapPool => 'Team map library';

  @override
  String get allMaps => 'All maps';

  @override
  String get upperLevel => 'Upper level';

  @override
  String get lowerLevel => 'Lower level';

  @override
  String get chooseLevel => 'Map level';

  @override
  String get customMap => 'Custom map';

  @override
  String get versionedRadar => 'Calibrated radar';

  @override
  String get libraryDescription =>
      'Match recordings, real events and prepared reviews in one library.';

  @override
  String get importArchive => 'Import demo or archive';

  @override
  String get importLink => 'Download from link';

  @override
  String get sourcePage => 'HLTV match page — optional';

  @override
  String get downloadUrl => 'Direct HTTPS demo or archive URL';

  @override
  String get importSourceHelp =>
      'Download a demo from the HLTV match page and import the .rar, .zip or .dem. Or paste a direct file link. The match page is saved as provenance.';

  @override
  String get hltvStatus => 'HLTV · source import';

  @override
  String get hltvManual =>
      'Open a match, download its recording and import it. The parser extracts players, map, rounds and events from the file itself. Automatic HLTV catalog access is not connected.';

  @override
  String get openHLTV => 'Open HLTV';

  @override
  String get sourceBlocked =>
      'The source restricted automatic download. Open the link in your browser, download the file and import the archive.';

  @override
  String get openSource => 'Open source';

  @override
  String get analyzeDemo => 'Analyze demo';

  @override
  String get watchReview => 'Open review';

  @override
  String get parsed => 'Review ready';

  @override
  String get notAnalyzed => 'Not analyzed';

  @override
  String get parserMissing =>
      'The parser module is missing. Install the complete TeamSync Windows build.';

  @override
  String get desktopParser =>
      'Large demos are analyzed on desktop. Import a prepared .teamsync-review file here to view its 2D review.';

  @override
  String get parseFailed =>
      'The recording could not be parsed. It may be damaged or recorded by an incompatible CS2 version.';

  @override
  String get unsafeArchive =>
      'Archive rejected: unsafe paths, encryption or size limits.';

  @override
  String get unsafeDownload =>
      'Use a public HTTPS file link. Local and private network addresses are not accepted.';

  @override
  String get parseTimeout =>
      'Analysis exceeded the time limit. Try a single map instead of a large archive.';

  @override
  String get jobStarting => 'Preparing import';

  @override
  String get jobDownload => 'Downloading file';

  @override
  String get jobExtract => 'Extracting archive';

  @override
  String get jobParse => 'Analyzing recording';

  @override
  String get jobPositions => 'Reading player positions';

  @override
  String get jobEvents => 'Reading events';

  @override
  String get jobIndex => 'Preparing playback';

  @override
  String get jobComplete => 'Complete';

  @override
  String get jobCancelled => 'Operation cancelled';

  @override
  String get noDownloads => 'No active downloads';

  @override
  String get measuredData => 'Recorded positions · coach overview';

  @override
  String get sampledPlayback =>
      'Movement is smoothed between recorded snapshots as a visual approximation. Events and notes remain tick-based; round changes and teleports are not interpolated.';

  @override
  String get radarRevisionNotice =>
      'Uses the bundled radar revision. Geometry in an older recording may differ.';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get nextFrame => 'Next snapshot';

  @override
  String get previousFrame => 'Previous snapshot';

  @override
  String get roundLabel => 'Round';

  @override
  String get players => 'Players';

  @override
  String get events => 'Events';

  @override
  String get allSides => 'Both sides';

  @override
  String get annotations => 'Review notes';

  @override
  String get addAnnotation => 'Add note';

  @override
  String get createTaskFromNote => 'Task from note';

  @override
  String get exportReview => 'Share review to phone';

  @override
  String get reviewDataInvalid => 'Invalid review file';

  @override
  String get noCalibration =>
      'This map has no bundled calibration. Events and statistics are available; positions are hidden.';

  @override
  String get matchDetails => 'Maps and players';

  @override
  String get scoreboard => 'Player statistics';

  @override
  String get followPlayer => 'Follow player';

  @override
  String get showTrails => 'Movement trails';

  @override
  String get tickLabel => 'Tick';

  @override
  String get killsLabel => 'Kills';

  @override
  String get deathsLabel => 'Deaths';

  @override
  String get assistsLabel => 'Assists';

  @override
  String get viewAll => 'View all';

  @override
  String get workspaceSubtitle => 'Preparation that turns into team play.';

  @override
  String get bombPlanted => 'Bomb planted';

  @override
  String get bombDefused => 'Bomb defused';

  @override
  String get bombExploded => 'Bomb exploded';

  @override
  String get eventPoints =>
      'Grenades use recorded event points, without invented smoke or fire geometry.';

  @override
  String get playerT => 'T player · amber circle';

  @override
  String get playerCT => 'CT player · blue shield';

  @override
  String get playerLegend =>
      'T1–T5 — attack · CT1–CT5 — defence. Each side has its own numbering.';

  @override
  String get playbooks => 'Playbooks / PDF';

  @override
  String get newPlaybook => 'New playbook';

  @override
  String get attachToPlaybook => 'Add to playbook / PDF';

  @override
  String get playbookHelp =>
      'Build round pages with a plan, economy, roles and tactic snapshots. Attached diagrams stay fixed when the original tactic changes.';

  @override
  String get roundPlan => 'Round plan';

  @override
  String get economy => 'Economy / buy';

  @override
  String get responsibilities => 'Roles and timings';

  @override
  String get addRound => 'Add round page';

  @override
  String get attachTactic => 'Attach tactic diagram';

  @override
  String get snapshotSaved => 'Tactic snapshot added to playbook';

  @override
  String get exportDocument => 'Save PDF';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get removePage => 'Remove page';

  @override
  String get removeAttachment => 'Remove diagram';

  @override
  String get bootcamp => 'Bootcamp';

  @override
  String get bootcampHelp =>
      'Install CS2 and TeamSpeak here, add MatchZy, then start your LAN servers with a button.';

  @override
  String get csExecutable => 'Select cs2.exe';

  @override
  String get tsExecutable => 'Select ts3server.exe';

  @override
  String get steamExecutable => 'Select steam.exe';

  @override
  String get startBoth => 'Start CS2 + TeamSpeak';

  @override
  String get startServer => 'Start';

  @override
  String get stopServer => 'Stop';

  @override
  String get restartServer => 'Restart';

  @override
  String get connectServer => 'Connect';

  @override
  String get serverStopped => 'Stopped';

  @override
  String get serverStarting => 'Process started · checking port';

  @override
  String get serverReady => 'LAN port responds';

  @override
  String get serverFailed => 'Process exited';

  @override
  String get chooseExecutables => 'Select existing server executables first.';

  @override
  String get serverProfile => 'CS2 profile';

  @override
  String get practiceProfile => 'Practice';

  @override
  String get scrimProfile => 'PUG / scrim · MatchZy';

  @override
  String get bootcampLimits =>
      'CS2 and TS3 download as separate components into the selected folder. Accept the TS3 licence after reading it. PUG and advanced practice use MatchZy. Internet reachability is not tested; firewall settings are not changed.';

  @override
  String get getTeamspeak => 'Download TeamSpeak server';

  @override
  String get serverLog => 'Process log';

  @override
  String get serverPort => 'CS2 port';

  @override
  String get lanAddress => 'This PC’s LAN addresses';

  @override
  String get localHostOnly => 'Server hosting is available on Windows';

  @override
  String get openInCS => 'Open in CS2';

  @override
  String get csLaunchHelp =>
      'Steam is launching the demo. If CS2 is already open, close it and try again or paste the copied command into its console.';

  @override
  String get csLaunchError =>
      'Could not open demo. Check CS2 and Steam paths in Bootcamp and make sure the original DEM exists.';

  @override
  String get scouting => 'Match tags';

  @override
  String get scoutingHelp =>
      'Teams, tournament, tier and roles are tagged by the coach. Describe positions with map and side context; these are not official HLTV roles.';

  @override
  String get matchTeams => 'Teams (comma separated)';

  @override
  String get tournament => 'Tournament';

  @override
  String get tournamentTier => 'Tournament tier';

  @override
  String get playerPositions =>
      'Positions / roles (one per line: player — side — position)';

  @override
  String get filterTeam => 'Team';

  @override
  String get filterPosition => 'Position / role';

  @override
  String get allTiers => 'All tiers';

  @override
  String get untagged => 'Untagged';

  @override
  String get hltvInbox => 'HLTV catalog';

  @override
  String get hltvInboxHelp =>
      'Open a match, select your download folder and download its Demo in the browser. TeamSync picks up a new DEM / RAR / ZIP, extracts it and adds it to your library. Browser checks stay in the browser.';

  @override
  String get watchDownloads => 'Open match and wait for download';

  @override
  String get waitingDownload =>
      'Waiting for a new demo in the selected folder. Keep this section open.';

  @override
  String get stopWaiting => 'Stop waiting';

  @override
  String get chooseDownloadFolder => 'Browser download folder';

  @override
  String get matchPage => 'HLTV match URL';

  @override
  String get timelineNotes => 'Note markers · click to seek';

  @override
  String get noteAt => 'Note at current time';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get invalidServerPort => 'Enter a port from 1024 to 65535';

  @override
  String get serverBusy => 'Stop servers before changing settings';

  @override
  String get noServerLogs => 'Logs appear after starting';

  @override
  String get captureVersion => 'Version snapshot';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get tsLicenseHelp =>
      'TeamSpeak: install the server separately and run it manually once to accept its licence. Then select ts3server.exe.';

  @override
  String get chooseServerInstallation =>
      'Select a separate CS2 Dedicated Server installation for hosting and plugins. The client game is used only to view demos.';

  @override
  String get serverExecutable => 'Server: select cs2.exe';

  @override
  String get pluginHelp =>
      'Downloads pinned official versions, checks SHA-256, backs up replaced files and enables Metamod in gameinfo.gi. Existing MatchZy configs are preserved. Check plugin loading after CS2 updates.';

  @override
  String get installPlugin => 'Install MatchZy and dependencies';

  @override
  String get pluginInstalled =>
      'MatchZy files installed. Start the server and check plugin status.';

  @override
  String get pluginInstallFailed =>
      'Installation did not complete. Check the dedicated server path, network connection and log.';

  @override
  String get pluginCommands =>
      'PUG: .ready / .unready · .pause / .unpause · .stay / .switch.\nPractice: .prac · .savenade name · .loadnade name · .rethrow · .traj · .clear · .bot · .ctspawn 1. Enter these in CS2 chat; admin commands require permission.';

  @override
  String get pluginLoaded => 'MatchZy loaded';

  @override
  String get pluginNotVerified => 'MatchZy loading not yet confirmed';

  @override
  String get applyPractice => 'Enable server practice';

  @override
  String get applyScrim => 'Return to PUG mode';

  @override
  String get pluginCommandFailed =>
      'Command not confirmed. Check MatchZy loading and server log.';

  @override
  String get commandSent =>
      'Command sent to the server; see the log for its response.';

  @override
  String get matchSetup => 'Match and veto';

  @override
  String get matchSetupHelp =>
      'Enter real player SteamID64s. Captains veto in CS2, then ready and knife. Selecting one map skips veto.';

  @override
  String get steamRoster => 'Roster: SteamID64 and name, one per line';

  @override
  String get invalidMatchRoster =>
      'Each team needs 1–5 unique SteamID64s with no overlap. Select enough maps for the BO.';

  @override
  String get loadMatch => 'Load match on server';

  @override
  String get refreshCatalog => 'Refresh HLTV';

  @override
  String get catalogPrevious => 'Newer';

  @override
  String get catalogNext => 'Older';

  @override
  String get anyStars => 'Any rating';

  @override
  String get catalogPosition => 'Position (my tags)';

  @override
  String get catalogFilterHelp =>
      'Search covers this page of 100 matches. Stars are HLTV match ratings, not tournament tiers. Tag each event’s tier yourself; position search uses your imported demo tags.';

  @override
  String get catalogUpdated => 'Fetched:';

  @override
  String get downloadAndAnalyze => 'Download and analyze';

  @override
  String get coachTier => 'Tier · coach tag';

  @override
  String get hltvNoDemo => 'This match page does not have a Demo link yet.';

  @override
  String get hltvUnavailable =>
      'HLTV did not respond or restricted the request. Cached matches remain available; open the match in your browser or try again later.';

  @override
  String get hltvRateLimit =>
      'HLTV requested fewer requests. Cached matches remain available; try again in a few minutes.';

  @override
  String get hltvBrowserFallback =>
      'The catalog and link are ready, but the archive server restricted direct download. Download in the opened browser; TeamSync will pick it up from the selected folder.';

  @override
  String get serverFolder => 'Server installation folder';

  @override
  String get serverFilesReady => 'Server files installed; path saved';

  @override
  String get serverDiskSpace =>
      'Not enough space: first CS2 installation needs at least 110 GB free, and an update needs 11 GB.';

  @override
  String get serverSetupError =>
      'Installation did not complete. Check free space, folder permissions and network. Retry CS2 installation to resume SteamCMD. If an official archive changed, TeamSync needs an update.';

  @override
  String get serverContentDownload => 'Downloading / verifying server content';

  @override
  String get steamcmdPreparing => 'Preparing SteamCMD and connecting to Steam';

  @override
  String get downloadServerFiles => 'Install servers from TeamSync';

  @override
  String get serverDownloadHelp =>
      'CS2 downloads directly via Valve SteamCMD (large download: roughly 80–100 GB; requires 110 GB free). TeamSpeak 3.13.8 uses its official archive, about 9 MB. A separate TeamSyncServers folder is created. Servers do not start automatically.';

  @override
  String get downloadCsServer => 'Install / resume CS2';

  @override
  String get downloadTsServer => 'Install TeamSpeak';

  @override
  String get acceptTsLicense => 'I have read and accept the TeamSpeak licence';

  @override
  String get tsLicense => 'TeamSpeak licence';

  @override
  String get continueLabel => 'Continue';

  @override
  String get hltvDesktopCatalog =>
      'The HLTV catalog loads on Windows. On a phone, use prepared reviews or the HLTV website in your browser.';

  @override
  String get sourceVerification => 'Connecting and verifying the HLTV source';

  @override
  String get downloadRuntimeMissing =>
      'The download component is missing. Reinstall TeamSync while online to install the required Microsoft component.';

  @override
  String get managedDownloadFailed =>
      'Download did not complete. If a source verification window appeared, confirm access and retry. Check your connection and free space.';

  @override
  String get accountId => 'Account ID';

  @override
  String get copyAccountId => 'Copy account ID';

  @override
  String get accountInvite => 'Invite account';

  @override
  String get accountLookup => 'Player account ID';

  @override
  String get acceptInvite => 'Accept';

  @override
  String get declineInvite => 'Decline';

  @override
  String get incomingInvites => 'Team invitations';

  @override
  String get outgoingInvites => 'Sent invitations';

  @override
  String get cancelInvite => 'Revoke invitation';

  @override
  String get openRoster => 'Open roster';

  @override
  String get squad => 'Squad';

  @override
  String get mainSquad => 'Main roster';

  @override
  String get reserveSquad => 'Reserves';

  @override
  String get staffSquad => 'Staff';

  @override
  String get leaveTeam => 'Leave team';

  @override
  String get removePlayer => 'Remove member';

  @override
  String get accountNotFound =>
      'Account not found. Ask the player to copy their ID from their profile.';

  @override
  String get inviteInvalid => 'This invitation expired or was revoked.';

  @override
  String get alreadyMember => 'This account is already on the team.';

  @override
  String get accessDenied => 'You do not have permission for this action.';

  @override
  String get writeConflict =>
      'An invitation already exists or the data changed. Refresh the list.';

  @override
  String get ownershipRequired => 'Transfer ownership to another member first.';

  @override
  String get confirmAction => 'Confirm this action?';

  @override
  String get transferOwner => 'Transfer ownership';

  @override
  String get openInWorkspace => 'Open shared tactics';

  @override
  String get rosterLocalHelp =>
      'Open the team’s shared tactics on this device. Drawings and notes sync between desktop and phone.';

  @override
  String get editProfile => 'Edit display name';

  @override
  String get serverWaking =>
      'Connecting. After inactivity a free server may take about a minute to start.';

  @override
  String get accountTeamHelp =>
      'Invite a player using their account ID. They can accept the invitation in their profile.';

  @override
  String get accountRosterManaged => 'Manage roster by accounts';

  @override
  String get copied => 'Copied';

  @override
  String get inviteSent => 'Invitation sent';

  @override
  String get syncTactics => 'Shared tactics';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncWorking => 'Syncing…';

  @override
  String get syncReady => 'Tactics are up to date';

  @override
  String get syncOffline =>
      'Offline. Changes are saved on this device and will upload when connected.';

  @override
  String get syncConflict =>
      'Both versions were kept. Review the conflict copy in tactics.';

  @override
  String get syncConflictCopy => 'Conflict copy';

  @override
  String get syncAccountMismatch =>
      'Sign in to the account linked to this team.';

  @override
  String get readOnlyTeam =>
      'Your role can view shared tactics. Owners, captains and coaches can edit them.';

  @override
  String get syncTeamHelp =>
      'Tactics, map drawings and notes are shared by the whole online team. Saved changes sync automatically; offline changes stay on your device.';

  @override
  String get linkWorkspace => 'Connect shared tactics';

  @override
  String get newSharedWorkspace => 'New workspace';

  @override
  String get linkTeamExplain =>
      'Choose a workspace. Its tactics will be shared with this team and teammates’ changes will appear here.';

  @override
  String get syncAccessLost =>
      'Team access was revoked. Local materials are preserved; synchronization has stopped.';

  @override
  String get utilityLibrary => 'Utilities';

  @override
  String get newUtility => 'New utility';

  @override
  String get editUtility => 'Edit utility';

  @override
  String get utilityInstruction => 'Instructions and timing';

  @override
  String get utilitySource => 'YouTube / CS2Tricks link';

  @override
  String get utilitySourceHelp =>
      'Open the original source. If the video is unavailable, use the saved instructions. External media is not downloaded.';

  @override
  String get utilityEmpty =>
      'Add a team utility: map, position, instructions and source.';

  @override
  String get utilityGrenade => 'Grenade type';

  @override
  String get utilityStart => 'Start position';

  @override
  String get utilityTarget => 'Target';

  @override
  String get utilityThrow => 'Throw type';

  @override
  String get utilityAuthor => 'Original author';

  @override
  String get utilityVerified => 'Verified, ISO date';

  @override
  String get utilityRevision => 'Map revision';

  @override
  String get utilityOpen => 'Open original';

  @override
  String get utilityUnavailable =>
      'Could not open the source. Saved instructions remain available.';

  @override
  String get utilityInvalidSource =>
      'Use an HTTPS YouTube or CS2Tricks link without credentials.';

  @override
  String get grenadeHe => 'HE grenade';

  @override
  String get grenadeDecoy => 'Decoy';

  @override
  String get editMaterial => 'Edit';

  @override
  String get utilityTactics => 'Linked tactics';

  @override
  String get utilityScreenshots => 'Aim screenshots';

  @override
  String get utilityAddImage => 'Add own image';

  @override
  String get utilityRemoveImage => 'Remove image';

  @override
  String get syncReadOnlyPending =>
      'Local edits are preserved. Your current role cannot publish them.';

  @override
  String get syncMediaQuota => 'The team attachment limit has been reached.';

  @override
  String get utilityVideo => 'Own video clip';

  @override
  String get utilityAddVideo => 'Add own MP4';

  @override
  String get utilityOpenVideo => 'Watch clip';

  @override
  String get utilityShareVideo => 'Share file';

  @override
  String get utilityRemoveVideo => 'Remove clip';

  @override
  String get utilityVideoLimit =>
      'Own MP4 up to 20 MB. Clips sync with the team and are saved for offline viewing.';

  @override
  String get invalidVideo => 'Choose an MP4 with a video track, up to 20 MB.';

  @override
  String get videoUnavailable =>
      'Could not open the clip. Use Share file to choose a compatible player.';

  @override
  String get skillTitle => 'Study and verification';

  @override
  String get skillSelf => 'My status';

  @override
  String get skillNotStarted => 'Not studied';

  @override
  String get skillLearning => 'Learning';

  @override
  String get skillReady => 'Ready for review';

  @override
  String get skillConfirmed => 'Confirmed';

  @override
  String get skillTeam => 'Review roster';

  @override
  String get skillRecheck => 'A new review is required';

  @override
  String get skillRequestRecheck => 'Request skill re-verification';

  @override
  String get skillReason => 'Reason for re-verification';

  @override
  String get skillReturnReason => 'Reason for returning to practice';

  @override
  String get skillConflict => 'Status changed on another device';

  @override
  String get skillKeepRemote => 'Keep server status';

  @override
  String get skillKeepLocal => 'Send my status';

  @override
  String get skillPending => 'Saved locally';

  @override
  String get skillMaterialChanged =>
      'The utility changed. Close this window and reopen the review.';

  @override
  String get skillEmptyHistory => 'No verification history yet.';

  @override
  String get skillMember => 'Team member';

  @override
  String get skillReasonRequired => 'Enter the reason for re-verification.';

  @override
  String get taskInProgress => 'In progress';

  @override
  String get taskStart => 'Start task';

  @override
  String get taskReturnReason => 'Reason for returning the task';

  @override
  String get historyMore => 'Load more';

  @override
  String get taskType => 'Training type';

  @override
  String get taskTypeUtility => 'Study a lineup';

  @override
  String get taskTypeTactic => 'Learn a tactical role';

  @override
  String get taskTypeDryRun => 'Complete a dry run';

  @override
  String get taskTypeExecute => 'Practice an execute';

  @override
  String get taskTypeRetake => 'Practice a retake';

  @override
  String get taskTypeDemo => 'Watch a demo';

  @override
  String get taskTypeRound => 'Review a round';

  @override
  String get taskTypeFix => 'Correct a mistake';

  @override
  String get taskTypeQuiz => 'Knowledge check';

  @override
  String get taskDeadline => 'Due date';

  @override
  String get taskNoDeadline => 'No deadline';

  @override
  String get taskClearDeadline => 'Clear deadline';

  @override
  String get taskDeadlineHelp =>
      'Choose a time on this device. Teammates see the deadline in their own time zone.';

  @override
  String get taskCriteria => 'Completion criteria';

  @override
  String get editTaskPlan => 'Edit assignment plan';

  @override
  String get taskOverdue => 'Overdue';

  @override
  String get taskTypeGeneral => 'General assignment';

  @override
  String get taskCreate => 'Create assignment';

  @override
  String get taskSavePlan => 'Save plan';

  @override
  String get prepareMap => 'Prepare map';

  @override
  String get prepNext => 'Next';

  @override
  String get prepCreate => 'Create plans';

  @override
  String get prepStrategies => 'Tactics';

  @override
  String get prepMembers => 'Players';

  @override
  String get prepPlan => 'Template and deadline';

  @override
  String get prepTemplate => 'Training template';

  @override
  String get prepChooseStrategies => 'Select at least one tactic.';

  @override
  String get prepChooseMembers => 'Select at least one player.';

  @override
  String get prepDeadlineRequired => 'Choose a preparation deadline.';

  @override
  String get prepNoStrategies => 'Create a tactic for this map first.';

  @override
  String get prepNoMembers =>
      'Load the online team roster and add player accounts.';

  @override
  String get prepBatchLimit => 'Create at most 500 assignments in one batch.';

  @override
  String get prepRosterChanged =>
      'The roster or tactics changed. Reopen the wizard.';

  @override
  String prepCount(int count) {
    return 'Assignments to create: $count';
  }

  @override
  String prepCreated(int count) {
    return 'Created assignments: $count';
  }

  @override
  String get prepCriteriaRole =>
      'Explain the starting position, route, your utility and actions after contact.';

  @override
  String get prepCriteriaDryRun =>
      'Walk through the tactic without opponents and check timings and utility order.';

  @override
  String get prepCriteriaExecute =>
      'Execute with the squad and review mistakes after the attempt.';

  @override
  String get prepCriteriaRetake =>
      'Coordinate positions, trades and entry order when retaking the site.';

  @override
  String get prepAssignTactics => 'Assignments by tactic';

  @override
  String prepAssigneeCount(int count) {
    return 'Assigned players: $count';
  }

  @override
  String get prepChooseAssignments =>
      'Assign at least one player to every selected tactic.';

  @override
  String get syncUnlinkedTasks =>
      'Other data is synced. Some tasks need an account assignee: open Training and edit their plans.';

  @override
  String get taskUnlinkedAssignee => 'Previous player — choose an account';

  @override
  String get taskDiscussion => 'Discussion';

  @override
  String get discussionMessage => 'Comment';

  @override
  String get discussionSend => 'Send';

  @override
  String get discussionRefresh => 'Refresh / retry';

  @override
  String get discussionOffline =>
      'Could not refresh the discussion. Cached comments and pending messages remain on this device. Open or refresh to retry.';

  @override
  String get discussionPending => 'Pending — saved on this device';

  @override
  String get discussionFailed =>
      'Could not save the comment. Check your account, permissions and queue limit.';

  @override
  String get taskEvidence => 'Evidence';

  @override
  String get evidenceImage => 'Add image';

  @override
  String get evidenceVideo => 'Add MP4';

  @override
  String get evidenceHelp =>
      'Own PNG/JPEG or MP4, up to 20 MB per file. Uploading does not submit or approve the task. Open a received file to keep a local copy.';

  @override
  String get evidenceFailed =>
      'Could not attach or open evidence. Check the file, connection, permissions and team storage quota.';

  @override
  String get evidenceRemovePending => 'Remove local retry';

  @override
  String get evidenceLimits => 'Formats and limits';

  @override
  String get evidenceImageType => 'Image';

  @override
  String get evidenceVideoType => 'Video';

  @override
  String get scheduleTitle => 'Schedule';

  @override
  String get schedulePractice => 'Practice';

  @override
  String get scheduleScrim => 'Scrim';

  @override
  String get scheduleReview => 'Review';

  @override
  String get scheduleNew => 'New event';

  @override
  String get scheduleEdit => 'Edit event';

  @override
  String get scheduleZone => 'Times use this device’s time zone';

  @override
  String get scheduleInvalidTime =>
      'Enter a title, a duration of 1 minute to 7 days, and a reason when cancelling.';

  @override
  String get scheduleRangeLimit => 'Select a range of up to 366 days.';

  @override
  String get scheduleOffline =>
      'Could not refresh. Previously loaded schedule data remains on this device.';

  @override
  String get schedulePending =>
      'Saved on this device. Open or refresh Schedule to retry.';

  @override
  String get scheduleConflict =>
      'The server has a newer version. Your local change is preserved below. Review the current data before removing and re-entering it.';

  @override
  String get scheduleDiscard => 'Discard this local change';

  @override
  String get scheduleParticipants => 'Participation & attendance';

  @override
  String get scheduleCancelled => 'Cancelled';

  @override
  String get scheduleCancelEvent => 'Cancel this event';

  @override
  String get scheduleCancelReason => 'Cancellation reason';

  @override
  String get scheduleSave => 'Save';

  @override
  String get scheduleUnavailable =>
      'Could not complete the action. Check your account, permissions and connection.';

  @override
  String get scheduleRecord => 'Attendance';

  @override
  String get scheduleReply => 'RSVP';

  @override
  String get rsvpUnknown => 'No response';

  @override
  String get rsvpGoing => 'Going';

  @override
  String get rsvpMaybe => 'Maybe';

  @override
  String get rsvpDeclined => 'Not going';

  @override
  String get attendanceUnmarked => 'Not recorded';

  @override
  String get attendancePresent => 'Present';

  @override
  String get attendanceLate => 'Late';

  @override
  String get attendanceAbsent => 'Absent';

  @override
  String get attendanceExcused => 'Excused';

  @override
  String get scheduleFormer => 'Former member';

  @override
  String get scheduleReason => 'Reason / note';

  @override
  String get scheduleCorrectReason =>
      'Explain why the recorded attendance is changing.';

  @override
  String get scheduleNotStarted =>
      'Attendance can be recorded after the event starts. An excused absence may be recorded in advance.';

  @override
  String get scheduleTimeLocked =>
      'This event has recorded attendance. Its time cannot be changed.';

  @override
  String get scheduleStart => 'Starts';

  @override
  String get scheduleEnd => 'Ends';

  @override
  String get scheduleLocation => 'Location / server';

  @override
  String get scheduleType => 'Event type';
}
