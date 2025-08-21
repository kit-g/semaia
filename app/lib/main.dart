import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:semaia/core/config/config.dart';
import 'package:semaia/presentation/navigation/app.dart';

import 'core/url/io.dart';
import 'firebase_options.dart' as fb;

Future<void> main() async {
  Logger.root.level = getLogLevel();
  Logger.root.onRecord.listen(_log);
  setUrlStrategy();
  await initFirebase();

  runApp(const Semaia());
}

Level getLogLevel() {
  return switch (const String.fromEnvironment('logLevel')) {
    'ALL' => Level.ALL,
    _ => Level.OFF,
  };
}

// ignore: avoid_print
void _log(LogRecord r) => print('${r.level.name}: ${r.time}: ${r.message}');

Future<FirebaseApp> initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();

  switch (AppConfig.env) {
    case Env.dev || Env.prod || Env.local:
      // using the same FB project for now
      return Firebase.initializeApp(
        name: kIsWeb ? null : AppConfig.appName,
        options: fb.DefaultFirebaseOptions.currentPlatform,
      );
  }
}
