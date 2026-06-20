import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';
import '../models/reminder_log_model.dart';

class ReminderRepository {
  final FirebaseFirestore _firestore;

  ReminderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _remindersCollection =>
      _firestore.collection('reminders');

  CollectionReference<Map<String, dynamic>> get _reminderLogsCollection =>
      _firestore.collection('reminderLogs');

  /// Creates a new reminder. Returns the created reminder with auto-generated ID if empty.
  Future<ReminderModel> createReminder(ReminderModel reminder) async {
    try {
      final docRef = reminder.reminderId.isEmpty
          ? _remindersCollection.doc()
          : _remindersCollection.doc(reminder.reminderId);

      final newReminder = reminder.copyWith(reminderId: docRef.id);
      await docRef.set(newReminder.toJson());
      return newReminder;
    } catch (e) {
      rethrow;
    }
  }

  /// Updates an existing reminder.
  Future<void> updateReminder(ReminderModel reminder) async {
    try {
      await _remindersCollection.doc(reminder.reminderId).set(
            reminder.toJson(),
            SetOptions(merge: true),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches a single reminder by ID.
  Future<ReminderModel?> getReminder(String reminderId) async {
    try {
      final doc = await _remindersCollection.doc(reminderId).get();
      if (doc.exists && doc.data() != null) {
        return ReminderModel.fromJson(doc.data()!, docId: doc.id);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a reminder by ID.
  Future<void> deleteReminder(String reminderId) async {
    try {
      await _remindersCollection.doc(reminderId).delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Streams all reminders for a specific patient.
  Stream<List<ReminderModel>> watchReminders(String patientId) {
    return _remindersCollection
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReminderModel.fromJson(doc.data(), docId: doc.id))
          .toList();
    });
  }

  /// Streams active reminders for a specific patient.
  Stream<List<ReminderModel>> watchActiveReminders(String patientId) {
    return _remindersCollection
        .where('patientId', isEqualTo: patientId)
        .where('activeStatus', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReminderModel.fromJson(doc.data(), docId: doc.id))
          .toList();
    });
  }

  /// Creates a new reminder log.
  Future<ReminderLogModel> createReminderLog(ReminderLogModel log) async {
    try {
      final docRef = log.logId.isEmpty
          ? _reminderLogsCollection.doc()
          : _reminderLogsCollection.doc(log.logId);

      final newLog = log.copyWith(logId: docRef.id);
      await docRef.set(newLog.toJson());
      return newLog;
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the status of a reminder log (e.g. Confirmed, Missed).
  Future<void> updateReminderLogStatus(
    String logId,
    String status, {
    bool? escalationNotified,
    DateTime? completedAt,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'actionTime': Timestamp.fromDate(DateTime.now()),
      };
      if (escalationNotified != null) {
        updates['escalationNotified'] = escalationNotified;
      }
      if (completedAt != null) {
        updates['completedAt'] = Timestamp.fromDate(completedAt);
      } else if (status.toLowerCase() == 'completed') {
        updates['completedAt'] = Timestamp.fromDate(DateTime.now());
      }
      await _reminderLogsCollection.doc(logId).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches a single reminder log by ID.
  Future<ReminderLogModel?> getReminderLog(String logId) async {
    try {
      final doc = await _reminderLogsCollection.doc(logId).get();
      if (doc.exists && doc.data() != null) {
        return ReminderLogModel.fromJson(doc.data()!, docId: doc.id);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Streams all logs for a patient.
  Stream<List<ReminderLogModel>> watchReminderLogs(String patientId) {
    return _reminderLogsCollection
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ReminderLogModel.fromJson(doc.data(), docId: doc.id))
          .toList();
      // Sort in-memory because composite index might not be built immediately
      list.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      return list;
    });
  }
}
