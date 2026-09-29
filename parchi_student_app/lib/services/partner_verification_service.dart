import 'dart:convert';
import '../config/api_config.dart';
import '../models/partner_verification_model.dart';
import 'auth_service.dart';

/// Error from the verification API. [statusCode] lets the UI react precisely
/// (404 = not your request, 410 = expired, 409 = already decided, 429 = slow down).
class PartnerVerificationException implements Exception {
  final int statusCode;
  final String message;
  const PartnerVerificationException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class PartnerVerificationService {
  // 403 here is a business error (e.g. "account not verified"), never a session failure, so we
  // must not let the auth layer log the user out because of it.
  Future<PartnerVerificationModel> getRequest(String requestId) async {
    final response = await authService.authenticatedGet(
      ApiConfig.verificationRequestEndpoint(requestId),
      forbiddenIsSessionError: false,
    );
    return _parse(response, 'Failed to load verification request');
  }

  /// [viaQr] = the student scanned the code from the partner's screen in-app. Otherwise the
  /// student must supply the number-matching [matchCode].
  Future<PartnerVerificationModel> approve(
    String requestId, {
    required bool viaQr,
    String? matchCode,
  }) async {
    final response = await authService.authenticatedPost(
      ApiConfig.approveVerificationEndpoint(requestId),
      body: {
        'method': viaQr ? 'qr' : 'push',
        if (!viaQr && matchCode != null) 'matchCode': matchCode,
      },
      forbiddenIsSessionError: false,
    );
    return _parse(response, 'Failed to approve verification');
  }

  Future<PartnerVerificationModel> reject(String requestId) async {
    final response = await authService.authenticatedPost(
      ApiConfig.rejectVerificationEndpoint(requestId),
      body: const {},
      forbiddenIsSessionError: false,
    );
    return _parse(response, 'Failed to reject verification');
  }

  PartnerVerificationModel _parse(dynamic response, String fallback) {
    Map<String, dynamic> responseData;
    try {
      responseData = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw PartnerVerificationException(response.statusCode, fallback);
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        responseData['data'] != null) {
      return PartnerVerificationModel.fromJson(
        responseData['data'] as Map<String, dynamic>,
      );
    }
    final message = responseData['message'];
    final errorMessage = message is List
        ? message.join(', ')
        : (message is String ? message : fallback);
    throw PartnerVerificationException(response.statusCode, errorMessage);
  }
}

final partnerVerificationService = PartnerVerificationService();
