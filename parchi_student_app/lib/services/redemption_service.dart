import 'dart:convert';
import '../config/api_config.dart';
import '../models/redemption_model.dart';
import 'auth_service.dart';

class RedemptionService {

  // Get Redemption History
  Future<List<RedemptionModel>> getRedemptions(
      {int page = 1, int limit = 10, String? status}) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
      };

      final uri = Uri.parse(ApiConfig.redemptionHistoryEndpoint)
          .replace(queryParameters: queryParams);

      final response = await authService.authenticatedGet(uri.toString());

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseData['data'] != null &&
            responseData['data']['items'] != null) {
          final List<dynamic> listJson = responseData['data']['items'];
          return listJson
              .map((json) => RedemptionModel.fromJson(json))
              .toList();
        }
        return [];
      } else {
        throw _handleError(response.statusCode, responseData);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to fetch redemptions: ${e.toString()}');
    }
  }

  // Get Redemption Stats
  Future<RedemptionStats> getStats() async {
    try {
      final response = await authService.authenticatedGet(ApiConfig.redemptionStatsEndpoint);

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return RedemptionStats.fromJson(responseData['data'] ?? {});
      } else {
        throw _handleError(response.statusCode, responseData);
      }
    } catch (e) {
      // Return zero stats on error rather than breaking UI
      return RedemptionStats(
          totalRedemptions: 0, bonusesUnlocked: 0, leaderboardPosition: 0);
    }
  }

  // Get Redemption Details
  Future<RedemptionModel> getRedemptionDetails(String id) async {
    try {
      final response = await authService.authenticatedGet(ApiConfig.redemptionDetailsEndpoint(id));

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return RedemptionModel.fromJson(responseData['data']);
      } else {
        throw _handleError(response.statusCode, responseData);
      }
    } catch (e) {
      rethrow;
    }
  }

  Exception _handleError(int statusCode, Map<String, dynamic> errorData) {
    final message = errorData['message'];
    String errorMessage;

    if (message is List) {
      errorMessage = message.join(', ');
    } else if (message is String) {
      errorMessage = message;
    } else {
      errorMessage = 'An error occurred';
    }

    switch (statusCode) {
      case 400:
        return Exception("Bad Request: $errorMessage");
      case 401:
        return Exception("Unauthorized: Please login again.");
      case 403:
        return Exception("Forbidden: You do not have access to this resource.");
      case 404:
        return Exception("Not Found: $errorMessage");
      case 500:
        return Exception("Server Error: $errorMessage");
      default:
        return Exception(errorMessage);
    }
  }
}

final redemptionService = RedemptionService();
