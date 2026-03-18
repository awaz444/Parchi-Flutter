import 'package:flutter/material.dart';

/// Wraps any widget tree so that tapping anywhere outside a focused
/// text field dismisses the soft keyboard.
///
/// Usage:
///   TapToDismissKeyboard(child: Scaffold(...))
class TapToDismissKeyboard extends StatelessWidget {
  final Widget child;

  const TapToDismissKeyboard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // HitTestBehavior.translucent lets taps pass through to children
      // (buttons, text fields, etc.) while still firing this callback.
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: child,
    );
  }
}
