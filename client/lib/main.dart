import 'dart:io';
import 'dart:async';

import 'package:app_links/app_links.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/store.dart';
import 'data/files.dart';
import 'data/map_catalog.dart';
import 'l10n/app_localizations.dart';
import 'ui/workspace.dart';
import 'ui/kit.dart';
import 'data/account.dart';
import 'data/reminders.dart';
import 'ui/account_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  Store? store;
  Directory? directory;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => failed = false);
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      await MapCatalog.install(dir);
      final opened = Store('${dir.path}/teamsync.sqlite');
      if (!mounted) {
        opened.close();
        return;
      }
      setState(() {
        store = opened;
        directory = dir;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (store != null) {
      return TeamSyncApp(store: store!, files: LocalFiles(directory!));
    }
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: workspaceTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: failed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppLocalizations.of(context).startupError),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: load,
                            child: Text(AppLocalizations.of(context).retry),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData workspaceTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Studio.background,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: Studio.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: Studio.accent,
        onPrimary: Studio.background,
        surface: Studio.surface,
        onSurface: Studio.text,
        outline: Studio.border,
        outlineVariant: Studio.border,
      ),
  dividerColor: Studio.border,
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.4,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w600,
      letterSpacing: -.4,
    ),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 15, height: 1.6),
    bodyMedium: TextStyle(fontSize: 13, height: 1.6),
    labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Studio.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Studio.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Studio.accent),
    ),
    fillColor: Studio.surface,
    hintStyle: const TextStyle(color: Studio.muted, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    filled: true,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 46),
      side: const BorderSide(color: Studio.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    margin: EdgeInsets.zero,
    color: Studio.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Studio.background,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Studio.surface,
    indicatorColor: Studio.elevated,
    height: 72,
  ),
);

class TeamSyncApp extends StatefulWidget {
  final Store store;
  final LocalFiles files;
  const TeamSyncApp({super.key, required this.store, required this.files});
  @override
  State<TeamSyncApp> createState() => _TeamSyncAppState();
}

class _TeamSyncAppState extends State<TeamSyncApp> with WidgetsBindingObserver {
  late ReminderCoordinator reminders;
  late Locale locale;
  final navigation = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? links;
  String? lastCallback;
  @override
  void initState() {
    super.initState();
    locale = Locale(widget.store.setting('language') == 'en' ? 'en' : 'ru');
    reminders = ReminderCoordinator(widget.store)..start();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid || Platform.isIOS) {
      final appLinks = AppLinks();
      links = appLinks.uriLinkStream.listen(openCallback, onError: (_) {});
      appLinks.getInitialLink().then((uri) {
        if (uri != null) openCallback(uri);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    reminders.foreground = state == AppLifecycleState.resumed;
    if (reminders.foreground) unawaited(reminders.refresh());
  }

  void openCallback(Uri uri) {
    if (!AccountClient.isCallback(uri) ||
        AccountClient.loginInProgress ||
        lastCallback == uri.toString()) {
      return;
    }
    lastCallback = uri.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        navigation.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => AccountPage(
              store: widget.store,
              onLocale: changeLocale,
              callback: uri,
            ),
          ),
        );
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    links?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    reminders.dispose();
    super.dispose();
  }

  void changeLocale(String language) {
    try {
      widget.store.setSetting('language', language);
      setState(() => locale = Locale(language));
    } catch (_) {
      /* Preserve the current locale if disk storage fails. */
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigation,
    title: 'TeamSync',
    debugShowCheckedModeBanner: false,
    theme: workspaceTheme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Workspace(
      store: widget.store,
      files: widget.files,
      onLocale: changeLocale,
    ),
  );
}
