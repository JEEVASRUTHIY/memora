import 'dart:async';
import 'package:flutter/material.dart';
import '../models/safe_zone_model.dart';
import '../models/location_log_model.dart';
import '../services/safe_zone_service.dart';
import '../repositories/safe_zone_repository.dart';

class SafeZoneProvider extends ChangeNotifier {
  final SafeZoneRepository _repository;
  final SafeZoneService _service;

  SafeZoneModel? _safeZone;
  LocationLogModel? _latestLocation;
  List<LocationLogModel> _logs = [];
  bool _isLoadingZone = false;
  bool _isLoadingLogs = false;
  bool _isSavingZone = false;
  bool _hasMoreLogs = true;
  String? _errorMessage;
  
  // Developer GPS Simulator Overrides
  bool _isSimulatorEnabled = false;
  double _simulatedLatitude = 37.7749;
  double _simulatedLongitude = -122.4194;

  StreamSubscription? _safeZoneSubscription;
  StreamSubscription? _locationSubscription;

  SafeZoneProvider({
    required SafeZoneRepository safeZoneRepository,
    required SafeZoneService safeZoneService,
  })  : _repository = safeZoneRepository,
        _service = safeZoneService;

  SafeZoneRepository get repository => _repository;

  // Getters for Flutter Screens & Unit Tests compatibility
  SafeZoneModel? get safeZone => _safeZone;
  SafeZoneModel? get currentSafeZone => _safeZone;
  LocationLogModel? get latestLocation => _latestLocation;
  List<LocationLogModel> get logs => _logs;
  
  bool get isLoadingZone => _isLoadingZone;
  bool get isLoading => _isLoadingZone;
  bool get isLoadingLogs => _isLoadingLogs;
  bool get isSavingZone => _isSavingZone;
  bool get hasMoreLogs => _hasMoreLogs;
  String? get errorMessage => _errorMessage;

  bool get isSimulatorEnabled => _isSimulatorEnabled;
  bool get isSimulatorMode => _isSimulatorEnabled;
  double get simulatedLatitude => _simulatedLatitude;
  double get mockLatitude => _simulatedLatitude;
  double get simulatedLongitude => _simulatedLongitude;
  double get mockLongitude => _simulatedLongitude;

  /// Initializes live Firebase streams. Called by main or screens.
  void initialize(String patientId, {required bool isPatient}) {
    _safeZoneSubscription?.cancel();
    _safeZoneSubscription = _repository.watchSafeZone(patientId).listen((zone) {
      _safeZone = zone;
      notifyListeners();
    });

    _locationSubscription?.cancel();
    _locationSubscription = _repository.watchLatestLocation(patientId).listen((loc) {
      _latestLocation = loc;
      notifyListeners();
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Toggles developer GPS Simulator mode.
  void toggleGpsSimulator(bool enabled) {
    _isSimulatorEnabled = enabled;
    notifyListeners();
  }

  /// Toggles simulator mode (Unit test compatibility).
  void toggleSimulatorMode(bool enable, {double? defaultLat, double? defaultLng}) {
    _isSimulatorEnabled = enable;
    if (defaultLat != null) _simulatedLatitude = defaultLat;
    if (defaultLng != null) _simulatedLongitude = defaultLng;
    notifyListeners();
  }

  /// Updates simulated coordinates.
  void setSimulatedCoordinates(double lat, double lng) {
    _simulatedLatitude = lat;
    _simulatedLongitude = lng;
    notifyListeners();
  }

  /// Fetches safe zone configuration.
  Future<void> fetchSafeZone(String patientId) async {
    _isLoadingZone = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _safeZone = await _service.getSafeZone(patientId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingZone = false;
      notifyListeners();
    }
  }

  /// Configures a patient's safe zone (caregivers only).
  Future<bool> configureSafeZone({
    required String caregiverId,
    required String patientId,
    required double latitude,
    required double longitude,
    required double radius,
    required bool activeStatus,
  }) async {
    _isSavingZone = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedZone = await _service.configureSafeZone(
        caregiverId: caregiverId,
        patientId: patientId,
        homeLatitude: latitude,
        homeLongitude: longitude,
        radius: radius,
        activeStatus: activeStatus,
      );
      
      _safeZone = updatedZone;
      _isSavingZone = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isSavingZone = false;
      notifyListeners();
      return false;
    }
  }

  /// Uploads live coordinates to the backend (used by developer simulator or background service).
  Future<Map<String, dynamic>?> sendLocationUpdate({
    required String patientId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _service.updateLocation(
        patientId: patientId,
        latitude: latitude,
        longitude: longitude,
      );
      
      // Reload logs to show new entry immediately in UI
      await loadLogs(patientId);
      return response;
    } catch (e) {
      debugPrint('Failed location upload via provider: $e');
      return null;
    }
  }

  /// Fetches initial location logs (up to 100).
  Future<void> loadLogs(String patientId) async {
    _isLoadingLogs = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedLogs = await _service.fetchLocationLogs(patientId, limit: 100);
      _logs = fetchedLogs;
      _hasMoreLogs = fetchedLogs.length == 100;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingLogs = false;
      notifyListeners();
    }
  }

  /// Loads the next page of logs (pagination).
  Future<void> loadMoreLogs(String patientId) async {
    if (_logs.isEmpty || !_hasMoreLogs || _isLoadingLogs) return;

    _isLoadingLogs = true;
    notifyListeners();

    try {
      final lastLog = _logs.last;
      if (lastLog.timestamp != null) {
        final startAfterMillis = lastLog.timestamp!.millisecondsSinceEpoch;
        final nextLogs = await _service.fetchLocationLogs(
          patientId,
          limit: 100,
          startAfterMillis: startAfterMillis,
        );

        if (nextLogs.isEmpty) {
          _hasMoreLogs = false;
        } else {
          _logs.addAll(nextLogs);
          _hasMoreLogs = nextLogs.length == 100;
        }
      } else {
        _hasMoreLogs = false;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingLogs = false;
      notifyListeners();
    }
  }

  /// Force triggers a simulated breach event.
  Future<bool> simulateBreach(String patientId, double latitude, double longitude) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.forceBreach(
        patientId: patientId,
        latitude: latitude,
        longitude: longitude,
      );
      await loadLogs(patientId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _safeZoneSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}
