import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:memora/data/models/user_model.dart';
import 'package:memora/data/repositories/user_repository.dart';
import 'package:memora/data/repositories/link_repository.dart';
import 'package:memora/core/constants/app_constants.dart';
import 'package:memora/core/errors/app_error_handler.dart';

/// High-level authentication and linking operations.
class AuthService {
  final FirebaseAuth _auth;
  final UserRepository _userRepo;
  final LinkRepository _linkRepo;

  AuthService({
    FirebaseAuth? auth,
    UserRepository? userRepo,
    LinkRepository? linkRepo,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _userRepo = userRepo ?? UserRepository(),
        _linkRepo = linkRepo ?? LinkRepository();

  // ── Auth state ─────────────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  // ── Profile stream ─────────────────────────────────────────────────────────

  Stream<UserModel?> watchCurrentUser(String uid) =>
      _userRepo.watchUser(uid);

  // ── Registration ───────────────────────────────────────────────────────────

  /// Register Auth first, then persist the user's Firestore documents.
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final authUser = _auth.currentUser;
      if (authUser == null || authUser.uid != cred.user!.uid) {
        throw StateError('Your account was created, but your sign-in session is unavailable. Please try again.');
      }
      final uid = authUser.uid;

      String? patientId;
      if (role == AppConstants.rolePatient) {
        patientId = _generatePatientId();
      }

      final user = UserModel(
        uid: uid,
        role: role,
        name: name.trim(),
        email: email.trim(),
        patientId: patientId,
        fcmTokens: const [],
        createdAt: DateTime.now(),
      );

      if (role == AppConstants.rolePatient) {
        final registeredUser = await _userRepo.createPatientRegistration(
          user: user,
        );
        return registeredUser;
      } else {
        await _userRepo.createCaregiverRegistration(user);
      }
      return user;
    } on FirebaseException catch (error) {
      final uid = _auth.currentUser?.uid ?? 'unknown';
      debugPrint('[AuthService] Firestore paths users/$uid and emailIndex/${email.trim().toLowerCase()}; code=${error.code}; error=$error');
      throw Exception(AppErrorHandler.handle(error));
    } catch (e) {
      throw Exception(AppErrorHandler.handle(e));
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid != null) {
        final profile = await _userRepo.getUser(uid);
        if (profile?.isPatient == true && profile?.patientId != null) {
          await _userRepo.ensurePatientCode(
            uid: uid,
            patientId: profile!.patientId!,
          );
        }
      }
      // Store FCM token (arrayUnion — safe if already present)
      _storeFcmToken(cred.user?.uid);
    } catch (e) {
      throw Exception(AppErrorHandler.handle(e));
    }
  }

  /// Registers FCM token for this device with arrayUnion (called on login/refresh).
  void _storeFcmToken(String? uid) {
    if (uid == null) return;
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) updateFcmToken(uid, token);
    }).catchError((e) {
      debugPrint('[AuthService] FCM token store failed: $e');
    });
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _userRepo.removeFcmToken(uid, token);
      } catch (e) {
        debugPrint('[AuthService] FCM token removal on logout failed: $e');
      }
    }
    await _auth.signOut();
  }

  // ── Free-mode linking ─────────────────────────────────────────────────────

  /// Calls the `requestLink` Cloud Function.
  /// Returns the result map {linkId, role, status}.
  Future<Map<String, dynamic>> requestLink(String patientId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('Please sign in again.');
      final caregiver = await _userRepo.getUser(uid);
      if (caregiver == null) throw StateError('Your profile could not be found.');
      final normalizedId = patientId.trim().toUpperCase();
      return await _linkRepo.requestLink(normalizedId, caregiver);
    } on FirebaseException catch (error) {
      final normalizedId = patientId.trim().toUpperCase();
      debugPrint(
        '[AuthService] Firestore paths patientCodes/$normalizedId and '
        'links/${normalizedId}_${_auth.currentUser?.uid ?? 'unknown'}; '
        'code=${error.code}; error=$error',
      );
      throw Exception(AppErrorHandler.handle(error));
    } catch (e) {
      final msg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Bad state: ', '');
      throw Exception(msg);
    }
  }

  /// Calls the `respondToLink` Cloud Function (primary caregiver only).
  Future<Map<String, dynamic>> respondToLink(
      String linkId, bool approve) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('Please sign in again.');
      return await _linkRepo.respondToLink(linkId, approve, uid);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw Exception(msg);
    }
  }

  /// Calls the `removeSecondary` Cloud Function (primary caregiver only).
  Future<void> removeSecondary(String linkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('Please sign in again.');
      await _linkRepo.removeSecondary(linkId, uid);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> addBackupCaregiver({
    required String patientId,
    required String email,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Please sign in again.');
    try {
      return await _linkRepo.addBackupCaregiver(
        patientId: patientId,
        email: email,
        primaryUid: uid,
      );
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> finishOnboarding(String uid) => _userRepo.setOnboardingDone(uid);

  Future<String> savePatientProfile({
    required String uid,
    required String? patientId,
    required String name,
    required int age,
    required String details,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null || authUser.uid != uid) {
      throw Exception('Please sign in again before saving your patient profile.');
    }
    try {
      return await _userRepo.createPatientProfile(
        uid: uid,
        existingPatientId: patientId,
        name: name,
        age: age,
        details: details,
        timezone: _deviceTimezone(),
      );
    } on FirebaseException catch (error) {
      throw Exception(AppErrorHandler.handle(error));
    }
  }

  // ── FCM Token ──────────────────────────────────────────────────────────────

  Future<void> updateFcmToken(String uid, String token) async {
    try {
      await _userRepo.addFcmToken(uid, token);
    } catch (e) {
      debugPrint('[AuthService] FCM token update failed: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _generatePatientId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(
      AppConstants.patientIdLength,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }

  String _deviceTimezone() {
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    final sign = offset >= 0 ? '+' : '-';
    final hours = (offset.abs() ~/ 60).toString().padLeft(2, '0');
    final minutes = (offset.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }
}
