import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Base URL for the backend API
  static String get baseUrl {
    final url = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080';
    return url;
  }

  // Auth endpoints
  static String get signupEndpoint => '$baseUrl/auth/signup';
  static String get studentSignupEndpoint => '$baseUrl/auth/student/signup';
  static String get studentSignupWithFilesEndpoint =>
      '$baseUrl/auth/student/signup-with-files';
  static String get loginEndpoint => '$baseUrl/auth/login';
  static String get logoutEndpoint => '$baseUrl/auth/logout';
  static String get refreshEndpoint => '$baseUrl/auth/refresh';
  static String get profileEndpoint => '$baseUrl/auth/me';
  static String get changePasswordEndpoint => '$baseUrl/auth/change-password';
  static String get forgotPasswordEndpoint => '$baseUrl/auth/forgot-password';
  static String get updateProfilePictureEndpoint =>
      '$baseUrl/auth/student/profile-picture';
  static String get updateFcmTokenEndpoint => '$baseUrl/auth/update-fcm';
  static String get appConfigEndpoint => '$baseUrl/admin/config/app';
  // Offers Endpoints
  static String get activeOffersEndpoint => '$baseUrl/offers/active';
  static String get featuredOffersEndpoint => '$baseUrl/offers/featured';
  static String offerDetailsEndpoint(String id) =>
      '$baseUrl/offers/$id/details';
  static String merchantOffersEndpoint(String merchantId) =>
      '$baseUrl/offers/merchant/$merchantId';
  static String get allBrandsEndpoint => '$baseUrl/merchants/brands';
  static String merchantDetailsEndpoint(String merchantId) =>
      '$baseUrl/merchants/$merchantId/details';
  static String get studentMerchantListEndpoint =>
      '$baseUrl/merchants/student/list';

  // Redemption Endpoints
  static String get redemptionHistoryEndpoint => '$baseUrl/redemptions';
  static String get redemptionStatsEndpoint => '$baseUrl/redemptions/stats';
  static String redemptionDetailsEndpoint(String id) =>
      '$baseUrl/redemptions/$id';

  // Leaderboard Endpoints
  static String get leaderboardEndpoint => '$baseUrl/students/leaderboard';

  // Notification Endpoints
  static String get studentNotificationsEndpoint => '$baseUrl/student/notifications';
  static String markNotificationReadEndpoint(String id) =>
      '$baseUrl/notifications/$id/read';
      
  // Institutes Endpoint
  static String get institutesEndpoint => '$baseUrl/institutes';
}
