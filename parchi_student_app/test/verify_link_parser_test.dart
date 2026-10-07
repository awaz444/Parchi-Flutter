import 'package:flutter_test/flutter_test.dart';
import 'package:parchi_student_app/utils/verify_link_parser.dart';
import 'package:parchi_student_app/utils/verify_nav_guard.dart';

const id = 'c0a8012e-7b3a-4c11-9f0d-1b2c3d4e5f60';

void main() {
  group('extractVerifyRequestId', () {
    test('accepts the custom scheme link', () {
      expect(extractVerifyRequestId(Uri.parse('parchi://verify/$id')), id);
    });

    test('accepts https links on the Parchi hosts, ignoring query and trailing slash', () {
      expect(extractVerifyRequestId(Uri.parse('https://www.parchipakistan.com/verify/$id')), id);
      expect(extractVerifyRequestId(Uri.parse('https://parchipakistan.com/verify/$id/')), id);
      expect(extractVerifyRequestId(Uri.parse('https://www.parchipakistan.com/verify/$id?x=1')), id);
    });

    test('accepts the partner QR short link', () {
      expect(extractVerifyRequestId(Uri.parse('https://link.parchi.pk/a/v/$id')), id);
      expect(extractVerifyRequestId(Uri.parse('https://www.link.parchi.pk/a/v/$id')), id);
    });

    test('normalises the id to lower case', () {
      expect(
        extractVerifyRequestId(Uri.parse('parchi://verify/${id.toUpperCase()}')),
        id,
      );
    });

    test('rejects other hosts and schemes', () {
      expect(extractVerifyRequestId(Uri.parse('https://evil.example/verify/$id')), isNull);
      expect(extractVerifyRequestId(Uri.parse('https://parchipakistan.com.evil.example/verify/$id')), isNull);
      expect(extractVerifyRequestId(Uri.parse('http://www.parchipakistan.com/verify/$id')), isNull);
      expect(extractVerifyRequestId(Uri.parse('http://verify/$id')), isNull);
      expect(extractVerifyRequestId(Uri.parse('https://verify/$id')), isNull);
      expect(extractVerifyRequestId(Uri.parse('javascript:alert(1)')), isNull);
    });

    test('rejects malformed ids and unexpected path shapes', () {
      expect(extractVerifyRequestId(Uri.parse('parchi://verify/not-a-uuid')), isNull);
      expect(extractVerifyRequestId(Uri.parse('parchi://verify/')), isNull);
      expect(extractVerifyRequestId(Uri.parse('parchi://verify/$id/extra')), isNull);
      // Dart normalises "/../" while parsing, so this is exactly parchi://verify/<id>.
      expect(extractVerifyRequestId(Uri.parse('parchi://verify/../$id')), id);
      // Encoded dot-segments are normalised the same way, so they cannot smuggle a different path.
      expect(extractVerifyRequestId(Uri.parse('parchi://verify/%2e%2e/$id')), id);
      expect(extractVerifyRequestId(Uri.parse('parchi://verify/x/../$id/extra')), isNull);
      expect(extractVerifyRequestId(Uri.parse('https://www.parchipakistan.com/x/verify/$id')), isNull);
      expect(extractVerifyRequestId(Uri.parse('https://www.parchipakistan.com/verify/$id/more')), isNull);
      expect(extractVerifyRequestId(Uri.parse('parchi://redeem/$id')), isNull);
      expect(extractVerifyRequestId(Uri.parse('parchi://merchant/$id')), isNull);
    });

    test('does not treat auth email verify links as partner verification', () {
      expect(
        extractVerifyRequestId(
          Uri.parse('https://www.parchipakistan.com/verify?token=abc&type=signup'),
        ),
        isNull,
      );
    });
  });

  group('extractVerifyRequestIdFromRoute', () {
    test('accepts only a bare /verify/<uuid> route name', () {
      expect(extractVerifyRequestIdFromRoute('/verify/$id'), id);
      expect(extractVerifyRequestIdFromRoute('/verify/$id?ref=1'), id);
      expect(extractVerifyRequestIdFromRoute('/$id'), isNull); // ambiguous with redeem: never guess
      expect(extractVerifyRequestIdFromRoute('/redeem/$id'), isNull);
      expect(extractVerifyRequestIdFromRoute('/verify/nope'), isNull);
      expect(extractVerifyRequestIdFromRoute('https://evil.example/verify/$id'), isNull);
      expect(extractVerifyRequestIdFromRoute(null), isNull);
      expect(extractVerifyRequestIdFromRoute(''), isNull);
    });
  });

  group('isVerifyViaQr', () {
    test('treats short links and https verify URLs as QR', () {
      expect(isVerifyViaQr(Uri.parse('https://link.parchi.pk/a/v/$id')), isTrue);
      expect(isVerifyViaQr(Uri.parse('https://www.parchipakistan.com/verify/$id')), isTrue);
      expect(isVerifyViaQr(Uri.parse('https://www.parchipakistan.com/verify/$id?via=qr')), isTrue);
    });

    test('keeps plain push custom-scheme links on the match path', () {
      expect(isVerifyViaQr(Uri.parse('parchi://verify/$id')), isFalse);
      expect(isVerifyViaQr(Uri.parse('parchi://verify/$id?via=qr')), isTrue);
    });

    test('route-only App Links count as QR', () {
      expect(isVerifyViaQrFromRoute('/verify/$id'), isTrue);
      expect(isVerifyViaQrFromRoute('/verify/$id?via=qr'), isTrue);
      expect(isVerifyViaQrFromRoute('/redeem/$id'), isFalse);
    });
  });

  group('verify nav guard', () {
    setUp(resetVerifyNavGuard);

    test('suppresses duplicate deliveries inside the window, allows after it', () {
      var now = DateTime(2026, 1, 1, 12);
      verifyNavNow = () => now;

      expect(tryClaimVerifyNav(id), isTrue);
      expect(tryClaimVerifyNav(id), isFalse);

      now = now.add(const Duration(seconds: 4));
      expect(tryClaimVerifyNav(id), isTrue);
    });

    test('never opens a second screen while one is open for the same request', () {
      var now = DateTime(2026, 1, 1, 12);
      verifyNavNow = () => now;

      expect(tryClaimVerifyNav(id), isTrue);
      markVerifyScreenOpen(id);

      now = now.add(const Duration(minutes: 5));
      expect(tryClaimVerifyNav(id), isFalse);

      markVerifyScreenClosed(id);
      expect(tryClaimVerifyNav(id), isTrue);
    });

    test('different requests do not block each other', () {
      expect(tryClaimVerifyNav(id), isTrue);
      expect(tryClaimVerifyNav('11111111-1111-4111-8111-111111111111'), isTrue);
    });
  });
}
