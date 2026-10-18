import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memora/core/app_config.dart';
import 'package:memora/core/router/app_routes.dart';

/// Deliberately unobtrusive entry, available in release test builds.
class DeveloperEntry extends StatefulWidget {
  const DeveloperEntry({super.key});
  @override
  State<DeveloperEntry> createState() => _DeveloperEntryState();
}

class _DeveloperEntryState extends State<DeveloperEntry> {
  int _taps = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: !AppConfig.devToolsEnabled ? null : () {
      if (++_taps == 5) {
        _taps = 0;
        context.push(AppRoutes.devTools);
      }
    },
    child: const Text('Memora 1.0.0'),
  );
}
