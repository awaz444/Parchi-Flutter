import 'dart:convert';
import '../config/api_config.dart';
import '../models/home_ad_model.dart';
import 'auth_service.dart';

class HomeAdsService {
  Future<HomeAdsConfig> getActiveAds() async {
    final response = await authService.publicGet(ApiConfig.activeAdsEndpoint);
    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = responseData['data'];
      if (raw is Map<String, dynamic>) return HomeAdsConfig.fromJson(raw);
      return const HomeAdsConfig(ads: [], interval: Duration(seconds: 4));
    }

    final message = responseData['message'];
    final errorMessage = message is List
        ? message.join(', ')
        : (message is String ? message : 'Failed to fetch ads');
    throw Exception(errorMessage);
  }
}

final homeAdsService = HomeAdsService();
