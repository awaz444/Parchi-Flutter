/// Pure-Dart parsing of partner verification links (no Flutter imports, easy to unit test).
///
/// Accepted forms, and nothing else:
///   parchi://verify/{uuid}
///   https://parchipakistan.com/verify/{uuid}
///   https://www.parchipakistan.com/verify/{uuid}
/// Anything on another scheme/host, with extra path segments, or with a non-UUID id is rejected.
library;

final RegExp _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

const Set<String> _allowedWebHosts = {'parchipakistan.com', 'www.parchipakistan.com'};

bool isUuid(String value) => _uuidRe.hasMatch(value);

List<String> _segments(Uri uri) =>
    uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);

/// Returns the (lower-cased) request id for a valid verification link, otherwise null.
String? extractVerifyRequestId(Uri uri) {
  final segments = _segments(uri);

  if (uri.scheme == 'parchi' && uri.host == 'verify') {
    if (segments.length == 1 && isUuid(segments[0])) return segments[0].toLowerCase();
    return null;
  }

  if (uri.scheme == 'https' && _allowedWebHosts.contains(uri.host)) {
    if (segments.length == 2 && segments[0] == 'verify' && isUuid(segments[1])) {
      return segments[1].toLowerCase();
    }
  }
  return null;
}

/// Flutter may hand us only the path of an OS-routed link (scheme and host stripped),
/// e.g. `/verify/{uuid}` for an https App Link. Accept exactly that shape.
String? extractVerifyRequestIdFromRoute(String? routeName) {
  if (routeName == null || routeName.isEmpty) return null;
  final uri = Uri.tryParse(routeName);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;
  final segments = _segments(uri);
  if (segments.length == 2 && segments[0] == 'verify' && isUuid(segments[1])) {
    return segments[1].toLowerCase();
  }
  return null;
}
