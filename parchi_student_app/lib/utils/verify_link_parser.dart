/// Pure-Dart parsing of partner verification links (no Flutter imports, easy to unit test).
///
/// Accepted forms, and nothing else:
///   parchi://verify/{uuid}
///   https://parchipakistan.com/verify/{uuid}
///   https://www.parchipakistan.com/verify/{uuid}
///   https://link.parchi.pk/a/v/{uuid}   (partner checkout QR short link)
/// Anything on another scheme/host, with extra path segments, or with a non-UUID id is rejected.
library;

final RegExp _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

const Set<String> _allowedWebHosts = {'parchipakistan.com', 'www.parchipakistan.com'};
const Set<String> _shortLinkHosts = {'link.parchi.pk', 'www.link.parchi.pk'};

bool isUuid(String value) => _uuidRe.hasMatch(value);

List<String> _segments(Uri uri) =>
    uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);

bool _hasQrQuery(Uri uri) {
  final via = uri.queryParameters['via']?.toLowerCase();
  final method = uri.queryParameters['method']?.toLowerCase();
  return via == 'qr' || method == 'qr';
}

bool _isShortVerifyPath(List<String> segments) =>
    segments.length == 3 && segments[0] == 'a' && segments[1] == 'v' && isUuid(segments[2]);

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

  // Partner QR codes use the short link host (then redirect to the www verify URL).
  if (uri.scheme == 'https' && _shortLinkHosts.contains(uri.host)) {
    if (_isShortVerifyPath(segments)) return segments[2].toLowerCase();
  }

  return null;
}

/// True when this link should skip number-matching (QR / presence already proven).
///
/// - Partner QR short links (`link.parchi.pk/a/v/...`)
/// - Explicit `?via=qr` / `?method=qr`
/// - https App Links on `/verify/{uuid}` (system camera / Safari after QR redirect)
///
/// Push notifications use `parchi://verify/{uuid}` without a QR query and still require matching.
bool isVerifyViaQr(Uri uri) {
  if (_hasQrQuery(uri)) return true;

  final segments = _segments(uri);
  if (uri.scheme == 'https' && _shortLinkHosts.contains(uri.host) && _isShortVerifyPath(segments)) {
    return true;
  }

  if (uri.scheme == 'https' &&
      _allowedWebHosts.contains(uri.host) &&
      segments.length == 2 &&
      segments[0] == 'verify' &&
      isUuid(segments[1])) {
    return true;
  }

  return false;
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

/// Cold-start App Links often arrive as `/verify/{uuid}` with the host stripped.
/// Treat those as QR (https) unless we know better from the full URI.
bool isVerifyViaQrFromRoute(String? routeName) {
  if (routeName == null || routeName.isEmpty) return false;
  final uri = Uri.tryParse(routeName);
  if (uri == null) return false;
  if (_hasQrQuery(uri)) return true;
  return extractVerifyRequestIdFromRoute(routeName) != null;
}
