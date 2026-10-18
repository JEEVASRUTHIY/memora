import 'package:cloud_firestore/cloud_firestore.dart';

class PatientProfile {
  final String patientId;
  final String ownerUid;
  final String name;
  final int age;
  final String details;
  final String timezone;
  final DateTime createdAt;

  const PatientProfile({
    required this.patientId,
    required this.ownerUid,
    required this.name,
    required this.age,
    required this.details,
    required this.timezone,
    required this.createdAt,
  });

  factory PatientProfile.fromMap(Map<String, dynamic> map, String patientId) {
    return PatientProfile(
      patientId: patientId,
      ownerUid: map['ownerUid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      details: map['details'] as String? ?? '',
      timezone: map['timezone'] as String? ?? 'UTC+00:00',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
