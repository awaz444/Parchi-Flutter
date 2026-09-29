import 'dart:convert';
import '../config/api_config.dart';
import '../models/event_model.dart';
import 'auth_service.dart';

class EventsService {
  Future<List<EventModel>> getActiveEvents() async {
    final response = await authService.publicGet(ApiConfig.activeEventsEndpoint);
    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = responseData['data'];
      if (raw is List) {
        return raw
            .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    final message = responseData['message'];
    final errorMessage = message is List
        ? message.join(', ')
        : (message is String ? message : 'Failed to fetch events');
    throw Exception(errorMessage);
  }
}

final eventsService = EventsService();
