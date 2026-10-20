import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: patients/{patientId}/refills/{refillId}
///
/// Refill and prescription schedule configured by caregivers and viewed by patients.
/// Includes prescription documents, tablet consumption rates, remaining supply,
/// next date to buy, one-tap caregiver requests, and daily alerts.
class MedicineRefillModel {
  final String id;
  final String patientId;
  final String medicineName;
  final String dosage;
  final DateTime refillDueDate;

  /// 'monthly' | 'weekly' | 'none'
  final String recurrence;

  /// Default lead time in days before due date (default: 5)
  final int reminderLeadDays;

  /// 'active' | 'caregiver_requested' | 'ordered' | 'refilled' | 'paused'
  final String status;

  // Prescription docs details
  final String? prescriptionDetails;
  final String? prescriptionDocumentUrl;
  final String? prescriptionDocumentName;
  final String? prescriptionDoctorName;
  final String? prescriptionClinic;
  final DateTime? prescriptionDate;

  // Tablet taking & supply tracking
  final int tabletsPerDose;
  final int dosesPerDay;
  final int totalTabletsInPack;
  final int remainingTablets;

  // Pharmacy & billing details
  final String? pharmacyName;
  final String? pharmacyPhone;
  final double? billAmount;
  final bool isBillPaid;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastRefilledAt;
  final DateTime? caregiverRequestedAt;

  const MedicineRefillModel({
    required this.id,
    required this.patientId,
    required this.medicineName,
    this.dosage = '',
    required this.refillDueDate,
    this.recurrence = 'monthly',
    this.reminderLeadDays = 5,
    this.status = 'active',
    this.prescriptionDetails,
    this.prescriptionDocumentUrl,
    this.prescriptionDocumentName,
    this.prescriptionDoctorName,
    this.prescriptionClinic,
    this.prescriptionDate,
    this.tabletsPerDose = 1,
    this.dosesPerDay = 1,
    this.totalTabletsInPack = 30,
    this.remainingTablets = 30,
    this.pharmacyName,
    this.pharmacyPhone,
    this.billAmount,
    this.isBillPaid = false,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.lastRefilledAt,
    this.caregiverRequestedAt,
  });

  /// Total tablets taken per day.
  int get tabletsPerDay => (tabletsPerDose > 0 ? tabletsPerDose : 1) * (dosesPerDay > 0 ? dosesPerDay : 1);

  /// Estimated days of supply remaining based on daily intake.
  int get daysOfSupplyRemaining =>
      tabletsPerDay > 0 ? (remainingTablets / tabletsPerDay).floor() : daysUntilDue;

  /// Days remaining until the due date (positive = upcoming, 0 = today, negative = overdue).
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(refillDueDate.year, refillDueDate.month, refillDueDate.day);
    return due.difference(today).inDays;
  }

  /// Next date to buy medication. Aligns with [refillDueDate].
  DateTime get nextDateToBuy => refillDueDate;

  /// Whether a refill reminder should be actively surfaced to the patient.
  /// Surfaced when active, ordered, or caregiver_requested and within [reminderLeadDays]
  /// or when remaining tablets reach low threshold.
  bool get isDueSoon {
    if (status == 'paused' || status == 'refilled') return false;
    return daysUntilDue <= reminderLeadDays || remainingTablets <= (tabletsPerDay * reminderLeadDays);
  }

  /// Whether the refill is in the critical last 3 days window (or due today / overdue)
  /// and neither 'Ask Caregiver to Buy' nor 'Bought the Medicine' has been resolved yet.
  bool get isDueInLast3DaysUnhandled {
    if (status != 'active') return false;
    return daysUntilDue <= 3;
  }

  /// Whether the patient has already tapped 'Ask Caregiver to Buy'.
  bool get isCaregiverRequested => status == 'caregiver_requested';

  /// Whether the refill is past its due date or out of tablets.
  bool get isOverdue => daysUntilDue < 0 || remainingTablets <= 0;

  /// Whether the refill is currently paused.
  bool get isPaused => status == 'paused';

  /// Whether the refill has been ordered.
  bool get isOrdered => status == 'ordered';

  /// Whether the refill has been marked as refilled/bought.
  bool get isRefilled => status == 'refilled';

  /// Computes next due date based on recurrence pattern, handling variable month lengths safely.
  DateTime computeNextDueDate() {
    return calculateNextDueDate(refillDueDate, recurrence) ?? refillDueDate;
  }

  /// Helper to compute the next due date given a base date and recurrence strategy ('monthly', 'weekly', 'none').
  static DateTime? calculateNextDueDate(DateTime baseDate, String recurrence) {
    if (recurrence == 'weekly') {
      return baseDate.add(const Duration(days: 7));
    }
    if (recurrence == 'monthly') {
      int nextYear = baseDate.year;
      int nextMonth = baseDate.month + 1;
      if (nextMonth > 12) {
        nextYear++;
        nextMonth = 1;
      }
      // Clamping to last day of next month if needed (e.g. Jan 31 -> Feb 28/29)
      final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
      final targetDay =
          baseDate.day > daysInNextMonth ? daysInNextMonth : baseDate.day;
      return DateTime(
        nextYear,
        nextMonth,
        targetDay,
        baseDate.hour,
        baseDate.minute,
      );
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    return null;
  }

  factory MedicineRefillModel.fromMap(Map<String, dynamic> map, String documentId) {
    final totalPack = map['totalTabletsInPack'] as int? ?? 30;
    final remaining = map['remainingTablets'] as int? ?? totalPack;

    return MedicineRefillModel(
      id: documentId,
      patientId: map['patientId'] as String? ?? '',
      medicineName: map['medicineName'] as String? ?? 'Prescription',
      dosage: map['dosage'] as String? ?? '',
      refillDueDate: _parseDateTime(map['refillDueDate']) ?? DateTime.now(),
      recurrence: map['recurrence'] as String? ?? 'monthly',
      reminderLeadDays: map['reminderLeadDays'] as int? ?? 5,
      status: map['status'] as String? ?? 'active',
      prescriptionDetails: map['prescriptionDetails'] as String?,
      prescriptionDocumentUrl: map['prescriptionDocumentUrl'] as String?,
      prescriptionDocumentName: map['prescriptionDocumentName'] as String?,
      prescriptionDoctorName: map['prescriptionDoctorName'] as String?,
      prescriptionClinic: map['prescriptionClinic'] as String?,
      prescriptionDate: _parseDateTime(map['prescriptionDate']),
      tabletsPerDose: map['tabletsPerDose'] as int? ?? 1,
      dosesPerDay: map['dosesPerDay'] as int? ?? 1,
      totalTabletsInPack: totalPack,
      remainingTablets: remaining,
      pharmacyName: map['pharmacyName'] as String?,
      pharmacyPhone: map['pharmacyPhone'] as String?,
      billAmount: (map['billAmount'] as num?)?.toDouble(),
      isBillPaid: map['isBillPaid'] as bool? ?? false,
      notes: map['notes'] as String?,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']),
      lastRefilledAt: _parseDateTime(map['lastRefilledAt']),
      caregiverRequestedAt: _parseDateTime(map['caregiverRequestedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'medicineName': medicineName.trim(),
      'dosage': dosage.trim(),
      'refillDueDate': Timestamp.fromDate(refillDueDate),
      'recurrence': recurrence,
      'reminderLeadDays': reminderLeadDays,
      'status': status,
      if (prescriptionDetails != null) 'prescriptionDetails': prescriptionDetails!.trim(),
      if (prescriptionDocumentUrl != null) 'prescriptionDocumentUrl': prescriptionDocumentUrl,
      if (prescriptionDocumentName != null) 'prescriptionDocumentName': prescriptionDocumentName!.trim(),
      if (prescriptionDoctorName != null) 'prescriptionDoctorName': prescriptionDoctorName!.trim(),
      if (prescriptionClinic != null) 'prescriptionClinic': prescriptionClinic!.trim(),
      if (prescriptionDate != null) 'prescriptionDate': Timestamp.fromDate(prescriptionDate!),
      'tabletsPerDose': tabletsPerDose,
      'dosesPerDay': dosesPerDay,
      'totalTabletsInPack': totalTabletsInPack,
      'remainingTablets': remainingTablets,
      if (pharmacyName != null) 'pharmacyName': pharmacyName!.trim(),
      if (pharmacyPhone != null) 'pharmacyPhone': pharmacyPhone!.trim(),
      if (billAmount != null) 'billAmount': billAmount,
      'isBillPaid': isBillPaid,
      if (notes != null) 'notes': notes!.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      if (lastRefilledAt != null) 'lastRefilledAt': Timestamp.fromDate(lastRefilledAt!),
      if (caregiverRequestedAt != null) 'caregiverRequestedAt': Timestamp.fromDate(caregiverRequestedAt!),
    };
  }

  MedicineRefillModel copyWith({
    String? id,
    String? patientId,
    String? medicineName,
    String? dosage,
    DateTime? refillDueDate,
    String? recurrence,
    int? reminderLeadDays,
    String? status,
    String? prescriptionDetails,
    String? prescriptionDocumentUrl,
    String? prescriptionDocumentName,
    String? prescriptionDoctorName,
    String? prescriptionClinic,
    DateTime? prescriptionDate,
    int? tabletsPerDose,
    int? dosesPerDay,
    int? totalTabletsInPack,
    int? remainingTablets,
    String? pharmacyName,
    String? pharmacyPhone,
    double? billAmount,
    bool? isBillPaid,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRefilledAt,
    DateTime? caregiverRequestedAt,
  }) {
    return MedicineRefillModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      refillDueDate: refillDueDate ?? this.refillDueDate,
      recurrence: recurrence ?? this.recurrence,
      reminderLeadDays: reminderLeadDays ?? this.reminderLeadDays,
      status: status ?? this.status,
      prescriptionDetails: prescriptionDetails ?? this.prescriptionDetails,
      prescriptionDocumentUrl: prescriptionDocumentUrl ?? this.prescriptionDocumentUrl,
      prescriptionDocumentName: prescriptionDocumentName ?? this.prescriptionDocumentName,
      prescriptionDoctorName: prescriptionDoctorName ?? this.prescriptionDoctorName,
      prescriptionClinic: prescriptionClinic ?? this.prescriptionClinic,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      tabletsPerDose: tabletsPerDose ?? this.tabletsPerDose,
      dosesPerDay: dosesPerDay ?? this.dosesPerDay,
      totalTabletsInPack: totalTabletsInPack ?? this.totalTabletsInPack,
      remainingTablets: remainingTablets ?? this.remainingTablets,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyPhone: pharmacyPhone ?? this.pharmacyPhone,
      billAmount: billAmount ?? this.billAmount,
      isBillPaid: isBillPaid ?? this.isBillPaid,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRefilledAt: lastRefilledAt ?? this.lastRefilledAt,
      caregiverRequestedAt: caregiverRequestedAt ?? this.caregiverRequestedAt,
    );
  }
}
