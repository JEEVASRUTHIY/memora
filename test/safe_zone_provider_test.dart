import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_async/fake_async.dart';
import 'package:memora/providers/safe_zone_provider.dart';
import 'package:memora/services/safe_zone_service.dart';
import 'package:memora/repositories/safe_zone_repository.dart';
import 'package:memora/models/safe_zone_model.dart';
import 'package:memora/models/location_log_model.dart';

// Mocks
class MockSafeZoneService extends Mock implements SafeZoneService {}
class MockSafeZoneRepository extends Mock implements SafeZoneRepository {}

class FakeQuerySnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockSafeZoneService mockService;
  late MockSafeZoneRepository mockRepository;
  late SafeZoneProvider provider;
  late StreamController<SafeZoneModel?> safeZoneStreamController;
  late StreamController<LocationLogModel?> locationStreamController;

  final testSafeZone = SafeZoneModel(
    patientId: 'patient123',
    homeLatitude: 37.7749,
    homeLongitude: -122.4194,
    radius: 200,
    activeStatus: true,
    updatedAt: DateTime.now(),
  );

  final testLocationLog = LocationLogModel(
    id: 'log123',
    patientId: 'patient123',
    latitude: 37.7749,
    longitude: -122.4194,
    status: 'Inside',
    breachFlag: false,
    lastKnownLocation: 'Inside safe zone',
    timestamp: DateTime.now(),
  );

  setUpAll(() {
    registerFallbackValue(testSafeZone);
    registerFallbackValue(testLocationLog);
  });

  setUp(() {
    mockService = MockSafeZoneService();
    mockRepository = MockSafeZoneRepository();

    safeZoneStreamController = StreamController<SafeZoneModel?>.broadcast();
    locationStreamController = StreamController<LocationLogModel?>.broadcast();

    when(() => mockRepository.watchSafeZone(any())).thenAnswer((_) => safeZoneStreamController.stream);
    when(() => mockRepository.watchLatestLocation(any())).thenAnswer((_) => locationStreamController.stream);
    
    // Stub history paging
    when(() => mockRepository.getLocationLogsQuerySnapshot(any(), limit: any(named: 'limit'), startAfterDoc: any(named: 'startAfterDoc')))
        .thenAnswer((_) async => FakeQuerySnapshot());

    provider = SafeZoneProvider(
      safeZoneRepository: mockRepository,
      safeZoneService: mockService,
    );
  });

  tearDown(() {
    safeZoneStreamController.close();
    locationStreamController.close();
    try {
      provider.dispose();
    } catch (_) {}
  });

  group('SafeZoneProvider Tests', () {
    test('initialize registers streams and loads safe zone', () {
      fakeAsync((async) {
        provider.initialize('patient123', isPatient: true);

        safeZoneStreamController.add(testSafeZone);
        locationStreamController.add(testLocationLog);
        async.elapse(const Duration(seconds: 1));

        expect(provider.currentSafeZone, equals(testSafeZone));
        expect(provider.latestLocation, equals(testLocationLog));
        expect(provider.isLoading, isFalse);
      });
    });

    test('configureSafeZone calls service and updates status', () async {
      when(() => mockService.configureSafeZone(
            caregiverId: any(named: 'caregiverId'),
            patientId: any(named: 'patientId'),
            homeLatitude: any(named: 'homeLatitude'),
            homeLongitude: any(named: 'homeLongitude'),
            radius: any(named: 'radius'),
            activeStatus: any(named: 'activeStatus'),
          )).thenAnswer((_) async => testSafeZone);

      final success = await provider.configureSafeZone(
        caregiverId: 'caregiver123',
        patientId: 'patient123',
        latitude: 37.7749,
        longitude: -122.4194,
        radius: 200,
        activeStatus: true,
      );

      expect(success, isTrue);
      expect(provider.currentSafeZone, equals(testSafeZone));
      verify(() => mockService.configureSafeZone(
            caregiverId: 'caregiver123',
            patientId: 'patient123',
            homeLatitude: 37.7749,
            homeLongitude: -122.4194,
            radius: 200,
            activeStatus: true,
          )).called(1);
    });

    test('toggleSimulatorMode handles active state configuration', () {
      expect(provider.isSimulatorMode, isFalse);
      
      provider.toggleSimulatorMode(true, defaultLat: 37.1, defaultLng: -122.1);
      
      expect(provider.isSimulatorMode, isTrue);
      expect(provider.mockLatitude, equals(37.1));
      expect(provider.mockLongitude, equals(-122.1));
    });
  });
}
