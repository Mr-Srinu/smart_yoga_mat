import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static Future<bool> ensure() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  static Future<bool> checkOnly() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }
}

class PermissionGate extends StatefulWidget {
  final Widget child;
  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  Future<void> _ask() async {
    final ok = await AppPermissions.ensure();
    if (!mounted) return;
    setState(() => _ready = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                const Text('Requesting Bluetooth permissions…'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _ask,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Open app settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
