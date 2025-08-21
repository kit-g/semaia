import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:semaia/presentation/theme/theme.dart';
import 'package:semaia_api/semaia_api.dart';
import 'package:semaia_language/semaia_language.dart';
import 'package:semaia_models/semaia_models.dart';
import 'package:semaia_state/semaia_state.dart';
import 'package:semaia/core/config/config.dart';
import 'package:semaia/core/utils/headers.dart';
import 'package:semaia/core/utils/misc.dart';
import 'package:semaia/presentation/navigation/router.dart';
import 'package:semaia/presentation/theme/index.dart';

class Semaia extends StatelessWidget {
  const Semaia({super.key});

  @override
  Widget build(BuildContext context) {
    final api = Api(gateway: AppConfig.apiBaseUrl);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppTheme>(
          create: (_) => AppTheme(mode: ThemeMode.system),
        ),
        ChangeNotifierProvider<DatabaseInspector>(
          create: (_) => DatabaseInspector(
            queryService: api,
            connectorService: api,
          ),
        ),
        ChangeNotifierProvider<PackageProvider>(
          create: (_) => PackageProvider(),
        ),
        ChangeNotifierProvider<Preferences>(
          create: (_) => Preferences(),
        ),
        ChangeNotifierProvider<Chats>(
          create: (_) => Chats(service: api),
        ),
        ChangeNotifierProvider<Auth>(
          create: (context) => Auth(
            onLogin: (user, token) => _initApp(context, user: user, sessionToken: token),
            isWeb: kIsWeb,
          ),
        ),
      ],
      builder: (__, _) {
        return Consumer<AppTheme>(
          builder: (__, theme, _) {
            return _App(theme: theme);
          },
        );
      },
    );
  }
}

class _App extends StatefulWidget {
  final AppTheme theme;

  const _App({required this.theme});

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> with AfterLayoutMixin<_App> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      supportedLocales: const [
        Locale('en', 'CA'),
        Locale('fr', 'CA'),
      ],
      localizationsDelegates: const [
        LocsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme(
        ColorScheme.fromSeed(
          seedColor: const Color(0xEA7822AB),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: theme(
        ColorScheme.fromSeed(
          seedColor: const Color(0xEA7510E1),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: widget.theme.mode,
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.config,
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _disableBrowserContextMenu();
    Auth.of(context).initGoogleSign();

    _initApp(context);
  }

  static void _disableBrowserContextMenu() {
    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }
  }
}

Future<void> _initApp(BuildContext context, {User? user, String? sessionToken}) async {
  if (user == null) return;

  final preferences = Preferences.of(context);
  final inspector = DatabaseInspector.of(context);
  final package = PackageProvider.of(context);
  final chats = Chats.of(context);
  await preferences.init();

  AppRouter.config.refresh();

  final headers = requestHeaders(session: sessionToken);

  Api.instance.defaultHeaders = headers;

  inspector.init();
  // Stashes.of(context).init();
  chats.init();
  package.init(
    () {
      return PackageInfo.fromPlatform().then<Package>(
        (info) {
          return (
            appName: info.appName,
            version: info.version,
            build: info.buildNumber,
          );
        },
      );
    },
  );
}
