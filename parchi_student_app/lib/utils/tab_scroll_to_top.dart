import 'package:flutter/material.dart';

/// Bottom-nav "tap the active tab to scroll to top".
///
/// [MainScreen] calls [trigger] when the user taps the tab that is already
/// selected. Each tab's screen listens to [listenable] for its own index and
/// scrolls its list back to the top.
class TabScrollToTop {
  TabScrollToTop._();

  static const int home = 0;
  static const int leaderboard = 1;
  static const int events = 2;
  static const int history = 3;

  static final Map<int, ValueNotifier<int>> _ticks = {};

  static ValueNotifier<int> _notifier(int tab) =>
      _ticks.putIfAbsent(tab, () => ValueNotifier<int>(0));

  /// Listen for re-taps on [tab].
  static ValueNotifier<int> listenable(int tab) => _notifier(tab);

  /// Fire a "scroll to top" request for [tab].
  static void trigger(int tab) {
    final n = _notifier(tab);
    n.value = n.value + 1;
  }

  /// Smoothly scroll [controller] to its start (no-op if already there or not
  /// attached to a scroll view).
  static Future<void> scrollToTop(ScrollController controller) async {
    if (!controller.hasClients) return;
    if (controller.offset <= 0) return;
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }
}
