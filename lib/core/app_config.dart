import 'package:flutter/services.dart';

/// App-wide runtime configuration.
///
/// Maps behaviour: if [useMapsApiKey] is true and a key exists in
/// android/local.properties, google_maps_flutter is used; otherwise the app
/// falls back to flutter_map + OpenStreetMap (no key required).
///
/// Developer tools: set [devToolsEnabled] to false to hide the dev-tools
/// screen even in release builds.
class AppConfig {
  AppConfig._();

  /// Use Google Maps (key required). When false, uses OpenStreetMap fallback.
  static const bool preferGoogleMaps = true;
  static bool _hasMapsKey = false;
  static bool get useMapsApiKey => preferGoogleMaps && _hasMapsKey;

  /// Only a boolean crosses the platform channel; the key stays in Android.
  static Future<void> loadPlatformConfig() async {
    try {
      _hasMapsKey = await const MethodChannel('memora/config')
          .invokeMethod<bool>('hasMapsKey') ?? false;
    } on PlatformException {
      _hasMapsKey = false;
    } on MissingPluginException {
      _hasMapsKey = false;
    }
  }

  /// Show developer tools screen (reachable by tapping version 5 times).
  static const bool devToolsEnabled = true;

  /// Firebase project ID (for reference only — actual config is in
  /// google-services.json / firebase_options.dart).
  static const String firebaseProjectId = 'memora-3b359';
}
