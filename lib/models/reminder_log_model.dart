import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderLogModel {
  final String logId;
  final String reminderId;
  final String patientId;
  final String description;
  final String? instructions;
  final String reminderType;
  final DateTime scheduledTime;
  final String status; // 'Triggered', 'Completed', 'Missed', 'Snoozed'
  final DateTime actionTime;
  final bool escalationNotified;
  final DateTime? completedAt;
  final bool snoozeEnabled;
  final String? imageUrl;

  ReminderLogModel({
    required this.logId,
    required this.reminderId,
    required this.patientId,
    required this.description,
    this.instructions,
    required this.reminderType,
    required this.scheduledTime,
    required this.status,
    required this.actionTime,
    this.escalationNotified = false,
    this.completedAt,
    this.snoozeEnabled = true,
    this.imageUrl,
  });

  factory ReminderLogModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    final scheduledField = json['scheduledTime'];
    DateTime scheduledDateTime;
    if (scheduledField is Timestamp) {
      scheduledDateTime = scheduledField.toDate();
    } else if (scheduledField is String) {
      scheduledDateTime = DateTime.parse(scheduledField);
    } else {
      scheduledDateTime = DateTime.now();
    }

    final actionField = json['actionTime'];
    DateTime actionDateTime;
    if (actionField is Timestamp) {
      actionDateTime = actionField.toDate();
    } else if (actionField is String) {
      actionDateTime = DateTime.parse(actionField);
    } else {
      actionDateTime = DateTime.now();
    }

    final completedField = json['completedAt'];
    DateTime? completedDateTime;
    if (completedField is Timestamp) {
      completedDateTime = completedField.toDate();
    } else if (completedField is String) {
      completedDateTime = DateTime.parse(completedField);
    }

    return ReminderLogModel(
      logId: docId ?? json['logId'] ?? '',
      reminderId: json['reminderId'] ?? '',
      patientId: json['patientId'] ?? '',
      description: json['description'] ?? '',
      instructions: json['instructions'],
      reminderType: json['reminderType'] ?? '',
      scheduledTime: scheduledDateTime,
      status: json['status'] ?? 'Triggered',
      actionTime: actionDateTime,
      escalationNotified: json['escalationNotified'] ?? false,
      completedAt: completedDateTime,
      snoozeEnabled: json['snoozeEnabled'] ?? true,
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logId': logId,
      'reminderId': reminderId,
      'patientId': patientId,
      'description': description,
      'instructions': instructions,
      'reminderType': reminderType,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'status': status,
      'actionTime': Timestamp.fromDate(actionTime),
      'escalationNotified': escalationNotified,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'snoozeEnabled': snoozeEnabled,
      'imageUrl': imageUrl,
    };
  }

  ReminderLogModel copyWith({
    String? logId,
    String? reminderId,
    String? patientId,
    String? description,
    String? instructions,
    String? reminderType,
    DateTime? scheduledTime,
    String? status,
    DateTime? actionTime,
    bool? escalationNotified,
    DateTime? completedAt,
    bool? snoozeEnabled,
    String? imageUrl,
  }) {
    return ReminderLogModel(
      logId: logId ?? this.logId,
      reminderId: reminderId ?? this.reminderId,
      patientId: patientId ?? this.patientId,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      reminderType: reminderType ?? this.reminderType,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      actionTime: actionTime ?? this.actionTime,
      escalationNotified: escalationNotified ?? this.escalationNotified,
      completedAt: completedAt ?? this.completedAt,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
