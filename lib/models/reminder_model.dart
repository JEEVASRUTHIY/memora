import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String reminderId;
  final String patientId;
  final String description;
  final String? instructions;
  final String reminderType;
  final DateTime scheduledTime;
  final String severityLevel;
  final int escalationWaitingDuration; // In minutes
  final bool activeStatus;
  final bool snoozeEnabled;

  ReminderModel({
    required this.reminderId,
    required this.patientId,
    required this.description,
    this.instructions,
    required this.reminderType,
    required this.scheduledTime,
    required this.severityLevel,
    required this.escalationWaitingDuration,
    required this.activeStatus,
    this.snoozeEnabled = true,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    final scheduledField = json['scheduledTime'];
    DateTime scheduledDateTime;
    if (scheduledField is Timestamp) {
      scheduledDateTime = scheduledField.toDate();
    } else if (scheduledField is String) {
      scheduledDateTime = DateTime.parse(scheduledField);
    } else {
      scheduledDateTime = DateTime.now();
    }

    return ReminderModel(
      reminderId: docId ?? json['reminderId'] ?? '',
      patientId: json['patientId'] ?? '',
      description: json['description'] ?? '',
      instructions: json['instructions'],
      reminderType: json['reminderType'] ?? '',
      scheduledTime: scheduledDateTime,
      severityLevel: json['severityLevel'] ?? 'Low',
      escalationWaitingDuration: json['escalationWaitingDuration'] is int 
          ? json['escalationWaitingDuration'] 
          : int.tryParse(json['escalationWaitingDuration']?.toString() ?? '') ?? 15,
      activeStatus: json['activeStatus'] ?? true,
      snoozeEnabled: json['snoozeEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reminderId': reminderId,
      'patientId': patientId,
      'description': description,
      'instructions': instructions,
      'reminderType': reminderType,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'severityLevel': severityLevel,
      'escalationWaitingDuration': escalationWaitingDuration,
      'activeStatus': activeStatus,
      'snoozeEnabled': snoozeEnabled,
    };
  }

  ReminderModel copyWith({
    String? reminderId,
    String? patientId,
    String? description,
    String? instructions,
    String? reminderType,
    DateTime? scheduledTime,
    String? severityLevel,
    int? escalationWaitingDuration,
    bool? activeStatus,
    bool? snoozeEnabled,
  }) {
    return ReminderModel(
      reminderId: reminderId ?? this.reminderId,
      patientId: patientId ?? this.patientId,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      reminderType: reminderType ?? this.reminderType,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      severityLevel: severityLevel ?? this.severityLevel,
      escalationWaitingDuration: escalationWaitingDuration ?? this.escalationWaitingDuration,
      activeStatus: activeStatus ?? this.activeStatus,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
    );
  }
}
