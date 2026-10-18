import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/app_config.dart';

/// Developer tools screen — reachable by tapping the version text 5 times.
/// Shows location debug info, GPS accuracy, and test buttons.
/// Disabled if AppConfig.devToolsEnabled is false.
class DevToolsScreen extends StatelessWidget {
  const DevToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.devToolsEnabled) {
      return const Scaffold(
        body: Center(child: Text('Developer tools are disabled.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Location readings and test actions will be available in a later test build.'),
          _InfoTile(label: 'Distance from zone centre', value: '—'),
          _InfoTile(label: 'GPS accuracy', value: '—'),
          _InfoTile(label: 'Inside safe zone', value: '—'),
          _InfoTile(label: 'Last location upload', value: '—'),
          SizedBox(height: 24),
          _ActionButton(label: 'Create test reminder in 1 minute'),
          SizedBox(height: 12),
          _ActionButton(label: 'Send test alert'),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.black54)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  const _ActionButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: null,
      child: Text(label),
    );
  }
}
