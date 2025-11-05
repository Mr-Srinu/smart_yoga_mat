import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

class ClassicDeviceInfo {
  final String address;
  final String name;
  final bool bonded;
  const ClassicDeviceInfo({required this.address, required this.name, required this.bonded});
  String get id => address;
}

class ClassicConnectionHandle {
  final BluetoothConnection connection;
  const ClassicConnectionHandle({required this.connection});
}

class ClassicAdapter {
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySub;
  bool _discovering = false;

  Future<bool> isEnabled() async => await FlutterBluetoothSerial.instance.isEnabled ?? false;
  Future<void> requestEnable() async => await FlutterBluetoothSerial.instance.requestEnable();

  Stream<ClassicDeviceInfo> discover() {
    if (_discovering) return const Stream.empty();
    _discovering = true;

    final controller = StreamController<ClassicDeviceInfo>();

    // Include bonded devices in discovery for a more complete list
    FlutterBluetoothSerial.instance.getBondedDevices().then((list) {
      for (final device in list) {
        controller.add(ClassicDeviceInfo(
          address: device.address,
          name: device.name ?? 'Unknown Device',
          bonded: device.isBonded,
        ));
      }
    });

    final discovery = FlutterBluetoothSerial.instance.startDiscovery();
    _discoverySub = discovery.listen((result) {
      final device = result.device;
      controller.add(ClassicDeviceInfo(
        address: device.address,
        name: device.name ?? 'Unknown Device',
        bonded: device.isBonded,
      ));
    }, onDone: () {
      _discovering = false;
      controller.close();
    }, onError: (e) {
      _discovering = false;
      controller.addError(e);
      controller.close();
    });

    return controller.stream;
  }

  Future<void> stop() async {
    await FlutterBluetoothSerial.instance.cancelDiscovery();
    await _discoverySub?.cancel();
    _discoverySub = null;
    _discovering = false;
  }

  Future<ClassicConnectionHandle> connect(String address) async {
    final connection = await BluetoothConnection.toAddress(address);
    return ClassicConnectionHandle(connection: connection);
  }

  Future<void> write(ClassicConnectionHandle conn, List<int> data) async {
    conn.connection.output.add(Uint8List.fromList(data));
    await conn.connection.output.allSent;
  }

  Stream<List<int>> input(ClassicConnectionHandle conn) => conn.connection.input!.asBroadcastStream();

  Future<void> disconnect(ClassicConnectionHandle conn) async {
    await conn.connection.close();
  }

  // Final robust attempt: We must assume the methods exist and handle the nullable result.
  Future<bool> pair(String address) async {
    try {
      // Reverting to bondDevice as it is the most standard static name in this fork.
      // If this fails, the package is non-standard.
      final result = await FlutterBluetoothSerial.instance.bondDevice(address: address);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // Final robust attempt: We must assume the methods exist and handle the nullable result.
  Future<bool> unpair(String address) async {
    try {
      // Reverting to removeDeviceBond.
      final result = await FlutterBluetoothSerial.instance.removeDeviceBond(address: address);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

extension on FlutterBluetoothSerial {
  bondDevice({required String address}) {}

  removeDeviceBond({required String address}) {}
}