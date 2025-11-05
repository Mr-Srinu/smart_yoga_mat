import 'package:flutter/material.dart';
import '../bluetooth/ble_adapter.dart';
import '../bluetooth/classic_adapter.dart';

class DeviceDetailScreen extends StatelessWidget {
  final BleDeviceInfo? bleDevice;
  final ClassicDeviceInfo? classicDevice;

  const DeviceDetailScreen._({this.bleDevice, this.classicDevice, super.key});

  factory DeviceDetailScreen.ble({required BleDeviceInfo device}) =>
      DeviceDetailScreen._(bleDevice: device);

  factory DeviceDetailScreen.classic({required ClassicDeviceInfo device}) =>
      DeviceDetailScreen._(classicDevice: device);

  @override
  Widget build(BuildContext context) {
    // Determine title: Use BLE name if available, otherwise Classic name (classicDevice! is safe due to factories)
    final title = bleDevice?.name ?? classicDevice!.name;

    // Determine body: Show BLE details (ID, RSSI) or Classic details (Address, Bonded)
    final body = bleDevice != null
        ? 'Protocol: BLE\nID: ${bleDevice!.id}\nRSSI: ${bleDevice!.rssi} dBm'
        : 'Protocol: Classic SPP\nAddress: ${classicDevice!.address}\nBonded: ${classicDevice!.bonded ? "Yes" : "No"}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
            alignment: Alignment.topLeft,
            child: Text(
                body,
                style: const TextStyle(fontSize: 16, height: 1.5)
            )
        ),
      ),
    );
  }
}