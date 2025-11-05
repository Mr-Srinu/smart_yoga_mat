import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceInfo {
  final String id;
  final String name;
  final int rssi;
  const BleDeviceInfo({required this.id, required this.name, required this.rssi});
}

class BleGattHandle {
  final BluetoothDevice device;
  final List<BluetoothService> services;
  const BleGattHandle({required this.device, required this.services});
}

class BleAdapter {
  final _controller = StreamController<BleDeviceInfo>.broadcast();
  Stream<BleDeviceInfo> get stream => _controller.stream;

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;

  Stream<BluetoothAdapterState> get adapterState => FlutterBluePlus.adapterState;

  Future<bool> isOn() async =>
      (await FlutterBluePlus.adapterState.first) == BluetoothAdapterState.on;

  Future<void> requestEnable() async {
    await FlutterBluePlus.turnOn();
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 8)}) async {
    if (_scanning) return;
    if (!await isOn()) throw StateError('BLE is OFF');
    _scanning = true;

    await FlutterBluePlus.stopScan();
    FlutterBluePlus.startScan(timeout: timeout);

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final d = r.device;
        _controller.add(BleDeviceInfo(
          id: d.remoteId.str,
          name: d.platformName.isNotEmpty ? d.platformName : 'Unknown',
          rssi: r.rssi,
        ));
      }
    }, onDone: () => _scanning = false, onError: (_) => _scanning = false);
  }

  Future<void> stop() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    _scanning = false;
  }

  Future<BluetoothDevice> connect(String id) async {
    final device = BluetoothDevice.fromId(id);
    await device.connect(
      autoConnect: false,
      license: License.free,
      timeout: const Duration(seconds: 12),
    );
    return device;
  }

  Future<BleGattHandle> discoverAll(BluetoothDevice device) async {
    final services = await device.discoverServices();
    return BleGattHandle(device: device, services: services);
  }

  Future<void> write(BluetoothCharacteristic c, List<int> data,
      {bool withoutResponse = true}) async {
    await c.write(Uint8List.fromList(data), withoutResponse: withoutResponse);
  }

  Future<List<int>> read(BluetoothCharacteristic c) async => await c.read();

  Future<Stream<List<int>>> enableNotify(BluetoothCharacteristic c) async {
    await c.setNotifyValue(true);
    return c.lastValueStream;
  }

  Future<void> disconnect(BluetoothDevice device) async => device.disconnect();

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}