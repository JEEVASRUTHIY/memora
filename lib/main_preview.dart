import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'theme/app_theme.dart';
import 'repositories/user_repository.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'models/user_model.dart';
import 'main.dart';

class PreviewState {
  static String? linkedPatientId;
  static String? linkedCaregiverId;
}

class MockUser extends Fake implements User {
  @override
  String get uid => 'mock_user_123';
  @override
  String? get email => 'user@example.com';
}

class FakeFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => Stream.value(null);
  @override
  Stream<User?> idTokenChanges() => Stream.value(null);
  @override
  Stream<User?> userChanges() => Stream.value(null);
}

class FakeUserRepository extends Fake implements UserRepository {}

class FakeUserService extends Fake implements UserService {
  @override
  Stream<UserModel?> watchUserProfile(String userId) {
    final isPatient = userId.contains('patient');
    return Stream.value(UserModel(
      userId: userId,
      role: isPatient ? 'Patient' : 'Caregiver',
      name: isPatient ? 'Jimmy Patient' : 'Jane Caregiver',
      contactDetails: isPatient ? 'jimmy@example.com' : 'jane@example.com',
      linkedPatientId: isPatient ? null : PreviewState.linkedPatientId,
      linkedCaregiverId: isPatient ? PreviewState.linkedCaregiverId : null,
    ));
  }
}

class FakeNotificationService extends Fake implements NotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> getToken() async => 'mock-token';
}

class PreviewAuthProvider extends AuthProvider {
  PreviewAuthProvider() : super(
    auth: FakeFirebaseAuth(),
    userService: FakeUserService(),
    notificationService: FakeNotificationService(),
  );

  User? _mockFirebaseUser;
  UserModel? _mockUserModel;
  bool _mockIsLoading = false;
  String? _mockErrorMessage;

  @override
  User? get firebaseUser => _mockFirebaseUser;

  @override
  UserModel? get userModel => _mockUserModel;

  @override
  bool get isLoading => _mockIsLoading;

  @override
  String? get errorMessage => _mockErrorMessage;

  @override
  Future<bool> login(String email, String password) async {
    _mockIsLoading = true;
    _mockErrorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    if (email.contains('error')) {
      _mockErrorMessage = 'Invalid credentials or user not found.';
      _mockIsLoading = false;
      notifyListeners();
      return false;
    }

    _mockFirebaseUser = MockUser();
    // Determine role by email content
    final isPatient = email.toLowerCase().contains('patient');
    _mockUserModel = UserModel(
      userId: isPatient ? 'patient123' : 'caregiver123',
      role: isPatient ? 'Patient' : 'Caregiver',
      name: isPatient ? 'Jimmy Patient' : 'Jane Caregiver',
      contactDetails: email,
      linkedPatientId: isPatient ? null : PreviewState.linkedPatientId,
      linkedCaregiverId: isPatient ? PreviewState.linkedCaregiverId : null,
    );

    _mockIsLoading = false;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String contactDetails,
  }) async {
    _mockIsLoading = true;
    _mockErrorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    _mockFirebaseUser = MockUser();
    final isPatient = role == 'Patient';
    _mockUserModel = UserModel(
      userId: isPatient ? 'patient123' : 'caregiver123',
      role: role,
      name: name,
      contactDetails: contactDetails,
      linkedPatientId: isPatient ? null : PreviewState.linkedPatientId,
      linkedCaregiverId: isPatient ? PreviewState.linkedCaregiverId : null,
    );

    _mockIsLoading = false;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> linkPatient(String patientId) async {
    _mockIsLoading = true;
    _mockErrorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    if (patientId == 'error') {
      _mockErrorMessage = 'Patient ID not found or already linked.';
      _mockIsLoading = false;
      notifyListeners();
      return false;
    }

    PreviewState.linkedPatientId = patientId;
    PreviewState.linkedCaregiverId = _mockUserModel?.userId ?? 'caregiver123';

    _mockUserModel = _mockUserModel?.copyWith(
      linkedPatientId: patientId,
    );

    _mockIsLoading = false;
    notifyListeners();
    return true;
  }

  @override
  Future<void> logout() async {
    _mockIsLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _mockFirebaseUser = null;
    _mockUserModel = null;
    _mockIsLoading = false;
    notifyListeners();
  }
}

void main() {
  final userRepository = FakeUserRepository();
  final notificationService = FakeNotificationService();
  final userService = FakeUserService();
  final authProvider = PreviewAuthProvider();

  runApp(
    MultiProvider(
      providers: [
        Provider<UserRepository>.value(value: userRepository),
        Provider<NotificationService>.value(value: notificationService),
        Provider<UserService>.value(value: userService),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const MemoraApp(),
    ),
  );
}
