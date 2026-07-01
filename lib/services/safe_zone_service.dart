import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/safe_zone_model.dart';
import '../models/location_log_model.dart';

class SafeZoneService {
  final http.Client _client;
  final String _baseUrl;

  SafeZoneService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://us-central1-memora-app.cloudfunctions.net/users';

  /// Configures a patient's safe zone.
  Future<SafeZoneModel> configureSafeZone({
    required String caregiverId,
    required String patientId,
    required double homeLatitude,
    required double homeLongitude,
    required double radius,
    required bool activeStatus,
  }) async {
    final url = Uri.parse('$_baseUrl/safezone/configure');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'caregiverId': caregiverId,
        'patientId': patientId,
        'homeLatitude': homeLatitude,
        'homeLongitude': homeLongitude,
        'radius': radius,
        'activeStatus': activeStatus,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to configure safe zone');
    }

    final data = jsonDecode(response.body);
    if (data['safeZone'] != null) {
      return SafeZoneModel.fromJson(data['safeZone']);
    }
    return SafeZoneModel(
      patientId: patientId,
      homeLatitude: homeLatitude,
      homeLongitude: homeLongitude,
      radius: radius,
      activeStatus: activeStatus,
    );
  }

  /// Fetches safe zone configuration.
  Future<SafeZoneModel?> getSafeZone(String patientId) async {
    final url = Uri.parse('$_baseUrl/safezone/$patientId');
    final response = await _client.get(url);

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to fetch safe zone');
    }

    final data = jsonDecode(response.body);
    return SafeZoneModel.fromJson(data);
  }

  /// Updates patient location.
  Future<Map<String, dynamic>> updateLocation({
    required String patientId,
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse('$_baseUrl/location/update');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patientId': patientId,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to update location');
    }

    return jsonDecode(response.body);
  }

  /// Fetches paginated location logs from functions.
  Future<List<LocationLogModel>> fetchLocationLogs(
    String patientId, {
    int limit = 100,
    int? startAfterMillis,
  }) async {
    var uriString = '$_baseUrl/locationLogs/$patientId?limit=$limit';
    if (startAfterMillis != null) {
      uriString += '&startAfter=$startAfterMillis';
    }

    final url = Uri.parse(uriString);
    final response = await _client.get(url);

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to fetch location logs');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => LocationLogModel.fromJson(json)).toList();
  }

  /// Checks the current geofence status.
  Future<Map<String, dynamic>> checkSafeZone({
    required String patientId,
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse('$_baseUrl/safezone/check');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patientId': patientId,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to check safe zone status');
    }

    return jsonDecode(response.body);
  }

  /// Forces a manual breach event.
  Future<void> forceBreach({
    required String patientId,
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse('$_baseUrl/safezone/breach');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patientId': patientId,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to trigger manual breach');
    }
  }
}
