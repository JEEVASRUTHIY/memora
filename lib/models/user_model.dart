class UserModel {
  final String userId;
  final String role; // 'Patient' or 'Caregiver'
  final String name;
  final String contactDetails;
  final String? linkedPatientId;
  final String? linkedCaregiverId;

  UserModel({
    required this.userId,
    required this.role,
    required this.name,
    required this.contactDetails,
    this.linkedPatientId,
    this.linkedCaregiverId,
  });

  // Check role helper
  bool get isPatient => role == 'Patient';
  bool get isCaregiver => role == 'Caregiver';
  bool get isLinked => isPatient 
      ? linkedCaregiverId != null 
      : linkedPatientId != null;

  String? get linkedUserId => isPatient ? linkedCaregiverId : linkedPatientId;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      role: json['role'] ?? '',
      name: json['name'] ?? '',
      contactDetails: json['contactDetails'] ?? '',
      linkedPatientId: json['linkedPatientId'],
      linkedCaregiverId: json['linkedCaregiverId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role,
      'name': name,
      'contactDetails': contactDetails,
      'linkedPatientId': linkedPatientId,
      'linkedCaregiverId': linkedCaregiverId,
    };
  }

  UserModel copyWith({
    String? userId,
    String? role,
    String? name,
    String? contactDetails,
    String? linkedPatientId,
    String? linkedCaregiverId,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      name: name ?? this.name,
      contactDetails: contactDetails ?? this.contactDetails,
      linkedPatientId: linkedPatientId ?? this.linkedPatientId,
      linkedCaregiverId: linkedCaregiverId ?? this.linkedCaregiverId,
    );
  }
}
