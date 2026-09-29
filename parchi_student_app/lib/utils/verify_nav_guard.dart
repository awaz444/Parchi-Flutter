/// Prevents pushing a second approve screen for the same request.
///
/// A link can be delivered several times (getInitialLink + uriLinkStream + onGenerateRoute +
/// notification tap). We refuse when a screen for that id is already open, and also suppress
/// duplicate deliveries that arrive within a short window before the screen has mounted.
final Set<String> _openRequestIds = <String>{};
final Map<String, DateTime> _recentClaims = <String, DateTime>{};

const Duration _duplicateWindow = Duration(seconds: 3);

/// Injectable clock for tests.
DateTime Function() verifyNavNow = DateTime.now;

bool tryClaimVerifyNav(String requestId) {
  if (_openRequestIds.contains(requestId)) return false;

  final now = verifyNavNow();
  final last = _recentClaims[requestId];
  if (last != null && now.difference(last) < _duplicateWindow) return false;

  _recentClaims[requestId] = now;
  return true;
}

void markVerifyScreenOpen(String requestId) => _openRequestIds.add(requestId);

void markVerifyScreenClosed(String requestId) {
  _openRequestIds.remove(requestId);
  _recentClaims.remove(requestId);
}

/// For tests.
void resetVerifyNavGuard() {
  _openRequestIds.clear();
  _recentClaims.clear();
  verifyNavNow = DateTime.now;
}
