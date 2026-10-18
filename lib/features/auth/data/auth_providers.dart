import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/data/services/auth_service.dart';
import 'package:memora/data/repositories/user_repository.dart';
import 'package:memora/data/repositories/link_repository.dart';
import 'package:memora/data/models/user_model.dart';
import 'package:memora/data/models/link_model.dart';
import 'package:memora/data/models/patient_profile.dart';

// ── Singleton providers ────────────────────────────────────────────────────

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

final linkRepositoryProvider = Provider<LinkRepository>(
  (ref) => LinkRepository(),
);

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    userRepo: ref.watch(userRepositoryProvider),
    linkRepo: ref.watch(linkRepositoryProvider),
  );
});

// ── Auth state ─────────────────────────────────────────────────────────────

/// Emits null (signed out) or a [User] (signed in).
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// The full Firestore [UserModel] for the current user, streamed live.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(firebaseAuthStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(authServiceProvider).watchCurrentUser(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

final patientProfileProvider = StreamProvider<PatientProfile?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || !user.isPatient) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchOrCreatePatientProfile(
        uid: user.uid,
        patientId: user.patientId,
      );
});

final linkedPatientProfileProvider =
    StreamProvider.family<PatientProfile?, String>((ref, patientId) {
  return ref.watch(userRepositoryProvider).watchPatientProfile(patientId);
});

// ── Link streams ───────────────────────────────────────────────────────────

/// All active+pending links for the current caregiver.
final caregiverLinksProvider = StreamProvider<List<LinkModel>>((ref) {
  final authState = ref.watch(firebaseAuthStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(linkRepositoryProvider).watchLinksForCaregiver(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// All active+pending links for the current patient.
final patientLinksProvider = StreamProvider<List<LinkModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null || user.isCaregiver) return const Stream.empty();
      return ref.watch(linkRepositoryProvider).watchLinksForPatient(user.patientId!);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Pending secondary links for the primary caregiver's patient (for approval UI).
final pendingSecondaryLinksProvider =
    StreamProvider.family<List<LinkModel>, String>((ref, patientUid) {
  return ref.watch(linkRepositoryProvider).watchPendingLinksForPatient(patientUid);
});

final primaryPatientLinksProvider = StreamProvider<List<LinkModel>>((ref) {
  final links = ref.watch(caregiverLinksProvider).valueOrNull ?? const <LinkModel>[];
  final primary = links.where((link) => link.isPrimary && link.isActive).firstOrNull;
  if (primary == null) return const Stream.empty();
  return ref.watch(linkRepositoryProvider).watchLinksForPatient(primary.patientId);
});

// ── Auth notifier ──────────────────────────────────────────────────────────

/// Holds transient UI state (loading / error) for auth operations.
class AuthNotifier extends StateNotifier<AuthUiState> {
  final AuthService? _service;
  final Ref? _ref;

  AuthNotifier(this._service, [this._ref]) : super(const AuthUiState());
  AuthNotifier.test() : _service = null, _ref = null, super(const AuthUiState());

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _service!.login(email: email, password: password);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', ''),
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _service!.register(
        email: email,
        password: password,
        name: name,
        role: role,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Bad state: ', ''),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    _ref?.invalidate(currentUserProvider);
    _ref?.invalidate(patientProfileProvider);
    _ref?.invalidate(caregiverLinksProvider);
    _ref?.invalidate(patientLinksProvider);
    _ref?.invalidate(primaryPatientLinksProvider);
    await _service!.logout();
    state = const AuthUiState();
  }

  void clearError() => state = state.copyWith(errorMessage: null);
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthUiState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider), ref);
});

// ── Link notifier ──────────────────────────────────────────────────────────

class LinkNotifier extends StateNotifier<LinkUiState> {
  final AuthService _service;

  LinkNotifier(this._service) : super(const LinkUiState());

  Future<bool> requestLink(String patientId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);
    try {
      final result = await _service.requestLink(patientId);
      final role = result['role'] as String? ?? 'secondary';
      final status = result['status'] as String? ?? 'pending';
      state = state.copyWith(
        isLoading: false,
        success: true,
        resultRole: role,
        resultStatus: status,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', ''),
      );
      return false;
    }
  }

  Future<bool> addBackupCaregiver(String patientId, String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);
    try {
      await _service.addBackupCaregiver(patientId: patientId, email: email);
      state = state.copyWith(isLoading: false, success: true,
          resultRole: 'secondary', resultStatus: 'active');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false,
          errorMessage: e.toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', ''));
      return false;
    }
  }

  void clearError() => state = state.copyWith(errorMessage: null);
}

final linkNotifierProvider =
    StateNotifierProvider.family<LinkNotifier, LinkUiState, String>(
  (ref, caregiverUid) => LinkNotifier(ref.watch(authServiceProvider)),
);

// ── Caregiver management notifier ─────────────────────────────────────────

class CaregiverManagementNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _service;

  CaregiverManagementNotifier(this._service) : super(const AsyncData(null));

  Future<void> respondToLink(String linkId, bool approve) async {
    state = const AsyncLoading();
    try {
      await _service.respondToLink(linkId, approve);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> removeSecondary(String linkId) async {
    state = const AsyncLoading();
    try {
      await _service.removeSecondary(linkId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final caregiverManagementProvider =
    StateNotifierProvider<CaregiverManagementNotifier, AsyncValue<void>>((ref) {
  return CaregiverManagementNotifier(ref.watch(authServiceProvider));
});

// ── UI state models ────────────────────────────────────────────────────────

class AuthUiState {
  final bool isLoading;
  final String? errorMessage;

  const AuthUiState({this.isLoading = false, this.errorMessage});

  AuthUiState copyWith({bool? isLoading, String? errorMessage}) {
    return AuthUiState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class LinkUiState {
  final bool isLoading;
  final bool success;
  final String? errorMessage;
  final String? resultRole;   // 'primary' | 'secondary'
  final String? resultStatus; // 'active' | 'pending'

  const LinkUiState({
    this.isLoading = false,
    this.success = false,
    this.errorMessage,
    this.resultRole,
    this.resultStatus,
  });

  LinkUiState copyWith({
    bool? isLoading,
    bool? success,
    String? errorMessage,
    String? resultRole,
    String? resultStatus,
  }) {
    return LinkUiState(
      isLoading: isLoading ?? this.isLoading,
      success: success ?? this.success,
      errorMessage: errorMessage,
      resultRole: resultRole ?? this.resultRole,
      resultStatus: resultStatus ?? this.resultStatus,
    );
  }
}
