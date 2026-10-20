import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to manage the medicine storage location photo.
/// Caregivers can update this photo with custom images or presets,
/// and patients will see it on their incoming reminder screen.
class MedicinePhotoService {
  static final MedicinePhotoService _instance =
      MedicinePhotoService._internal();
  factory MedicinePhotoService() => _instance;
  MedicinePhotoService._internal();

  static const String defaultAssetPhoto =
      'assets/images/medicine_location.jpg';
  static const String defaultDescription =
      'Top shelf in medicine cabinet';

  String _cachedPhotoUrl = defaultAssetPhoto;
  String _cachedDescription = defaultDescription;

  String get currentPhotoUrl => _cachedPhotoUrl;
  String get currentDescription => _cachedDescription;

  /// Watch photo updates for a patient from Firestore
  Stream<Map<String, String>> watchLocationPhoto(String patientId) {
    if (patientId.isEmpty) {
      return Stream.value({
        'photoUrl': _cachedPhotoUrl,
        'description': _cachedDescription,
      });
    }

    return FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      final photoUrl = (data?['medicineLocationPhoto'] as String?)?.trim();
      final desc = (data?['medicineLocationDesc'] as String?)?.trim();

      if (photoUrl != null && photoUrl.isNotEmpty) {
        _cachedPhotoUrl = photoUrl;
      }
      if (desc != null && desc.isNotEmpty) {
        _cachedDescription = desc;
      }

      return {
        'photoUrl': _cachedPhotoUrl,
        'description': _cachedDescription,
      };
    }).handleError((e) {
      debugPrint('[MedicinePhotoService] Error watching photo: $e');
      return {
        'photoUrl': _cachedPhotoUrl,
        'description': _cachedDescription,
      };
    });
  }

  /// Caregiver updates the medicine storage photo and description
  Future<void> updateLocationPhoto({
    required String patientId,
    required String photoUrl,
    required String description,
  }) async {
    _cachedPhotoUrl = photoUrl;
    _cachedDescription = description;

    if (patientId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .set({
          'medicineLocationPhoto': photoUrl,
          'medicineLocationDesc': description,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[MedicinePhotoService] Failed to update in Firestore: $e');
      }
    }
  }

  /// Preset storage places caregivers can quickly pick
  static const List<Map<String, String>> presetLocations = [
    {
      'title': 'Bathroom Medicine Cabinet',
      'desc': 'Top shelf in medicine cabinet',
      'url': 'assets/images/medicine_location.jpg',
    },
    {
      'title': 'Bedside Table Drawer',
      'desc': 'Top drawer of bedside nightstand',
      'url': 'https://images.unsplash.com/photo-1540518614846-7ede433c4ef3?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Kitchen Countertop Basket',
      'desc': 'Designated basket on kitchen counter',
      'url': 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=600&auto=format&fit=crop&q=80',
    },
  ];
}
