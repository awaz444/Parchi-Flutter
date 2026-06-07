import 'dart:convert';
import '../config/api_config.dart';
import '../models/leaderboard_model.dart';
import 'auth_service.dart';

class LeaderboardService {

  // Get Leaderboard
  Future<LeaderboardResponse> getLeaderboard({
    int page = 1,
    int limit = 10,
    String period = 'alltime',
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'period': period,
      };

      final uri = Uri.parse(ApiConfig.leaderboardEndpoint)
          .replace(queryParameters: queryParams);

      final response = await authService.publicGet(uri.toString());

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return LeaderboardResponse.fromJson(responseData);
      } else {
        throw _handleError(response.statusCode, responseData);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to fetch leaderboard: ${e.toString()}');
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

final leaderboardService = LeaderboardService();

