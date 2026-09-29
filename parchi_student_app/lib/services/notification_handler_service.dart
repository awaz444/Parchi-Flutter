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

  void Function(Uri uri)? _onOpenLink;
  Uri? _pendingOpenLink;

  set onOpenLink(void Function(Uri uri)? handler) {
    _onOpenLink = handler;
    if (handler != null && _pendingOpenLink != null) {
      final pending = _pendingOpenLink!;
      _pendingOpenLink = null;
      handler(pending);
    }
  }

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

    // Create the Android channel up front. Server-sent pushes reference 'broadcast_channel';
    // if it does not exist yet, Android 8+ falls back to a low-importance default channel and
    // time-critical prompts (like partner verification) would not pop up.
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'broadcast_channel',
            'Student Broadcasts',
            importance: Importance.max,
          ),
        );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _dispatchLink(response.payload);
      },
    );

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
      _handleRemoteMessage(message);
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(initialMessage);
    }
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final link = message.data['link_url'];
    _dispatchLink(link);
  }

  void _dispatchLink(String? link) {
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    final handler = _onOpenLink;
    if (handler != null) {
      handler(uri);
    } else {
      _pendingOpenLink = uri;
    }
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
      payload: message.data['link_url'] ?? message.data['notification_id'],
    );
  }

  // 4. Get FCM Token (for user-specific notifications)
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}
