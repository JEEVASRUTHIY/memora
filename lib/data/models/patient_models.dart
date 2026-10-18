import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore: patients/{patientId}/safeZones/{zoneId}
class SafeZoneModel {
  final String zoneId;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final bool active;
  final DateTime updatedAt;

  const SafeZoneModel({
    required this.zoneId,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.active,
    required this.updatedAt,
  });

  factory SafeZoneModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SafeZoneModel(
      zoneId: documentId,
      centerLat: (map['centerLat'] as num?)?.toDouble() ?? 0.0,
      centerLng: (map['centerLng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 200.0,
      active: map['active'] as bool? ?? true,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'centerLat': centerLat,
      'centerLng': centerLng,
      'radiusMeters': radiusMeters,
      'active': active,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Firestore: patients/{patientId}/alerts/{alertId}
class AlertModel {
  final String alertId;

  /// 'sos' | 'outsideSafeZone' | 'missedReminder'
  final String type;

  final String message;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  final bool acknowledged;
  final String? acknowledgedBy; // UID
  final DateTime? acknowledgedAt;

  // For missedReminder type:
  final String? reminderId;
  final String? occurrenceId;
  final int escalationLevel;   // 0 = initial, 1+ = escalated
  final DateTime? escalateAt;  // when to auto-escalate next

  const AlertModel({
    required this.alertId,
    required this.type,
    required this.message,
    this.lat,
    this.lng,
    required this.createdAt,
    required this.acknowledged,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.reminderId,
    this.occurrenceId,
    this.escalationLevel = 0,
    this.escalateAt,
  });

  factory AlertModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AlertModel(
      alertId: documentId,
      type: map['type'] as String? ?? '',
      message: map['message'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acknowledged: map['acknowledged'] as bool? ?? false,
      acknowledgedBy: map['acknowledgedBy'] as String?,
      acknowledgedAt: (map['acknowledgedAt'] as Timestamp?)?.toDate(),
      reminderId: map['reminderId'] as String?,
      occurrenceId: map['occurrenceId'] as String?,
      escalationLevel: map['escalationLevel'] as int? ?? 0,
      escalateAt: (map['escalateAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'message': message,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'createdAt': Timestamp.fromDate(createdAt),
      'acknowledged': acknowledged,
      if (acknowledgedBy != null) 'acknowledgedBy': acknowledgedBy,
      if (acknowledgedAt != null)
        'acknowledgedAt': Timestamp.fromDate(acknowledgedAt!),
      if (reminderId != null) 'reminderId': reminderId,
      if (occurrenceId != null) 'occurrenceId': occurrenceId,
      'escalationLevel': escalationLevel,
      if (escalateAt != null) 'escalateAt': Timestamp.fromDate(escalateAt!),
    };
  }
}

/// Firestore: patients/{patientId}/weeks/{weekId}
///
/// Written only by the server (Admin SDK). Clients can read if linked.
class WeekModel {
  final String weekId;
  final Map<String, dynamic> stats;
  final List<double> embedding;
  final double driftScore;
  final List<String> changedSignals;
  final String report;
  final DateTime createdAt;

  const WeekModel({
    required this.weekId,
    required this.stats,
    required this.embedding,
    required this.driftScore,
    required this.changedSignals,
    required this.report,
    required this.createdAt,
  });

  factory WeekModel.fromMap(Map<String, dynamic> map, String documentId) {
    return WeekModel(
      weekId: documentId,
      stats: Map<String, dynamic>.from(map['stats'] as Map? ?? {}),
      embedding: List<double>.from(
          (map['embedding'] as List? ?? []).map((e) => (e as num).toDouble())),
      driftScore: (map['driftScore'] as num?)?.toDouble() ?? 0.0,
      changedSignals: List<String>.from(map['changedSignals'] as List? ?? []),
      report: map['report'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stats': stats,
      'embedding': embedding,
      'driftScore': driftScore,
      'changedSignals': changedSignals,
      'report': report,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
