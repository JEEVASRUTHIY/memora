import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: users/{uid}
class UserModel {
  final String uid;
  final String role; // 'patient' | 'caregiver'
  final String name;
  final String email;

  /// Only set for patients — a short unique ID used for linking.
  final String? patientId;
  final bool onboardingDone;

  /// FCM tokens for push notifications (array).
  final List<String> fcmTokens;

  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    this.patientId,
    this.onboardingDone = false,
    this.fcmTokens = const [],
    required this.createdAt,
  });

  bool get isPatient => role == 'patient';
  bool get isCaregiver => role == 'caregiver';

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      role: (map['role'] as String? ?? '').toLowerCase(),
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      patientId: map['patientId'] as String?,
      onboardingDone: map['onboardingDone'] as bool? ?? false,
      fcmTokens: List<String>.from(map['fcmTokens'] as List? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'name': name,
      'email': email,
      if (patientId != null) 'patientId': patientId,
      'onboardingDone': onboardingDone,
      'fcmTokens': fcmTokens,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? uid,
    String? role,
    String? name,
    String? email,
    String? patientId,
    bool? onboardingDone,
    List<String>? fcmTokens,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      patientId: patientId ?? this.patientId,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
