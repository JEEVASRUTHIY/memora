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

  /// Calls the Cloud Function: POST /users/register
  Future<UserModel> registerUser({
    required String userId,
    required String role,
    required String name,
    required String contactDetails,
  }) async {
    final url = Uri.parse('$_baseUrl/register');
    
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'role': role,
          'name': name,
          'contactDetails': contactDetails,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data['user']);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Network error during registration: $e');
    }
  }

  /// Calls the Cloud Function: POST /users/link-patient
  Future<void> linkPatient({
    required String caregiverId,
    required String patientId,
  }) async {
    final url = Uri.parse('$_baseUrl/link-patient');

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'caregiverId': caregiverId,
          'patientId': patientId,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Linking failed');
      }
    } catch (e) {
      throw Exception('Network error during linking: $e');
    }
  }

  /// Gets the user profile locally/from repository
  Future<UserModel?> getUserProfile(String userId) => _repository.getUser(userId);

  /// Watches the user profile locally/from repository
  Stream<UserModel?> watchUserProfile(String userId) => _repository.watchUser(userId);
}
