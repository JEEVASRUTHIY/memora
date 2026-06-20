import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth;
  final UserService _userService;
  final NotificationService _notificationService;

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _userSubscription;

  AuthProvider({
    FirebaseAuth? auth,
    required UserService userService,
    required NotificationService notificationService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _userService = userService,
        _notificationService = notificationService {
    _init();
  }

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _init() {
    _auth.authStateChanges().listen((User? user) {
      _firebaseUser = user;
      if (user != null) {
        _subscribeToUserProfile(user.uid);
        _updateFcmToken(user.uid);
      } else {
        _userModel = null;
        _userSubscription?.cancel();
        _userSubscription = null;
        notifyListeners();
      }
    });
  }

  void _subscribeToUserProfile(String userId) {
    _userSubscription?.cancel();
    _userSubscription = _userService.watchUserProfile(userId).listen((profile) {
      _userModel = profile;
      notifyListeners();
    });
  }

  Future<void> _updateFcmToken(String userId) async {
    final token = await _notificationService.getToken();
    if (token != null) {
      try {
        await _userService.updateFcmToken(userId, token);
      } catch (e) {
        debugPrint("FCM token update failed: $e");
      }
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Logs in an existing user.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? "An authentication error occurred.";
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Registers a new user.
  /// Calls Firebase Authentication first, then registers profile via Cloud Functions backend.
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String contactDetails,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    UserCredential? credential;
    try {
      // 1. Create in Firebase Auth
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // 2. Call backend function to register user profile in Firestore
      await _userService.registerUser(
        userId: uid,
        role: role,
        name: name,
        contactDetails: contactDetails,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      
      // Rollback Auth creation if profile creation failed
      if (credential != null && credential.user != null) {
        try {
          await credential.user!.delete();
        } catch (authError) {
          debugPrint("Failed to delete user rollback: $authError");
        }
      }

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Links caregiver to patient.
  Future<bool> linkPatient(String patientId) async {
    if (_userModel == null || !_userModel!.isCaregiver) {
      _errorMessage = "Only caregivers can link patients.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.linkPatient(
        caregiverId: _userModel!.userId,
        patientId: patientId,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logs out.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await _userSubscription?.cancel();
    _userSubscription = null;
    await _auth.signOut();
    _userModel = null;
    _firebaseUser = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
