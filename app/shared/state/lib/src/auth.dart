import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:semaia_models/semaia_models.dart';

final _logger = Logger('Auth');

class Auth with ChangeNotifier {
  final _google = GoogleSignIn.instance;
  final _firebase = fb.FirebaseAuth.instance;
  final Future<void> Function(User?, String?) onLogin;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final bool isWeb;

  User? _user;

  User? get user => _user;

  bool get isLoggedIn => _user != null;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  set isInitialized(bool value) {
    _isInitialized = value;
    notifyListeners();
  }

  Future<void> initGoogleSign() async {
    await _google.initialize();
    isInitialized = true;
  }

  Auth({
    required this.onLogin,
    this.onError,
    required this.isWeb,
  }) {
    if (isWeb) {
      _google.authenticationEvents.listen(
        (event) async {
          _logger.info('Google sign in event: $event');

          switch (event) {
            case GoogleSignInAuthenticationEventSignOut():
              _firebase.signOut();
            case GoogleSignInAuthenticationEventSignIn(:var user):
              final cred = fb.GoogleAuthProvider.credential(idToken: user.authentication.idToken);
              final authResult = await _firebase.signInWithCredential(cred);

              _user = _cast(authResult.user);
              onLogin.call(_user, await authResult.user?.getIdToken());
              notifyListeners();
          }
        },
      );
    }

    _firebase.userChanges().listen(
      (user) async {
        _logger.info('Firebase user change: ${user == null ? 'null' : user.email}');
        _user = _cast(user);
        onLogin.call(_user, await user?.getIdToken());
        isInitialized = true;
      },
      onError: (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      },
    );
  }

  static Auth of(BuildContext context) {
    return Provider.of<Auth>(context, listen: false);
  }

  static Auth watch(BuildContext context) {
    return Provider.of<Auth>(context, listen: true);
  }

  Future<void> logout() async {
    _user = null;
    await _firebase.signOut();
    await _google.signOut();
  }

  Future<void> _loginWithCredential(fb.OAuthCredential credential) {
    return _firebase
        .signInWithCredential(credential)
        .then<void>((result) => _user = _cast(result.user))
        .catchError((e, s) => onError?.call(e, stacktrace: s));
  }

  Future<void> _loginWithGoogle(GoogleSignInAccount user) async {
    user.authentication;
    if (user.authentication case GoogleSignInAuthentication(:String? idToken)) {
      final cred = fb.GoogleAuthProvider.credential(idToken: idToken);
      return _loginWithCredential(cred);
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      await initGoogleSign();
      if (_google.supportsAuthenticate()) {
        final account = await _google.authenticate(scopeHint: ['profile', 'email']);
        return _loginWithGoogle(account);
      }
    } on GoogleSignInException catch (e, s) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _logger.shout('Google sign in error: $e');
        onError?.call(e, stacktrace: s);
      }
    } catch (e, s) {
      _logger.shout('Google sign in error: $e');
      onError?.call(e, stacktrace: s);

      try {
        await initGoogleSign();
        await _google.signOut();
      } catch (e, s) {
        onError?.call(e, stacktrace: s);
      }
    }
  }
}

User? _cast(fb.User? user) {
  if (user == null) return null;
  return User(
    email: user.email,
    id: user.uid,
    displayName: user.displayName,
    avatar: user.photoURL,
    createdAt: user.metadata.creationTime,
  );
}
