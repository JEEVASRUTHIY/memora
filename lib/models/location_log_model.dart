import 'package:cloud_firestore/cloud_firestore.dart';

class LocationLogModel {
  final String id;
  final String patientId;
  final double latitude;
  final double longitude;
  final String status; // 'Inside' or 'Outside'
  final bool breachFlag;
  final String lastKnownLocation;
  final DateTime? timestamp;

  LocationLogModel({
    required this.id,
    required this.patientId,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.breachFlag,
    required this.lastKnownLocation,
    this.timestamp,
  });

  factory LocationLogModel.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime? time;
    if (json['timestamp'] != null) {
      if (json['timestamp'] is Timestamp) {
        time = (json['timestamp'] as Timestamp).toDate();
      } else if (json['timestamp'] is String) {
        time = DateTime.tryParse(json['timestamp']);
      }
    }
    return LocationLogModel(
      id: id ?? json['id'] ?? '',
      patientId: json['patientId'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'Inside',
      breachFlag: json['breachFlag'] ?? false,
      lastKnownLocation: json['lastKnownLocation'] ?? '',
      timestamp: time,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'breachFlag': breachFlag,
      'lastKnownLocation': lastKnownLocation,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }
}
