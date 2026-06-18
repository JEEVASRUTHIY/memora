import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging;

  NotificationService({FirebaseMessaging? firebaseMessaging})
      : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance;

  /// Initializes notification permissions and sets up listeners.
  Future<void> initialize() async {
    try {
      // 1. Request notification permissions (required for iOS and Android 13+)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('User granted notification permissions.');
        }
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        if (kDebugMode) {
          print('User granted provisional notification permissions.');
        }
      } else {
        if (kDebugMode) {
          print('User declined or has not accepted notification permissions.');
        }
      }

      // 2. Setup foreground message handler (triggered when app is active)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Handling a foreground message: ${message.messageId}');
          print('Message data: ${message.data}');
          if (message.notification != null) {
            print('Message notification title: ${message.notification!.title}');
            print('Message notification body: ${message.notification!.body}');
          }
        }
      });

      // 3. Setup message handler when app is opened from a notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('App opened from notification: ${message.messageId}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing NotificationService: $e');
      }
    }
  }

  /// Fetches the FCM registration token for the device.
  Future<String?> getToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  /// Listens to token refreshes.
  Stream<String> get onTokenRefresh => _firebaseMessaging.onTokenRefresh;
}
