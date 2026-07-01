import 'package:cloud_firestore/cloud_firestore.dart';

class SafeZoneModel {
  final String patientId;
  final double homeLatitude;
  final double homeLongitude;
  final double radius;
  final bool activeStatus;
  final DateTime? updatedAt;

  SafeZoneModel({
    required this.patientId,
    required this.homeLatitude,
    required this.homeLongitude,
    required this.radius,
    required this.activeStatus,
    this.updatedAt,
  });

  factory SafeZoneModel.fromJson(Map<String, dynamic> json) {
    DateTime? updated;
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is Timestamp) {
        updated = (json['updatedAt'] as Timestamp).toDate();
      } else if (json['updatedAt'] is String) {
        updated = DateTime.tryParse(json['updatedAt']);
      }
    }
    return SafeZoneModel(
      patientId: json['patientId'] ?? '',
      homeLatitude: (json['homeLatitude'] as num?)?.toDouble() ?? 0.0,
      homeLongitude: (json['homeLongitude'] as num?)?.toDouble() ?? 0.0,
      radius: (json['radius'] as num?)?.toDouble() ?? 200.0,
      activeStatus: json['activeStatus'] ?? false,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'homeLatitude': homeLatitude,
      'homeLongitude': homeLongitude,
      'radius': radius,
      'activeStatus': activeStatus,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  SafeZoneModel copyWith({
    String? patientId,
    double? homeLatitude,
    double? homeLongitude,
    double? radius,
    bool? activeStatus,
    DateTime? updatedAt,
  }) {
    return SafeZoneModel(
      patientId: patientId ?? this.patientId,
      homeLatitude: homeLatitude ?? this.homeLatitude,
      homeLongitude: homeLongitude ?? this.homeLongitude,
      radius: radius ?? this.radius,
      activeStatus: activeStatus ?? this.activeStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
