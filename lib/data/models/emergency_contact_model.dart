import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: patients/{patientId}/contacts/{contactId}
class EmergencyContactModel {
  final String id;
  final String patientId;
  final String name;
  final String phoneNumber;
  final String relationship;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const EmergencyContactModel({
    required this.id,
    required this.patientId,
    required this.name,
    required this.phoneNumber,
    required this.relationship,
    this.isPrimary = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory EmergencyContactModel.fromMap(Map<String, dynamic> map, String documentId) {
    return EmergencyContactModel(
      id: documentId,
      patientId: map['patientId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      relationship: map['relationship'] as String? ?? 'Contact',
      isPrimary: map['isPrimary'] as bool? ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : DateTime.now()),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : (map['updatedAt'] is DateTime
              ? map['updatedAt'] as DateTime
              : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'name': name.trim(),
      'phoneNumber': phoneNumber.trim(),
      'relationship': relationship.trim(),
      'isPrimary': isPrimary,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  EmergencyContactModel copyWith({
    String? id,
    String? patientId,
    String? name,
    String? phoneNumber,
    String? relationship,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContactModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          patientId == other.patientId &&
          name == other.name &&
          phoneNumber == other.phoneNumber &&
          relationship == other.relationship &&
          isPrimary == other.isPrimary;

  @override
  int get hashCode =>
      id.hashCode ^
      patientId.hashCode ^
      name.hashCode ^
      phoneNumber.hashCode ^
      relationship.hashCode ^
      isPrimary.hashCode;
}
