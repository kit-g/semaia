import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:semaia_state/semaia_state.dart';
import 'package:semaia/core/config/config.dart';
import 'package:semaia/presentation/routes/login.dart';
import 'package:semaia/presentation/routes/query.dart';
import 'package:semaia/presentation/widgets/app_frame.dart';
export 'package:go_router/go_router.dart' show GoRouterState;

const _queryName = 'query';
const _queryPath = '/$_queryName';
const _loginName = 'login';
const _loginPath = '/$_loginName';

RouteBase _queryRoute() {
  return GoRoute(
    path: _queryPath,
    builder: (__, _) => const QueryPage(),
    name: _queryName,
  );
}

RouteBase _loginRoute() {
  return GoRoute(
    path: _loginPath,
    builder: (__, _) => const LoginPage(),
    name: _loginName,
  );
}

class AppRouter {
  static AppRouter of(BuildContext context) {
    return Provider.of<AppRouter>(context, listen: false);
  }

  static final config = GoRouter(
    debugLogDiagnostics: false,
    initialLocation: _queryPath,
    routes: [
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) {
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: AppFrame(shell: shell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [_queryRoute()],
          ),

          StatefulShellBranch(
            routes: [_loginRoute()],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final Auth(:isLoggedIn) = Auth.of(context);
      final Uri(:path, :queryParameters) = state.uri;

      if (!isLoggedIn) {
        return switch (queryParameters) {
          {'redirect': String _} => '$_loginPath${queryParameters.queryString}',
          _ => switch (path) {
            _loginPath => null,
            String other => switch (queryParameters.isEmpty) {
              true => '$_loginPath?redirect=${Uri.encodeComponent(other)}',
              false => '$_loginPath${queryParameters.queryString}&redirect=${Uri.encodeComponent(other)}',
            },
          },
        };
      }

      if (queryParameters['redirect'] case String redirect) {
        var removed = Map.fromEntries(queryParameters.entries.where((e) => e.key != 'redirect'));
        return '$redirect${removed.queryString}';
      }

      return null;
    },
  );
}

extension on Map<String, String> {
  static String pair(MapEntry entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}';

  String get queryString {
    if (isEmpty) return '';
    return '?${entries.map(pair).join('&')}';
  }
}

extension ContextNavigation on BuildContext {
  Map<String, String> get pathParameters {
    return GoRouterState.of(this).pathParameters;
  }

  Map<String, String> get queryParameters {
    return GoRouterState.of(this).uri.queryParameters;
  }

  String shareQuery(String toShare) {
    return AppConfig.url(
      _queryPath,
      {'q': Uri.encodeComponent(toShare)},
    );
  }
}
