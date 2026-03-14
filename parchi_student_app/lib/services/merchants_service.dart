import 'dart:convert';
import '../config/api_config.dart';
import '../models/merchant_detail_model.dart';
import '../models/student_merchant_model.dart';
import 'auth_service.dart';

class MerchantsService {

  Future<MerchantDetailModel> getMerchantDetails(String merchantId) async {
    try {
      final response = await authService.publicGet(ApiConfig.merchantDetailsEndpoint(merchantId));

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseData['data'] != null) {
          return MerchantDetailModel.fromJson(responseData['data']);
        }
        throw Exception('Invalid response format: missing data field');
      } else {
        throw _handleError(response.statusCode, responseData);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to fetch merchant details: ${e.toString()}');
    }
  }

  Future<MerchantListResponse> getStudentMerchants({
    int page = 1,
    int limit = 10,
    String? month,
  }) async {

    final queryParameters = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (month != null) 'month': month,
    };

    final uri = Uri.parse(ApiConfig.studentMerchantListEndpoint)
        .replace(queryParameters: queryParameters);

    try {
      final response = await authService.publicGet(uri.toString());

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Updated to use the Response wrapper helper
        if (responseData['data'] != null) {
             return MerchantListResponse.fromJson(responseData);
        }
        // Fallback or empty if structure is totally wrong, but should match
         throw Exception('Invalid response format: missing data field');
      } else {
        throw _handleError(response.statusCode, responseData);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to fetch student merchants: ${e.toString()}');
    }
  }

  // Consistent Error Handling Helper
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

// Singleton instance
final merchantsService = MerchantsService();

