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
import 'dart:async';
import 'models/reminder_model.dart';
import 'models/reminder_log_model.dart';
import 'repositories/reminder_repository.dart';
import 'services/reminder_service.dart';
import 'providers/reminder_provider.dart';

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

class FakeReminderRepository extends Fake implements ReminderRepository {
  final List<ReminderModel> _reminders = [];
  final List<ReminderLogModel> _logs = [];

  final _remindersController = StreamController<List<ReminderModel>>.broadcast();
  final _logsController = StreamController<List<ReminderLogModel>>.broadcast();

  FakeReminderRepository() {
    // Add default mock reminders for the preview run
    _reminders.add(ReminderModel(
      reminderId: 'rem_1',
      patientId: 'patient123',
      description: 'Take Blood Pressure Tablet',
      instructions: 'Take 1 tablet after breakfast.',
      reminderType: 'Medication',
      scheduledTime: DateTime.now().add(const Duration(minutes: 5)),
      severityLevel: 'High',
      escalationWaitingDuration: 1, // 1 minute for quick testing
      activeStatus: true,
    ));
    _reminders.add(ReminderModel(
      reminderId: 'rem_2',
      patientId: 'patient123',
      description: 'Morning Walk',
      instructions: 'Walk around the garden for 15 minutes.',
      reminderType: 'Routine',
      scheduledTime: DateTime.now().add(const Duration(hours: 2)),
      severityLevel: 'Low',
      escalationWaitingDuration: 15,
      activeStatus: true,
    ));
  }

  @override
  Future<ReminderModel> createReminder(ReminderModel reminder) async {
    final id = reminder.reminderId.isEmpty 
        ? 'rem_${DateTime.now().millisecondsSinceEpoch}' 
        : reminder.reminderId;
    final newReminder = reminder.copyWith(reminderId: id);
    _reminders.add(newReminder);
    _remindersController.add(List.from(_reminders));
    return newReminder;
  }

  @override
  Future<void> updateReminder(ReminderModel reminder) async {
    final index = _reminders.indexWhere((r) => r.reminderId == reminder.reminderId);
    if (index != -1) {
      _reminders[index] = reminder;
      _remindersController.add(List.from(_reminders));
    }
  }

  @override
  Future<ReminderModel?> getReminder(String reminderId) async {
    try {
      return _reminders.firstWhere((r) => r.reminderId == reminderId);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<ReminderModel>> watchReminders(String patientId) async* {
    yield _reminders.where((r) => r.patientId == patientId).toList();
    yield* _remindersController.stream.map(
      (list) => list.where((r) => r.patientId == patientId).toList(),
    );
  }

  @override
  Stream<List<ReminderModel>> watchActiveReminders(String patientId) async* {
    yield _reminders.where((r) => r.patientId == patientId && r.activeStatus).toList();
    yield* _remindersController.stream.map(
      (list) => list.where((r) => r.patientId == patientId && r.activeStatus).toList(),
    );
  }

  @override
  Future<ReminderLogModel> createReminderLog(ReminderLogModel log) async {
    final id = log.logId.isEmpty 
        ? 'log_${DateTime.now().millisecondsSinceEpoch}' 
        : log.logId;
    final newLog = log.copyWith(logId: id);
    _logs.add(newLog);
    _logsController.add(List.from(_logs));
    return newLog;
  }

  @override
  Future<void> updateReminderLogStatus(String logId, String status, {bool? escalationNotified}) async {
    final index = _logs.indexWhere((l) => l.logId == logId);
    if (index != -1) {
      _logs[index] = _logs[index].copyWith(
        status: status,
        actionTime: DateTime.now(),
        escalationNotified: escalationNotified ?? _logs[index].escalationNotified,
      );
      _logsController.add(List.from(_logs));
    }
  }

  @override
  Future<ReminderLogModel?> getReminderLog(String logId) async {
    try {
      return _logs.firstWhere((l) => l.logId == logId);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<ReminderLogModel>> watchReminderLogs(String patientId) async* {
    final filtered = _logs.where((l) => l.patientId == patientId).toList();
    filtered.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    yield filtered;
    yield* _logsController.stream.map((list) {
      final subList = list.where((l) => l.patientId == patientId).toList();
      subList.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      return subList;
    });
  }
}


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
  final reminderRepository = FakeReminderRepository();
  final reminderService = ReminderService(reminderRepository: reminderRepository);

  runApp(
    MultiProvider(
      providers: [
        Provider<UserRepository>.value(value: userRepository),
        Provider<NotificationService>.value(value: notificationService),
        Provider<UserService>.value(value: userService),
        Provider<ReminderRepository>.value(value: reminderRepository),
        Provider<ReminderService>.value(value: reminderService),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ReminderProvider>(
          create: (context) => ReminderProvider(
            reminderService: reminderService,
          ),
        ),
      ],
      child: const MemoraApp(),
    ),
  );
}
