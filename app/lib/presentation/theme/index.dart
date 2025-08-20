import 'package:flutter/material.dart';

class AppTheme with ChangeNotifier {
  ThemeMode _mode;

  AppTheme({required ThemeMode mode}) : _mode = mode;

  ThemeMode get mode => _mode;

  set mode(ThemeMode v) {
    _mode = v;
    notifyListeners();
  }

  void toLight() => mode = ThemeMode.light;

  void toDark() => mode = ThemeMode.dark;

  void flip(BuildContext context) {
    switch (Theme.of(context).brightness) {
      case Brightness.dark:
        toLight();
      case Brightness.light:
        toDark();
    }
  }
}
