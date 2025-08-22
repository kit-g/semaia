import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart';

class GoogleSignInButton extends StatelessWidget {
  final void Function()? onPressed;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return renderButton(
      configuration: GSIButtonConfiguration(
        type: GSIButtonType.standard,
        shape: GSIButtonShape.pill,
        theme: GSIButtonTheme.filledBlue,
        size: GSIButtonSize.large,
        text: GSIButtonText.continueWith,
      ),
    );
  }
}
