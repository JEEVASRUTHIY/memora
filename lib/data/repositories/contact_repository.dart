import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:memora/data/models/emergency_contact_model.dart';

/// Repository managing Emergency Contacts stored in:
/// `patients/{patientId}/contacts/{contactId}`
class ContactRepository {
  final FirebaseFirestore _db;

  ContactRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _contactsRef(String patientId) {
    final cleanId = patientId.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError('patientId cannot be empty when accessing contacts.');
    }
    return _db.collection('patients').doc(cleanId).collection('contacts');
  }

  /// Live stream of emergency contacts for a given patient.
  Stream<List<EmergencyContactModel>> watchContacts(String patientId) {
    if (patientId.trim().isEmpty) {
      return Stream.value(const <EmergencyContactModel>[]);
    }

    return _contactsRef(patientId)
        .snapshots()
        .map((snapshot) {
          final contacts = snapshot.docs.map((doc) {
            return EmergencyContactModel.fromMap(doc.data(), doc.id);
          }).toList();

          // Sort in memory: primary contacts first, then alphabetically by name
          contacts.sort((a, b) {
            if (a.isPrimary != b.isPrimary) {
              return a.isPrimary ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

          return contacts;
        })
        .handleError((error) {
          debugPrint('[ContactRepository] Error reading contacts for $patientId: $error');
          throw error;
        });
  }

  /// One-time fetch of emergency contacts.
  Future<List<EmergencyContactModel>> getContacts(String patientId) async {
    if (patientId.trim().isEmpty) return const [];
    try {
      final snap = await _contactsRef(patientId).get().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Connection timed out while fetching contacts.'),
          );
      final list = snap.docs
          .map((doc) => EmergencyContactModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    } catch (e) {
      debugPrint('[ContactRepository] Error getting contacts: $e');
      rethrow;
    }
  }

  /// Add a new contact for the patient.
  Future<String> createContact(EmergencyContactModel contact) async {
    final ref = _contactsRef(contact.patientId);
    final batch = _db.batch();

    // If this contact is marked primary, unmark other contacts to preserve single primary
    if (contact.isPrimary) {
      try {
        final existing = await ref
            .where('isPrimary', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 8));
        for (final doc in existing.docs) {
          batch.update(doc.reference, {'isPrimary': false});
        }
      } catch (e) {
        debugPrint('[ContactRepository] Warning: failed to query primary contacts: $e');
      }
    }

    final newDoc = ref.doc();
    batch.set(newDoc, {
      ...contact.toMap(),
      'patientId': contact.patientId.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit().timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('Connection timed out while saving contact. Please try again.'),
        );
    return newDoc.id;
  }

  /// Update an existing contact.
  Future<void> updateContact(EmergencyContactModel contact) async {
    final ref = _contactsRef(contact.patientId);
    final batch = _db.batch();

    if (contact.isPrimary) {
      try {
        final existing = await ref
            .where('isPrimary', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 8));
        for (final doc in existing.docs) {
          if (doc.id != contact.id) {
            batch.update(doc.reference, {'isPrimary': false});
          }
        }
      } catch (e) {
        debugPrint('[ContactRepository] Warning: failed to query primary contacts: $e');
      }
    }

    batch.update(ref.doc(contact.id), {
      'name': contact.name.trim(),
      'phoneNumber': contact.phoneNumber.trim(),
      'relationship': contact.relationship.trim(),
      'isPrimary': contact.isPrimary,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit().timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('Connection timed out while updating contact. Please try again.'),
        );
  }

  /// Delete a contact with given contactId.
  Future<void> deleteContact(String patientId, String contactId) async {
    await _contactsRef(patientId).doc(contactId).delete().timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('Connection timed out while deleting contact.'),
        );
  }
}
