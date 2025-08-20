enum Env {
  local,
  dev,
  prod;

  factory Env.fromString(String? v) {
    return switch (v) {
      'local' || 'l' => local,
      'dev' || 'd' || 'development' => dev,
      'prod' || 'p' || 'production' => prod,
      _ => throw UnimplementedError('Valid environments are: ${Env.values}'),
    };
  }
}

class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment('apiGateway');
  static Env env = Env.fromString(const String.fromEnvironment('env'));
  static const String domain = String.fromEnvironment('domain');
  static const String appName = String.fromEnvironment('appName', defaultValue: 'Semaia');

  static String url([String path = '', Map<String, dynamic>? query]) {
    return switch (env) {
      Env.local => Uri.http(domain, path, query).toString(),
      _ => Uri.https(domain, path, query).toString(),
    };
  }
}
