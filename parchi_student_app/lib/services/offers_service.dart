import 'dart:convert';
import '../config/api_config.dart';
import '../models/offer_model.dart';
import 'auth_service.dart';

class OffersService {

  // Get Active Offers
  Future<List<OfferModel>> getActiveOffers() async {
    try {
      final response = await authService.publicGet(ApiConfig.activeOffersEndpoint);

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // NestJS response structure: { data: { data: [...], pagination: {...} }, ... }
        if (responseData['data'] != null && responseData['data']['items'] != null) {
          final List<dynamic> offersJson = responseData['data']['items'];
          return offersJson.map((json) => OfferModel.fromJson(json)).toList();
        }
        return [];
      } else {
        throw _handleError(response.statusCode, responseData);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to fetch offers: ${e.toString()}');
    }
  }

  // Get Featured Offers
  Future<List<OfferModel>> getFeaturedOffers() async {
    try {
      final response = await authService.publicGet(ApiConfig.featuredOffersEndpoint);

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseData['data'] != null) {
          final List<dynamic> offersJson = responseData['data'];
          return offersJson.map((json) => OfferModel.fromJson(json)).toList();
        }
        return [];
      } else {
        throw _handleError(response.statusCode, responseData);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to fetch featured offers: ${e.toString()}');
    }
  }

  // Get Offer Details
  Future<OfferModel> getOfferDetails(String id) async {
    try {
      final response = await authService.publicGet(ApiConfig.offerDetailsEndpoint(id));

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return OfferModel.fromJson(responseData['data']);
      } else {
        throw _handleError(response.statusCode, responseData);
      }
    } catch (e) {
      rethrow;
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
        // This should theoretically be handled by authenticatedGet retry logic, 
        // but if it still bubbles up (retry failed), we throw specific auth error.
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
final offersService = OffersService();