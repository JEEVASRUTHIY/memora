import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: links/{linkId}
///
/// Multi-caregiver schema:
///   role      : 'primary' | 'secondary'
///   status    : 'pending' | 'active' | 'rejected' | 'removed'
class LinkModel {
  final String linkId;
  final String caregiverUid;
  final String patientId;
  final String caregiverName;
  final String role;
  final String status; // 'pending' | 'active' | 'rejected' | 'removed'
  final String requestedBy;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const LinkModel({
    required this.linkId,
    required this.caregiverUid,
    required this.patientId,
    required this.caregiverName,
    required this.role,
    required this.status,
    required this.requestedBy,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isPrimary => role == 'primary';

  factory LinkModel.fromMap(Map<String, dynamic> map, String documentId) {
    return LinkModel(
      linkId: documentId,
      caregiverUid: map['caregiverUid'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      caregiverName: map['caregiverName'] as String? ?? '',
      role: map['role'] as String? ?? 'primary',
      status: map['status'] as String? ?? 'active',
      requestedBy: map['requestedBy'] as String? ?? 'caregiver',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caregiverUid': caregiverUid,
      'patientId': patientId,
      'caregiverName': caregiverName,
      'role': role,
      'status': status,
      'requestedBy': requestedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
    };
  }
}
