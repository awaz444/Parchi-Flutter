import 'package:flutter/material.dart';

/// Request to switch the root bottom-nav tab (and optionally Events sub-tab).
class MainTabIntent {
  final int tabIndex;
  /// EventsScreen: 0 = Events, 1 = My Tickets
  final int? eventsSubTab;

  const MainTabIntent(this.tabIndex, {this.eventsSubTab});
}

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final RouteObserver<PageRoute<dynamic>> routeObserver =
      RouteObserver<PageRoute<dynamic>>();

  /// MainScreen listens and switches tabs when this changes.
  static final ValueNotifier<MainTabIntent?> tabIntent =
      ValueNotifier<MainTabIntent?>(null);

  /// Open the Events bottom tab on the My Tickets sub-tab.
  static void openMyTickets() {
    tabIntent.value = null;
    tabIntent.value = const MainTabIntent(2, eventsSubTab: 1);
  }

  /// `parchi://tickets` or `parchi://my-tickets` (with optional path).
  static bool isMyTicketsUri(Uri uri) {
    if (uri.scheme != 'parchi') return false;
    final host = uri.host.toLowerCase();
    if (host == 'tickets' || host == 'my-tickets') return true;
    if (uri.pathSegments.isNotEmpty) {
      final first = uri.pathSegments.first.toLowerCase();
      if (first == 'tickets' || first == 'my-tickets') return true;
    }
    return false;
  }
}
