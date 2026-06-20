import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class UserService {
  final UserRepository _repository;
  final http.Client _client;
  final String _baseUrl;

  UserService({
    required UserRepository userRepository,
    http.Client? client,
    String? baseUrl,
  })  : _repository = userRepository,
        _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://us-central1-memora-app.cloudfunctions.net/users'; // Default placeholder

  /// Registers user profile directly in Firestore.
  Future<UserModel> registerUser({
    required String userId,
    required String role,
    required String name,
    required String contactDetails,
  }) async {
    try {
      final user = UserModel(
        userId: userId,
        role: role,
        name: name,
        contactDetails: contactDetails,
      );
      await _repository.saveUser(user);
      return user;
    } catch (e) {
      throw Exception('Error during registration: $e');
    }
  }

  /// Links caregiver to patient directly in Firestore.
  Future<void> linkPatient({
    required String caregiverId,
    required String patientId,
  }) async {
    try {
      await _repository.linkPatient(
        caregiverId: caregiverId,
        patientId: patientId,
      );
    } catch (e) {
      throw Exception('Error during linking: $e');
    }
  }

  /// Updates the user's FCM token in Firestore.
  Future<void> updateFcmToken(String userId, String token) async {
    try {
      await _repository.updateFields(userId, {'fcmToken': token});
    } catch (e) {
      throw Exception('Failed to update FCM token: $e');
    }
  }

  /// Gets the user profile locally/from repository
  Future<UserModel?> getUserProfile(String userId) => _repository.getUser(userId);

  /// Watches the user profile locally/from repository
  Stream<UserModel?> watchUserProfile(String userId) => _repository.watchUser(userId);
}
