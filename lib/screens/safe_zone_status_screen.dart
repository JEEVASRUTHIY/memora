import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/safe_zone_model.dart';
import '../models/location_log_model.dart';
import '../providers/auth_provider.dart';
import '../providers/safe_zone_provider.dart';
import '../services/user_service.dart';
import '../services/background_location_service.dart';
import 'safe_zone_setup_screen.dart';
import 'location_history_screen.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

class SafeZoneStatusScreen extends StatefulWidget {
  final String patientId;

  const SafeZoneStatusScreen({super.key, required this.patientId});

  @override
  State<SafeZoneStatusScreen> createState() => _SafeZoneStatusScreenState();
}

class _SafeZoneStatusScreenState extends State<SafeZoneStatusScreen> {
  final MapController _mapController = MapController();
  bool _isBackgroundRunning = false;
  bool _mapError = false;
  String _mapErrorMsg = '';
  StreamSubscription? _serviceSubscription;
  bool _isGpsPanelExpanded = false;

  // Controller fields for GPS Simulator input
  final _latController = TextEditingController(text: "37.7800");
  final _lngController = TextEditingController(text: "-122.4220");

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _setupBackgroundServiceListener();
    
    // Fetch initial values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final safeZoneProvider = Provider.of<SafeZoneProvider>(context, listen: false);
      safeZoneProvider.fetchSafeZone(widget.patientId);
      safeZoneProvider.loadLogs(widget.patientId);
      
      // Sync text controllers with simulator coordinate state
      _latController.text = safeZoneProvider.simulatedLatitude.toString();
      _lngController.text = safeZoneProvider.simulatedLongitude.toString();
    });
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _latController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _checkServiceStatus() async {
    final running = await FlutterBackgroundService().isRunning();
    if (mounted) {
      setState(() {
        _isBackgroundRunning = running;
      });
    }
  }

  void _setupBackgroundServiceListener() {
    // Listen for events from background service isolate
    _serviceSubscription = FlutterBackgroundService().on('locationUpdate').listen((event) {
      if (mounted && event != null) {
        // Trigger a reload of logs
        Provider.of<SafeZoneProvider>(context, listen: false).loadLogs(widget.patientId);
        _checkServiceStatus();
      }
    });
  }

  void _toggleBackgroundTracking(bool enable) async {
    if (enable) {
      // First verify permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are required to start background geofencing.')),
        );
        return;
      }

      await BackgroundLocationService.startService();
    } else {
      await BackgroundLocationService.stopService();
    }
    
    // Add a slight delay to allow service to start/stop before checking status
    await Future.delayed(const Duration(milliseconds: 500));
    _checkServiceStatus();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isPatient = auth.userModel?.isPatient ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPatient ? 'My Safe Zone' : 'Safe Zone Monitoring',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'View Location History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationHistoryScreen(patientId: widget.patientId),
                ),
              );
            },
          ),
          if (!isPatient)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configure Safe Zone',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SafeZoneSetupScreen(patientId: widget.patientId),
                  ),
                );
              },
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: isPatient ? _buildPatientUI(auth.userModel!) : _buildCaregiverUI(auth.userModel!),
      ),
    );
  }

  Widget _buildPatientUI(UserModel patient) {
    final safeZoneProvider = Provider.of<SafeZoneProvider>(context);
    final safeZone = safeZoneProvider.safeZone;
    final latestLog = safeZoneProvider.logs.isNotEmpty ? safeZoneProvider.logs.first : null;

    final isBreached = patient.isLinked && (latestLog?.status == 'Outside');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual Breach Indicator for Patient
          if (isBreached)
            _buildBreachAlertCard(latestLog),
          
          // Background service state toggle card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Background Safety Tracking',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isBackgroundRunning ? Icons.radar_rounded : Icons.radar_outlined,
                            color: _isBackgroundRunning ? AppTheme.accent : AppTheme.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isBackgroundRunning ? 'Tracking Active' : 'Tracking Suspended',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isBackgroundRunning ? AppTheme.accent : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isBackgroundRunning,
                        onChanged: _toggleBackgroundTracking,
                        activeColor: AppTheme.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'When active, your device will monitor your location in the background and notify your caregiver immediately if you exit the designated home safe zone.',
                    style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Safe Zone Info Card
          _buildSafeZoneInfoCard(safeZone, latestLog),
          const SizedBox(height: 20),

          // Collapsible Developer GPS Simulator Controls
          _buildGpsSimulatorBlock(safeZoneProvider),
        ],
      ),
    );
  }

  Widget _buildCaregiverUI(UserModel caregiver) {
    final userService = Provider.of<UserService>(context);
    final safeZoneProvider = Provider.of<SafeZoneProvider>(context);

    return StreamBuilder<UserModel?>(
      stream: userService.watchUserProfile(widget.patientId),
      builder: (context, patientSnapshot) {
        if (patientSnapshot.hasError) {
          return Center(child: Text('Error loading patient info: ${patientSnapshot.error}', style: const TextStyle(color: AppTheme.error)));
        }

        final patient = patientSnapshot.data;
        if (patient == null) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primary)));
        }

        return StreamBuilder<SafeZoneModel?>(
          stream: safeZoneProvider.repository.watchSafeZone(widget.patientId),
          builder: (context, zoneSnapshot) {
            final safeZone = zoneSnapshot.data;

            // Live updates info
            final isBreached = patient.isLinked && (patient.isPatient ? false : (patient.isLinked && (patient.linkedPatientId != null || patient.linkedCaregiverId != null))) || (patient.toJson()['isBreached'] == true);
            final double? patientLat = (patient.toJson()['lastKnownLatitude'] as num?)?.toDouble();
            final double? patientLng = (patient.toJson()['lastKnownLongitude'] as num?)?.toDouble();
            
            DateTime? lastTime;
            if (patient.toJson()['lastLocationTime'] != null) {
              final val = patient.toJson()['lastLocationTime'];
              if (val is Timestamp) {
                lastTime = val.toDate();
              } else if (val is String) {
                lastTime = DateTime.tryParse(val);
              }
            }

            double distance = 0.0;
            if (safeZone != null && patientLat != null && patientLng != null) {
              distance = _calculateDistance(
                safeZone.homeLatitude,
                safeZone.homeLongitude,
                patientLat,
                patientLng,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Live Alert Banner for Caregiver
                if (isBreached)
                  _buildCaregiverEmergencyBanner(patient, distance, safeZone?.radius ?? 200),
                
                // Map Area
                Expanded(
                  child: Stack(
                    children: [
                      _buildMap(safeZone, patientLat, patientLng, isBreached),
                      
                      // Floating Info Cards overlay
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Card(
                          color: AppTheme.surface.withOpacity(0.95),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Patient Live Location',
                                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                    ),
                                    _buildStatusBadge(isBreached),
                                  ],
                                ),
                                const Divider(height: 16, color: Colors.white10),
                                _buildInfoItem(
                                  Icons.person_pin_circle_outlined, 
                                  'Patient', 
                                  patient.name
                                ),
                                if (safeZone != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoItem(
                                    Icons.radar_rounded, 
                                    'Boundary Radius', 
                                    '${safeZone.radius.round()} meters'
                                  ),
                                  if (patientLat != null && patientLng != null) ...[
                                    const SizedBox(height: 8),
                                    _buildInfoItem(
                                      Icons.social_distance_rounded, 
                                      'Current Distance', 
                                      '${distance.round()} meters (${distance > safeZone.radius ? "Outside" : "Inside"})'
                                    ),
                                  ],
                                ],
                                if (lastTime != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoItem(
                                    Icons.access_time_rounded, 
                                    'Latest Location Update', 
                                    TimeOfDay.fromDateTime(lastTime).format(context)
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(bool isBreached) {
    final color = isBreached ? AppTheme.error : AppTheme.accent;
    final text = isBreached ? 'ACTIVE BREACH' : 'SAFE INSIDE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Expanded(
          child: Text(
            val,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMap(SafeZoneModel? safeZone, double? patientLat, double? patientLng, bool isBreached) {
    if (_mapError) {
      return _buildMapErrorWidget();
    }

    final LatLng center = safeZone != null 
        ? LatLng(safeZone.homeLatitude, safeZone.homeLongitude)
        : const LatLng(37.7749, -122.4194);

    try {
      return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: patientLat != null && patientLng != null ? LatLng(patientLat, patientLng) : center,
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.jeevasruthiy.memora',
          ),
          if (safeZone != null)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: center,
                  radius: safeZone.radius,
                  useRadiusInMeter: true,
                  color: (isBreached ? AppTheme.error : AppTheme.accent).withOpacity(0.12),
                  borderColor: isBreached ? AppTheme.error : AppTheme.accent,
                  borderStrokeWidth: 2.0,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (safeZone != null)
                Marker(
                  point: center,
                  width: 60.0,
                  height: 60.0,
                  child: const Icon(
                    Icons.home_rounded,
                    color: Colors.blue,
                    size: 32.0,
                  ),
                ),
              if (patientLat != null && patientLng != null)
                Marker(
                  point: LatLng(patientLat, patientLng),
                  width: 60.0,
                  height: 60.0,
                  child: Icon(
                    Icons.person_pin_circle_rounded,
                    color: isBreached ? Colors.red : Colors.green,
                    size: 40.0,
                  ),
                ),
            ],
          ),
        ],
      );
    } catch (e) {
      setState(() {
        _mapError = true;
        _mapErrorMsg = e.toString();
      });
      return _buildMapErrorWidget();
    }
  }

  Widget _buildMapErrorWidget() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_rounded, color: AppTheme.error, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load Map',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaregiverEmergencyBanner(UserModel patient, double distance, double radius) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppTheme.error,
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRITICAL ALARM: PATIENT BREACHED!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                Text(
                  '${patient.name} has exited the safe zone by ${(distance - radius).round()} meters.',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreachAlertCard(LocationLogModel? latestLog) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAFE ZONE BREACH ACTIVE',
                  style: GoogleFonts.outfit(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You are currently outside your configured home safe zone. Please return immediately to assure your caregiver of your safety.',
                  style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeZoneInfoCard(SafeZoneModel? safeZone, LocationLogModel? latestLog) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Geofence Limits',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const Divider(height: 24, color: Colors.white10),
            if (safeZone == null)
              Text(
                'No safe zone boundaries have been configured for your account yet. Your caregiver can set this up from their dashboard.',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 13),
              )
            else ...[
              _buildInfoRowItem(Icons.radar_rounded, 'Designated Radius', '${safeZone.radius.round()} meters'),
              const SizedBox(height: 12),
              _buildInfoRowItem(
                Icons.location_searching_rounded, 
                'Home Center Coordinate', 
                '${safeZone.homeLatitude.toStringAsFixed(5)}, ${safeZone.homeLongitude.toStringAsFixed(5)}'
              ),
              if (latestLog != null) ...[
                const SizedBox(height: 12),
                _buildInfoRowItem(
                  Icons.gps_fixed_rounded, 
                  'Last Tracked Coordinate', 
                  '${latestLog.latitude.toStringAsFixed(5)}, ${latestLog.longitude.toStringAsFixed(5)}'
                ),
                const SizedBox(height: 12),
                _buildInfoRowItem(
                  Icons.schedule_rounded, 
                  'Last Tracking Check', 
                  latestLog.timestamp != null ? TimeOfDay.fromDateTime(latestLog.timestamp!).format(context) : 'Unknown'
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 11)),
            Text(
              value,
              style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGpsSimulatorBlock(SafeZoneProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isGpsPanelExpanded = !_isGpsPanelExpanded;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Developer GPS Location Simulator',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                Icon(
                  _isGpsPanelExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ),
        if (_isGpsPanelExpanded) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.blue.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Enable Coordinate Overrides',
                        style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      Switch(
                        value: provider.isSimulatorEnabled,
                        onChanged: (val) {
                          provider.toggleGpsSimulator(val);
                        },
                        activeColor: Colors.blueAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Mock Latitude',
                      prefixIcon: Icon(Icons.map_rounded, color: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Mock Longitude',
                      prefixIcon: Icon(Icons.explore_rounded, color: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: !provider.isSimulatorEnabled 
                              ? null 
                              : () async {
                                  final lat = double.tryParse(_latController.text.trim());
                                  final lng = double.tryParse(_lngController.text.trim());
                                  if (lat != null && lng != null) {
                                    provider.setSimulatedCoordinates(lat, lng);
                                    await provider.sendLocationUpdate(
                                      patientId: widget.patientId,
                                      latitude: lat,
                                      longitude: lng,
                                    );
                                  }
                                },
                          child: Text(
                            'Mock Coordinates',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrangeAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final lat = double.tryParse(_latController.text.trim()) ?? 38.0;
                            final lng = double.tryParse(_lngController.text.trim()) ?? -122.0;
                            provider.setSimulatedCoordinates(lat, lng);
                            await provider.simulateBreach(widget.patientId, lat, lng);
                          },
                          child: Text(
                            'Force Breach event',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
