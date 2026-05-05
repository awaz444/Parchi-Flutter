import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHandlerService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static final NotificationHandlerService _instance = NotificationHandlerService._internal();

  factory NotificationHandlerService() {
    return _instance;
  }

  NotificationHandlerService._internal();

  // 1. Initialize Everything
  Future<void> initialize() async {
    // Request Permission (Critical for iOS)
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      print("FCM permission request failed: $e");
    }

    // Subscribe to the Broadcast Topic
    // Wrapped in try-catch; iOS Simulator has no APNS token so we guard against it
    await _subscribeToTopics();

    // Setup Local Notifications (for foreground display)
    // Make sure 'ic_launcher' exists in android/app/src/main/res/drawable or mipmap
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // For iOS (Darwin)
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(initSettings);

    // 2. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // When app is OPEN, FCM doesn't show a popup automatically.
      // We manually trigger a Local Notification.
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Handle Background Message Open
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked!');
    });
  }

  // 2. Subscribe to FCM topics — guarded for iOS Simulator (no APNS token)
  Future<void> _subscribeToTopics() async {
    try {
      // On iOS/macOS, wait for the APNS token before subscribing to topics.
      // The Simulator never gets an APNS token — we skip gracefully.
      if (Platform.isIOS || Platform.isMacOS) {
        String? apnsToken;
        for (int i = 0; i < 5; i++) {
          apnsToken = await _fcm.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        if (apnsToken == null) {
          print("FCM: No APNS token (Simulator or missing push entitlement). Skipping topic subscription.");
          return;
        }
      }
      await _fcm.subscribeToTopic('students_all');
      print("FCM: Subscribed to students_all topic.");
    } catch (e) {
      print("FCM: Topic subscription failed (expected on Simulator): $e");
    }
  }

  /// Subscribes to targeted topics based on student profile.
  /// Call this whenever user data is refreshed.
  Future<void> subscribeToTargetedTopics({
    required String? university,
    required bool isFoundersClub,
  }) async {
    try {
      // Basic broadcast
      await _fcm.subscribeToTopic('students_all');

      // University-specific
      if (university != null && university.isNotEmpty) {
        final sanitizedUni = university.toLowerCase().replaceAll(' ', '_');
        await _fcm.subscribeToTopic('university_$sanitizedUni');
        print("FCM: Subscribed to university_$sanitizedUni");
      }

      // Membership-specific
      if (isFoundersClub) {
        await _fcm.subscribeToTopic('founders_club');
        print("FCM: Subscribed to founders_club");
      }
    } catch (e) {
      print("FCM: Targeted topic subscription failed: $e");
    }
  }

  // 3. Trigger the Local Notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'broadcast_channel', // id
      'Student Broadcasts', // name
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformDetails,
      // Pass the DB ID so we can mark it read later if needed
      payload: message.data['notification_id'],
    );
  }

  // 4. Get FCM Token (for user-specific notifications)
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}
