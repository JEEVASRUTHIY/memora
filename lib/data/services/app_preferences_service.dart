import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App preferences managing:
/// 1. Read Aloud Mode: Auto-play upon opening screens vs only when speaker button is pressed.
/// 2. Safe Places & Location orientation for dementia memory care.
class AppPreferencesState {
  final bool readAloudEverytime;
  final String homeAddress;
  final String homeFriendlyName;
  final bool isSimulatedAway;
  final String awayLocationDescription;

  const AppPreferencesState({
    this.readAloudEverytime = true,
    this.homeAddress = '123 Maple Avenue, Apt 4B',
    this.homeFriendlyName = 'Home',
    this.isSimulatedAway = false,
    this.awayLocationDescription = 'Oak Street near the corner bakery',
  });

  AppPreferencesState copyWith({
    bool? readAloudEverytime,
    String? homeAddress,
    String? homeFriendlyName,
    bool? isSimulatedAway,
    String? awayLocationDescription,
  }) {
    return AppPreferencesState(
      readAloudEverytime: readAloudEverytime ?? this.readAloudEverytime,
      homeAddress: homeAddress ?? this.homeAddress,
      homeFriendlyName: homeFriendlyName ?? this.homeFriendlyName,
      isSimulatedAway: isSimulatedAway ?? this.isSimulatedAway,
      awayLocationDescription:
          awayLocationDescription ?? this.awayLocationDescription,
    );
  }
}

class AppPreferencesNotifier extends StateNotifier<AppPreferencesState> {
  AppPreferencesNotifier() : super(const AppPreferencesState());

  void setReadAloudEverytime(bool enabled) {
    state = state.copyWith(readAloudEverytime: enabled);
  }

  void setHomeAddress(String address, {String? friendlyName}) {
    state = state.copyWith(
      homeAddress: address.trim(),
      homeFriendlyName: friendlyName?.trim() ?? state.homeFriendlyName,
    );
  }

  void setLocationSimulation({
    required bool isAway,
    String? awayDescription,
  }) {
    state = state.copyWith(
      isSimulatedAway: isAway,
      awayLocationDescription: awayDescription?.trim() ?? state.awayLocationDescription,
    );
  }

  void setSimulatedAway(bool isAway) {
    state = state.copyWith(isSimulatedAway: isAway);
  }
}

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesNotifier, AppPreferencesState>((ref) {
  return AppPreferencesNotifier();
});
