import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/data/models/medicine_refill_model.dart';
import 'package:memora/data/repositories/refill_repository.dart';

final refillRepositoryProvider = Provider<RefillRepository>(
  (_) => RefillRepository(),
);

/// All refills configured for the given patient.
final patientRefillsProvider =
    StreamProvider.family<List<MedicineRefillModel>, String>((ref, patientId) {
  if (patientId.isEmpty) return Stream.value([]);
  return ref.watch(refillRepositoryProvider).watchRefills(patientId);
});

/// Refills that are active and within reminder lead time (default <= 5 days before due date).
final activeRefillAlertsProvider =
    Provider.family<List<MedicineRefillModel>, String>((ref, patientId) {
  final allRefills = ref.watch(patientRefillsProvider(patientId)).valueOrNull ?? [];
  return allRefills.where((r) => r.isDueSoon).toList();
});

class RefillManagementNotifier extends FamilyNotifier<AsyncValue<void>, String> {
  RefillRepository get _repo => ref.read(refillRepositoryProvider);
  late String _patientId;

  @override
  AsyncValue<void> build(String patientId) {
    _patientId = patientId;
    return const AsyncData(null);
  }

  Future<bool> saveRefill(MedicineRefillModel refill, {required bool isNew}) async {
    state = const AsyncLoading();
    try {
      if (isNew) {
        await _repo.createRefill(_patientId, refill);
      } else {
        await _repo.updateRefill(_patientId, refill);
      }
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> deleteRefill(String refillId) async {
    state = const AsyncLoading();
    try {
      await _repo.deleteRefill(_patientId, refillId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> markOrdered(String refillId) async {
    state = const AsyncLoading();
    try {
      await _repo.markOrdered(_patientId, refillId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> askCaregiverToBuy(String refillId) async {
    state = const AsyncLoading();
    try {
      await _repo.askCaregiverToBuy(_patientId, refillId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> markBought(MedicineRefillModel refill, {int? replenishedTablets}) async {
    state = const AsyncLoading();
    try {
      await _repo.markBought(_patientId, refill, replenishedTablets: replenishedTablets);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> markRefilled(MedicineRefillModel refill, {int? replenishedTablets}) async {
    return markBought(refill, replenishedTablets: replenishedTablets);
  }

  Future<bool> togglePause(String refillId, bool isCurrentlyPaused) async {
    state = const AsyncLoading();
    try {
      await _repo.togglePause(_patientId, refillId, isCurrentlyPaused);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final refillManagementProvider =
    NotifierProvider.family<RefillManagementNotifier, AsyncValue<void>, String>(
  RefillManagementNotifier.new,
);
