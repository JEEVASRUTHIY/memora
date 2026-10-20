import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/data/services/app_preferences_service.dart';

/// Describes the patient's current location in an accessible, dementia-friendly manner.
class PatientLocationInfo {
  final bool isAtHome;
  final String locationTitle;
  final String speechExplanation;
  final String displayExplanation;
  final String? nearbyLandmark;

  const PatientLocationInfo({
    required this.isAtHome,
    required this.locationTitle,
    required this.speechExplanation,
    required this.displayExplanation,
    this.nearbyLandmark,
  });
}

class LocationService {
  final Ref _ref;

  LocationService(this._ref);

  /// Resolves the patient's current friendly location.
  PatientLocationInfo getCurrentLocation() {
    final prefs = _ref.read(appPreferencesProvider);

    if (!prefs.isSimulatedAway) {
      return PatientLocationInfo(
        isAtHome: true,
        locationTitle: 'Safe at Home',
        speechExplanation:
            'You are safely at home in your living room at ${prefs.homeAddress}.',
        displayExplanation:
            'You are safe at home (${prefs.homeAddress}). Everything is okay.',
        nearbyLandmark: 'Living Room',
      );
    } else {
      final place = prefs.awayLocationDescription;
      return PatientLocationInfo(
        isAtHome: false,
        locationTitle: 'Away from Home',
        speechExplanation:
            'You are currently on $place. You are not at home. Would you like to call your emergency contact?',
        displayExplanation:
            'You are currently on $place, away from home.',
        nearbyLandmark: place,
      );
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(ref);
});
