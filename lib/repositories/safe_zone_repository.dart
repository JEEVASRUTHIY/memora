import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/safe_zone_model.dart';
import '../models/location_log_model.dart';

class SafeZoneRepository {
  final FirebaseFirestore _firestore;

  SafeZoneRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _safeZonesCollection =>
      _firestore.collection('safeZones');

  CollectionReference<Map<String, dynamic>> get _logsCollection =>
      _firestore.collection('locationLogs');

  /// Watches changes to a patient's safe zone configuration.
  Stream<SafeZoneModel?> watchSafeZone(String patientId) {
    return _safeZonesCollection.doc(patientId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return SafeZoneModel.fromJson(snapshot.data()!);
      }
      return null;
    });
  }

  /// Fetches a patient's safe zone configuration.
  Future<SafeZoneModel?> getSafeZone(String patientId) async {
    try {
      final doc = await _safeZonesCollection.doc(patientId).get();
      if (doc.exists && doc.data() != null) {
        return SafeZoneModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Watches the latest location log for a patient.
  Stream<LocationLogModel?> watchLatestLocation(String patientId) {
    return _logsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return LocationLogModel.fromJson(snapshot.docs.first.data(), id: snapshot.docs.first.id);
      }
      return null;
    });
  }

  /// Watches recent location logs for a patient.
  Stream<List<LocationLogModel>> watchRecentLogs(String patientId, {int limit = 100}) {
    return _logsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LocationLogModel.fromJson(doc.data(), id: doc.id)).toList();
    });
  }

  /// Fetches a paginated list of location logs.
  Future<List<LocationLogModel>> getLogsPage(String patientId, {int limit = 100, DocumentSnapshot? startAfterDoc}) async {
    try {
      var query = _logsCollection
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => LocationLogModel.fromJson(doc.data(), id: doc.id)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches location logs query snapshot directly (for pagination tests).
  Future<QuerySnapshot<Map<String, dynamic>>> getLocationLogsQuerySnapshot(
    String patientId, {
    int limit = 100,
    DocumentSnapshot? startAfterDoc,
  }) async {
    var query = _logsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    return query.get();
  }

  /// Fetches logs using starting timestamp cursor.
  Future<List<LocationLogModel>> getLogsByTimestamp(String patientId, {int limit = 100, DateTime? startAfterTime}) async {
    try {
      var query = _logsCollection
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfterTime != null) {
        query = query.startAfter([Timestamp.fromDate(startAfterTime)]);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => LocationLogModel.fromJson(doc.data(), id: doc.id)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
