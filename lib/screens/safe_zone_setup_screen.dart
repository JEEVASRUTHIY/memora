import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/safe_zone_provider.dart';
import 'map_selection_screen.dart';

class SafeZoneSetupScreen extends StatefulWidget {
  final String patientId;

  const SafeZoneSetupScreen({super.key, required this.patientId});

  @override
  State<SafeZoneSetupScreen> createState() => _SafeZoneSetupScreenState();
}

class _SafeZoneSetupScreenState extends State<SafeZoneSetupScreen> {
  bool _initialized = false;
  bool _activeStatus = false;
  double _radius = 250.0;
  double _latitude = 37.7749;
  double _longitude = -122.4194;

  final List<double> _radiusOptions = [10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0];

  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(text: _latitude.toString());
    _lngController = TextEditingController(text: _longitude.toString());
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<SafeZoneProvider>(context, listen: false)
            .fetchSafeZone(widget.patientId)
            .then((_) {
          final config = Provider.of<SafeZoneProvider>(context, listen: false).safeZone;
          if (config != null) {
            setState(() {
              _activeStatus = config.activeStatus;
              _radius = _getClosestRadius(config.radius);
              _latitude = config.homeLatitude;
              _longitude = config.homeLongitude;
              _latController.text = _latitude.toString();
              _lngController.text = _longitude.toString();
            });
          }
        });
      });
    }
  }

  double _getClosestRadius(double val) {
    // Find closest option in _radiusOptions
    return _radiusOptions.reduce((a, b) => (val - a).abs() < (val - b).abs() ? a : b);
  }

  Future<void> _chooseOnMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectionScreen(
          initialCenter: LatLng(_latitude, _longitude),
          radius: _radius,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _latController.text = _latitude.toString();
        _lngController.text = _longitude.toString();
      });
    }
  }

  Future<void> _saveConfiguration() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<SafeZoneProvider>(context, listen: false);

    if (auth.userModel == null || !auth.userModel!.isCaregiver) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only caregivers can modify safe zones.')),
      );
      return;
    }

    final success = await provider.configureSafeZone(
      caregiverId: auth.userModel!.userId,
      patientId: widget.patientId,
      latitude: _latitude,
      longitude: _longitude,
      radius: _radius,
      activeStatus: _activeStatus,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Safe zone configuration saved!',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppTheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final provider = Provider.of<SafeZoneProvider>(context);
    final isPatient = auth.userModel?.isPatient ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Safe Zone Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: provider.isLoadingZone
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primary)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Configuration Status Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: (_activeStatus ? AppTheme.accent : AppTheme.textSecondary).withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _activeStatus ? Icons.gpp_good_rounded : Icons.gpp_maybe_rounded,
                                        color: _activeStatus ? AppTheme.accent : AppTheme.textSecondary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Safe Zone Status',
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          _activeStatus ? 'Currently Active' : 'Currently Inactive',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _activeStatus,
                                  onChanged: isPatient
                                      ? null
                                      : (val) {
                                          setState(() {
                                            _activeStatus = val;
                                          });
                                        },
                                  activeColor: AppTheme.accent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Configuration Details
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Safe Zone Boundary Configuration',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Divider(height: 24, color: Colors.white10),
                            
                            // Center Coordinates
                            Text(
                              'Geofence Center Point',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, color: AppTheme.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Lat: ${_latitude.toStringAsFixed(6)}\nLng: ${_longitude.toStringAsFixed(6)}',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 14,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (!isPatient)
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppTheme.surface,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.map_rounded, color: AppTheme.primary),
                                      onPressed: _chooseOnMap,
                                    ),
                                ],
                              ),
                            ),
                            if (!isPatient) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _latController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Manual Latitude',
                                        labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 11),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: AppTheme.primary),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        final numVal = double.tryParse(val);
                                        if (numVal != null) {
                                          setState(() {
                                            _latitude = numVal;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _lngController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Manual Longitude',
                                        labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 11),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: AppTheme.primary),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        final numVal = double.tryParse(val);
                                        if (numVal != null) {
                                          setState(() {
                                            _longitude = numVal;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Radius Display & Slider Selection
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Geofence Radius',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${_radius.round()} meters',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            isPatient
                                ? Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.background,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.radar_rounded, color: AppTheme.primary),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Static radius set to ${_radius.round()}m',
                                          style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      Slider(
                                        value: (_radiusOptions.indexOf(_radius) != -1
                                            ? _radiusOptions.indexOf(_radius)
                                            : 4).toDouble(),
                                        min: 0,
                                        max: (_radiusOptions.length - 1).toDouble(),
                                        divisions: _radiusOptions.length - 1,
                                        activeColor: AppTheme.primary,
                                        inactiveColor: Colors.white10,
                                        onChanged: (val) {
                                          setState(() {
                                            _radius = _radiusOptions[val.round()];
                                          });
                                        },
                                      ),
                                      // Custom labels
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: _radiusOptions.map((r) {
                                            final isActive = r == _radius;
                                            return Text(
                                              r >= 1000 ? '${(r / 1000).round()}km' : '${r.round()}m',
                                              style: GoogleFonts.outfit(
                                                fontSize: isActive ? 11 : 9,
                                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button (Caregiver Only)
                    if (!isPatient)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: !provider.isSavingZone ? AppTheme.primaryGradient : null,
                          color: provider.isSavingZone ? AppTheme.surface.withOpacity(0.5) : null,
                        ),
                        child: ElevatedButton(
                          onPressed: provider.isSavingZone ? null : _saveConfiguration,
                          child: provider.isSavingZone
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Save Configuration',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    
                    if (provider.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        provider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: AppTheme.error, fontSize: 13),
                      ),
                    ]
                  ],
                ),
              ),
      ),
    );
  }
}
