import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../theme/app_theme.dart';

class MapSelectionScreen extends StatefulWidget {
  final LatLng initialCenter;
  final double radius;

  const MapSelectionScreen({
    super.key,
    required this.initialCenter,
    required this.radius,
  });

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  late LatLng _selectedCenter;
  final MapController _mapController = MapController();
  bool _hasError = false;
  String _errorMsg = '';

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selectedCenter = widget.initialCenter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final locations = await geo.locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newCenter = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _selectedCenter = newCenter;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found location: Lat: ${newCenter.latitude.toStringAsFixed(6)}, Lng: ${newCenter.longitude.toStringAsFixed(6)}'),
              backgroundColor: AppTheme.accent,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        _mapController.move(newCenter, 15);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address not found. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: Location not found or service unavailable.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _handleMapError(dynamic error) {
    setState(() {
      _hasError = true;
      _errorMsg = error.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorFallback();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Location',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Google Map with Try/Catch protection
          tryMapWidget(),
          
          // Search overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: AppTheme.surface.withOpacity(0.95),
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search location...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          border: InputBorder.none,
                          icon: const Icon(Icons.search, color: AppTheme.primary),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    if (_isSearching)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                        onPressed: _performSearch,
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // Selection Card overlay
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Card(
              color: AppTheme.surface.withOpacity(0.95),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Safe Zone Center',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Drag the marker on the map to set the center coordinates for the safe zone.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Latitude: ${_selectedCenter.latitude.toStringAsFixed(6)}\nLongitude: ${_selectedCenter.longitude.toStringAsFixed(6)}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(context, _selectedCenter);
                      },
                      child: Text(
                        'Confirm Selection',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tryMapWidget() {
    try {
      return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _selectedCenter,
          initialZoom: 15.0,
          onTap: (tapPosition, point) {
            setState(() {
              _selectedCenter = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.jeevasruthiy.memora',
          ),
          CircleLayer(
            circles: [
              CircleMarker(
                point: _selectedCenter,
                radius: widget.radius,
                useRadiusInMeter: true,
                color: AppTheme.primary.withOpacity(0.15),
                borderColor: AppTheme.primary,
                borderStrokeWidth: 2.0,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _selectedCenter,
                width: 80.0,
                height: 80.0,
                child: const Icon(
                  Icons.location_on,
                  size: 40.0,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ],
      );
    } catch (e) {
      _hasError = true;
      _errorMsg = e.toString();
      return _buildErrorFallback();
    }
  }

  Widget _buildErrorFallback() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Location',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
      ),
      body: Container(
        color: AppTheme.background,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.map_outlined,
                color: AppTheme.error,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Map Loading Failed',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We are unable to load OpenStreetMap at this time. Please check your network connection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                label: Text(
                  'Go Back',
                  style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
