import 'package:flutter/material.dart';
import 'package:semaia_state/semaia_state.dart';

extension LogoutCleanup on BuildContext {
  Future<void> logout() async {
    await Auth.of(this).logout();
    DatabaseInspector.of(this).onSignOut();
    Preferences.of(this).onSignOut();
    Chats.of(this).onSignOut();
  }
}
