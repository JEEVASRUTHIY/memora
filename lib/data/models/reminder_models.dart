import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore: patients/{patientId}/reminders/{reminderId}
///
/// Template created by a caregiver. Actual occurrences in reminderOccurrences.
class ReminderModel {
  final String reminderId;
  final String patientId;
  final String title;
  final String? note;
  final String? imageUrl;

  /// 'once' | 'daily' | 'weekly'
  final String recurrence;

  /// For daily/weekly: list of "HH:mm" strings, e.g. ["08:00","20:00"]
  final List<String> times;

  /// 'low' | 'medium' | 'high'
  final String importance;

  /// Maximum auto-repeats before escalating to missed.
  final int maxRepeats;

  /// Minutes between repeats within a single occurrence.
  final int repeatEveryMinutes;

  final bool active;
  final String createdBy; // UID of caregiver
  final DateTime createdAt;

  const ReminderModel({
    required this.reminderId,
    required this.patientId,
    required this.title,
    this.note,
    this.imageUrl,
    required this.recurrence,
    required this.times,
    required this.importance,
    required this.maxRepeats,
    required this.repeatEveryMinutes,
    required this.active,
    required this.createdBy,
    required this.createdAt,
  });

  factory ReminderModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReminderModel(
      reminderId: documentId,
      patientId: map['patientId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      note: map['note'] as String?,
      imageUrl: map['imageUrl'] as String?,
      recurrence: map['recurrence'] as String? ?? 'daily',
      times: List<String>.from(map['times'] as List? ?? []),
      importance: map['importance'] as String? ?? 'medium',
      maxRepeats: map['maxRepeats'] as int? ?? 3,
      repeatEveryMinutes: map['repeatEveryMinutes'] as int? ?? 15,
      active: map['active'] as bool? ?? true,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'title': title,
      if (note != null) 'note': note,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'recurrence': recurrence,
      'times': times,
      'importance': importance,
      'maxRepeats': maxRepeats,
      'repeatEveryMinutes': repeatEveryMinutes,
      'active': active,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ReminderModel copyWith({
    String? title,
    String? note,
    String? imageUrl,
    String? recurrence,
    List<String>? times,
    String? importance,
    int? maxRepeats,
    int? repeatEveryMinutes,
    bool? active,
  }) {
    return ReminderModel(
      reminderId: reminderId,
      patientId: patientId,
      title: title ?? this.title,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
      recurrence: recurrence ?? this.recurrence,
      times: times ?? this.times,
      importance: importance ?? this.importance,
      maxRepeats: maxRepeats ?? this.maxRepeats,
      repeatEveryMinutes: repeatEveryMinutes ?? this.repeatEveryMinutes,
      active: active ?? this.active,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

/// Firestore: patients/{patientId}/reminderOccurrences/{occurrenceId}
///
/// occurrenceId is DETERMINISTIC: "{reminderId}_{yyyyMMddHHmm}"
class ReminderOccurrenceModel {
  final String occurrenceId; // e.g. "abc123_202410171430"
  final String reminderId;
  final DateTime scheduledTime;

  /// 'pending' | 'confirmed' | 'snoozed' | 'missed'
  final String status;

  final DateTime? snoozedUntil;
  final int repeatCount;
  final int snoozeCount;
  final DateTime? shownTime;

  const ReminderOccurrenceModel({
    required this.occurrenceId,
    required this.reminderId,
    required this.scheduledTime,
    required this.status,
    this.snoozedUntil,
    required this.repeatCount,
    required this.snoozeCount,
    this.shownTime,
  });

  bool get isPendingOrSnoozed =>
      status == 'pending' || status == 'snoozed';

  bool get isActionable {
    final now = DateTime.now();
    if (status == 'snoozed' && snoozedUntil != null) {
      return now.isAfter(snoozedUntil!);
    }
    return status == 'pending' && now.isAfter(scheduledTime);
  }

  factory ReminderOccurrenceModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return ReminderOccurrenceModel(
      occurrenceId: documentId,
      reminderId: map['reminderId'] as String? ?? '',
      scheduledTime:
          (map['scheduledTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] as String? ?? 'pending',
      snoozedUntil: (map['snoozedUntil'] as Timestamp?)?.toDate(),
      repeatCount: map['repeatCount'] as int? ?? 0,
      snoozeCount: map['snoozeCount'] as int? ?? 0,
      shownTime: (map['shownTime'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reminderId': reminderId,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'status': status,
      if (snoozedUntil != null)
        'snoozedUntil': Timestamp.fromDate(snoozedUntil!),
      'repeatCount': repeatCount,
      'snoozeCount': snoozeCount,
      if (shownTime != null) 'shownTime': Timestamp.fromDate(shownTime!),
    };
  }

  ReminderOccurrenceModel copyWith({
    String? status,
    DateTime? snoozedUntil,
    int? repeatCount,
    int? snoozeCount,
    DateTime? shownTime,
  }) {
    return ReminderOccurrenceModel(
      occurrenceId: occurrenceId,
      reminderId: reminderId,
      scheduledTime: scheduledTime,
      status: status ?? this.status,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      repeatCount: repeatCount ?? this.repeatCount,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      shownTime: shownTime ?? this.shownTime,
    );
  }
}

/// Firestore: patients/{patientId}/reminderEvents/{eventId}
///
/// Immutable audit record written on every patient action.
class ReminderEventModel {
  final String eventId;
  final String occurrenceId;
  final String reminderId;
  final DateTime scheduledTime;
  final DateTime shownTime;
  final DateTime? responseTime;
  final int? responseDelaySeconds;
  final int snoozeCount;
  final int repeatCount;

  /// 'confirmed' | 'snoozed' | 'missed'
  final String status;

  final int hourOfDay;
  final DateTime createdAt;

  const ReminderEventModel({
    required this.eventId,
    required this.occurrenceId,
    required this.reminderId,
    required this.scheduledTime,
    required this.shownTime,
    this.responseTime,
    this.responseDelaySeconds,
    required this.snoozeCount,
    required this.repeatCount,
    required this.status,
    required this.hourOfDay,
    required this.createdAt,
  });

  factory ReminderEventModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return ReminderEventModel(
      eventId: documentId,
      occurrenceId: map['occurrenceId'] as String? ?? '',
      reminderId: map['reminderId'] as String? ?? '',
      scheduledTime:
          (map['scheduledTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shownTime: (map['shownTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      responseTime: (map['responseTime'] as Timestamp?)?.toDate(),
      responseDelaySeconds: map['responseDelaySeconds'] as int?,
      snoozeCount: map['snoozeCount'] as int? ?? 0,
      repeatCount: map['repeatCount'] as int? ?? 0,
      status: map['status'] as String? ?? 'missed',
      hourOfDay: map['hourOfDay'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'occurrenceId': occurrenceId,
      'reminderId': reminderId,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'shownTime': Timestamp.fromDate(shownTime),
      if (responseTime != null)
        'responseTime': Timestamp.fromDate(responseTime!),
      if (responseDelaySeconds != null)
        'responseDelaySeconds': responseDelaySeconds,
      'snoozeCount': snoozeCount,
      'repeatCount': repeatCount,
      'status': status,
      'hourOfDay': hourOfDay,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
