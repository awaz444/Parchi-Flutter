import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../services/events_service.dart';

final eventsProvider = FutureProvider<List<EventModel>>((ref) async {
  return eventsService.getActiveEvents();
});
