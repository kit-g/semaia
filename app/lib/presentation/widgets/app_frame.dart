import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:semaia_language/semaia_language.dart';
import 'package:semaia_state/semaia_state.dart';
import 'package:semaia/core/utils/logout.dart';
import 'package:semaia/presentation/navigation/router.dart';
import 'package:semaia/presentation/theme/index.dart';

class AppFrame extends StatelessWidget {
  final StatefulNavigationShell shell;

  const AppFrame({super.key, required this.shell});

  String get imageAsset => 'assets/favicon/favicon.png';

  @override
  Widget build(BuildContext context) {
    final L(:toDarkMode, :toLightMode, :info, :logOut, :search, :query) = L.of(context);

    final ThemeData(:brightness, :textTheme, :colorScheme) = Theme.of(context);

    final (icon, tooltip) = switch (brightness) {
      Brightness.dark => (const Icon(Icons.wb_sunny), toLightMode),
      Brightness.light => (const Icon(Icons.nights_stay), toDarkMode),
    };
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(imageAsset),
            );
          },
        ),
        title: Text(
          _title(context),
          style: _style(context),
        ),
        actions: [
          Selector<Auth, (String?, String?)>(
            selector: (_, provider) => (provider.user?.displayName, provider.user?.email),
            builder: (context, params, _) {
              final (fullname, email) = params;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (fullname != null) Text(fullname, style: textTheme.labelMedium),
                  if (email != null) Text(email, style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          Selector<Auth, String?>(
            selector: (_, provider) => provider.user?.avatar,
            builder: (context, avatar, _) {
              if (avatar == null) return const SizedBox();
              return SizedBox(
                width: 36,
                height: 36,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  child: Image.network(avatar),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Selector<Auth, bool>(
            selector: (_, provider) => provider.isLoggedIn,
            builder: (___, isLoggedIn, __) {
              if (!isLoggedIn) return const SizedBox();
              return IconButton(
                tooltip: logOut,
                onPressed: () {
                  context.logout().then(
                    (_) {
                      AppRouter.config.refresh();
                    },
                  );
                },
                icon: const Icon(Icons.logout),
              );
            },
          ),
          IconButton(
            tooltip: info,
            onPressed: () => _showInfoDialog(context),
            icon: const Icon(Icons.help_outline_outlined),
          ),
          IconButton(
            tooltip: tooltip,
            onPressed: () {
              Provider.of<AppTheme>(context, listen: false).flip(context);
            },
            icon: icon,
          ),
        ],
      ),
      body: shell,
    );
  }

  void _showInfoDialog(BuildContext context) {
    try {
      final (:appName, :version, :build) = PackageProvider.of(context).package;
      showAboutDialog(context: context, applicationName: appName, applicationVersion: '$version+$build');
    } catch (e) {
      //
    }
  }

  String _title(BuildContext context) {
    return switch (GoRouterState.of(context).matchedLocation.split('/')) {
      ['', 'login'] => 'Semaia',
      ['', String path] => '${path.substring(0, 1).toUpperCase()}${path.substring(1)}',
      _ => '',
    };
  }

  TextStyle? _style(BuildContext context) {
    return switch (GoRouterState.of(context).matchedLocation.split('/')) {
      ['', 'login'] => const TextStyle(fontFamily: 'Parisienne', fontSize: 40),
      _ => null,
    };
  }
}
