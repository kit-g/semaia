import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:semaia/presentation/widgets/google_sign_in/button.dart';
import 'package:semaia_language/semaia_language.dart';
import 'package:semaia_state/semaia_state.dart';
import 'package:semaia/core/utils/misc.dart';
import 'package:semaia/core/utils/visual.dart';
import 'package:semaia/presentation/widgets/loader.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with ShowsSnackOnError<LoginPage>, LoadingState, AfterLayoutMixin {
  @override
  Widget build(BuildContext context) {
    final L(:logIn, :logInWithGoogle) = L.of(context);
    return Selector<Auth, bool>(
      selector: (_, provider) => provider.isInitialized,
      builder: (context, initialized, child) {
        if (!initialized) return const Loader();
        return child!;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(logIn)),
        body: ValueListenableBuilder<bool>(
          valueListenable: loader,
          child: const Center(child: CircularProgressIndicator()),
          builder: (context, loading, child) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width / 3),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    GoogleSignInButton(
                      onPressed: () {
                        Auth.of(context).loginWithGoogle();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    Auth.of(context).initGoogleSign();
  }
}
