import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/location_log_model.dart';
import '../providers/safe_zone_provider.dart';

class LocationHistoryScreen extends StatefulWidget {
  final String patientId;

  const LocationHistoryScreen({super.key, required this.patientId});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  @override
  void initState() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SafeZoneProvider>(context, listen: false).loadLogs(widget.patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SafeZoneProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Location History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(SafeZoneProvider provider) {
    if (provider.isLoadingLogs && provider.logs.isEmpty) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primary)));
    }

    if (provider.logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_rounded, color: AppTheme.textSecondary, size: 64),
            const SizedBox(height: 16),
            Text(
              'No location history available',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Location updates will appear here once tracking starts.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: provider.logs.length + 1,
      itemBuilder: (context, index) {
        if (index == provider.logs.length) {
          // Bottom button / pagination state
          if (provider.isLoadingLogs) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primary))),
            );
          }
          if (provider.hasMoreLogs) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: TextButton.icon(
                key: const Key('loadMoreButton'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  provider.loadMoreLogs(widget.patientId);
                },
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                label: Text(
                  'Load More Logs',
                  style: GoogleFonts.outfit(color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final log = provider.logs[index];
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildLogCard(LocationLogModel log) {
    final isOutside = log.status == 'Outside';
    final statusColor = isOutside ? AppTheme.error : AppTheme.accent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Status dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Center details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.lastKnownLocation.isNotEmpty ? log.lastKnownLocation : (isOutside ? 'Outside safe zone' : 'Inside safe zone'),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${log.latitude.toStringAsFixed(5)}, Lng: ${log.longitude.toStringAsFixed(5)}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Right Date / Time
            if (log.timestamp != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    TimeOfDay.fromDateTime(log.timestamp!).format(context),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    '${log.timestamp!.day}/${log.timestamp!.month}',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
