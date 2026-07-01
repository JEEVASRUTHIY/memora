import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class BackgroundLocationService {
  /// Configures and initializes the background service configuration
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'safezone_tracking_channel',
        initialNotificationTitle: 'Safe Zone Active',
        initialNotificationContent: 'Monitoring location in background...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Starts the background tracking service manually
  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  /// Stops the background tracking service
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
  }
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase inside the isolate
  await Firebase.initializeApp();

  // 1. Boot Safety Verification
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) {
    debugPrint('Background service: No authenticated user. Stopping.');
    service.stopSelf();
    return;
  }

  try {
    // 2. Verify patient user role
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      debugPrint('Background service: User profile does not exist. Stopping.');
      service.stopSelf();
      return;
    }

    final userData = userDoc.data()!;
    if (userData['role'] != 'Patient') {
      debugPrint('Background service: User role is not Patient. Stopping.');
      service.stopSelf();
      return;
    }

    // 3. Verify active safe zone is configured
    final safeZoneDoc = await FirebaseFirestore.instance.collection('safeZones').doc(user.uid).get();
    if (!safeZoneDoc.exists) {
      debugPrint('Background service: Safe zone not configured. Stopping.');
      service.stopSelf();
      return;
    }

    final safeZoneData = safeZoneDoc.data()!;
    if (safeZoneData['activeStatus'] != true) {
      debugPrint('Background service: Safe zone is disabled. Stopping.');
      service.stopSelf();
      return;
    }

    // 4. Verify location permissions are granted
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      debugPrint('Background service: Location permissions not granted. Stopping.');
      service.stopSelf();
      return;
    }
  } catch (e) {
    debugPrint('Background service verification exception: $e. Stopping.');
    service.stopSelf();
    return;
  }

  // Configure status listening to stop service from UI
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Battery Throttling variables
  double? lastLat;
  double? lastLng;
  DateTime? lastUpdateTime;

  // Start watching locations
  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  ).listen((Position position) async {
    final now = DateTime.now();
    bool shouldSend = false;

    if (lastLat == null || lastLng == null || lastUpdateTime == null) {
      shouldSend = true;
    } else {
      final distance = Geolocator.distanceBetween(
        lastLat!,
        lastLng!,
        position.latitude,
        position.longitude,
      );
      final elapsedMinutes = now.difference(lastUpdateTime!).inMinutes;

      // Displacement > 20 meters OR elapsed time > 5 minutes
      if (distance >= 20.0 || elapsedMinutes >= 5) {
        shouldSend = true;
      }
    }

    if (shouldSend) {
      try {
        final url = Uri.parse('https://us-central1-memora-app.cloudfunctions.net/users/location/update');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'patientId': user.uid,
            'latitude': position.latitude,
            'longitude': position.longitude,
          }),
        );

        if (response.statusCode == 200) {
          lastLat = position.latitude;
          lastLng = position.longitude;
          lastUpdateTime = now;

          // Notify the UI isolate if running
          service.invoke('locationUpdate', {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'status': jsonDecode(response.body)['status'] ?? 'Inside',
            'timestamp': now.toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('Background location update request failed: $e');
      }
    }
  });
}
