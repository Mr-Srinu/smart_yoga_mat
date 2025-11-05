import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/device_list.dart';
import 'utils/permissions.dart';
import 'bluetooth/bluetooth_manager.dart';

void main() {
  runApp(const BluetoothPrototypeApp());
}

class BluetoothPrototypeApp extends StatelessWidget {
  const BluetoothPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => BluetoothManager())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Yoga Mat',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
        ),
        home: const PermissionGate(child: DeviceListScreen()),
      ),
    );
  }
}
