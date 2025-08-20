import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:semaia_models/semaia_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _query = 'query';
const _sessionToken = 'sessionCookie';

class Preferences with ChangeNotifier implements SignOutStateSentry {
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  @override
  void onSignOut() {
    _prefs?.clear();
  }

  static Preferences of(BuildContext context) {
    return Provider.of<Preferences>(context, listen: false);
  }

  static Preferences watch(BuildContext context) {
    return Provider.of<Preferences>(context, listen: true);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool>? saveQuery(String query) {
    return _prefs?.setString(_query, query);
  }

  String? getQuery() {
    return _prefs?.getString(_query);
  }

  String? getSessionToken() {
    return _prefs?.getString(_sessionToken);
  }

  Future<bool>? saveSessionToken(String cookie) {
    return _prefs?.setString(_sessionToken, cookie);
  }

  Future<bool>? deleteSessionToken() {
    return _prefs?.remove(_sessionToken);
  }
}
