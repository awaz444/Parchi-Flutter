import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

  String get _platform {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return 'Unknown';
  }

  Future<void> logEvent(String eventName, {Map<String, dynamic>? metadata}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/log'),
        headers: {
          'Content-Type': 'application/json',
          if (user != null) 'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'eventName': eventName,
          'platform': _platform,
          'metadata': metadata ?? {},
        }),
      );

      if (response.statusCode != 201) {
        debugPrint('Failed to log event $eventName: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error logging event $eventName: $e');
    }
  }
}

final analyticsService = AnalyticsService();
