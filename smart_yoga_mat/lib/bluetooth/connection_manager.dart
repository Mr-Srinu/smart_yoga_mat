import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// FIX 2: Use 'as' to prefix the Classic Bluetooth classes and avoid the BluetoothDevice clash
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart' as classic_bt;

import 'ble_adapter.dart';
import 'classic_adapter.dart';
import 'connection_wrapper.dart';
import 'demo_device.dart';

class ConnectionManager {
  final BleAdapter ble;
  final ClassicAdapter classic;

  // demo links kept here so they survive screen rebuilds
  final DemoBleLink _demoBle = DemoBleLink();
  final DemoClassicLink _demoClassic = DemoClassicLink();

  ConnectionManager({required this.ble, required this.classic});

  Future<ConnectionWrapper> createBleWrapper(String id) async {
    // DEMO route
    if (id == DemoDeviceIds.bleId) {
      await _demoBle.connect();
      return ConnectionWrapper(
        type: ConnType.ble,
        deviceId: id,
        startScan: () async {},
        connect: (_) async => _demoBle.connect(),
        discover: () async {},
        ready: () async {},
        disconnect: () async => _demoBle.disconnect(),
        write: (data) async => _demoBle.write(data),
        dataStream: _demoBle.notifyStream,
        connectionStateStream: _demoBle.connectionStateStream.asBroadcastStream(),
      );
    }

    // REAL BLE route
    final device = BluetoothDevice.fromId(id);
    await device.connect(autoConnect: false, license: License.free, timeout: const Duration(seconds: 12));
    final services = await device.discoverServices();

    BluetoothCharacteristic? notifyChar;
    BluetoothCharacteristic? writeChar;

    for (final s in services) {
      for (final c in s.characteristics) {
        if (notifyChar == null && c.properties.notify) notifyChar = c;
        if (writeChar == null && (c.properties.write || c.properties.writeWithoutResponse)) writeChar = c;
      }
    }

    Stream<List<int>>? notifyStream;
    if (notifyChar != null) {
      await notifyChar.setNotifyValue(true);
      notifyStream = notifyChar.lastValueStream;
    }

    // Real BLE connection state stream
    final Stream<ConnState> connStateStream = device.connectionState.map((s) {
      if (s == BluetoothConnectionState.connected) return ConnState.ready;
      if (s == BluetoothConnectionState.disconnected) return ConnState.disconnected;
      return ConnState.connecting;
    });

    return ConnectionWrapper(
      type: ConnType.ble,
      deviceId: id,
      startScan: () async => ble.startScan(),
      connect: (_) async => device.connect(autoConnect: false, license: License.free, timeout: const Duration(seconds: 12)),
      discover: () async => device.discoverServices(),
      ready: () async { /* Optional: read initial state, etc. */ },
      disconnect: () async => device.disconnect(),
      write: (data) async {
        if (writeChar != null) await ble.write(writeChar, data, withoutResponse: !writeChar.properties.write);
      },
      dataStream: notifyStream,
      connectionStateStream: connStateStream,
    );
  }

  Future<ConnectionWrapper> createClassicWrapper(String address) async {
    // DEMO route
    if (address == DemoDeviceIds.classicAddr) {
      await _demoClassic.connect();
      return ConnectionWrapper(
        type: ConnType.classic,
        deviceId: address,
        startScan: () async {},
        connect: (_) async => _demoClassic.connect(),
        discover: () async {},
        ready: () async {},
        disconnect: () async => _demoClassic.disconnect(),
        write: (data) async => _demoClassic.write(data),
        dataStream: _demoClassic.input,
        connectionStateStream: _demoClassic.connectionStateStream.asBroadcastStream(),
      );
    }

    // REAL Classic SPP route
    ClassicConnectionHandle? conn;
    StreamSubscription? _dataSub;
    final _dataController = StreamController<List<int>>.broadcast();
    final _stateController = StreamController<ConnState>.broadcast();

    // Connection action: This is the function called by the wrapper for connect/retry.
    Future<void> connectClassic(String addr) async {
      // 1. Clean up previous attempt
      await _dataSub?.cancel();
      if (conn != null) {
        try { await classic.disconnect(conn!); } catch (_) {}
      }

      // 2. Establish new connection (throws on failure, caught by wrapper)
      conn = await classic.connect(addr);

      // 3. Update state stream (manually map the initial success)
      _stateController.add(ConnState.ready);

      // 4. FIX 1: The correct state stream method is elusive or unstable.
      // Instead, we rely on the data stream's completion (onDone/onError)
      // to signal a disconnection to the wrapper.
      // We explicitly emit a DISCONNECTED state when the data stream completes.
      _dataSub = classic.input(conn!).listen(
        _dataController.add,
        onError: (e) {
          _dataController.addError(e);
          _stateController.add(ConnState.disconnected); // Signal error/disconnection
        },
        onDone: () {
          _stateController.add(ConnState.disconnected); // Signal clean disconnection
        },
      );
    }

    // The write action uses the current handle
    Future<void> writeClassic(List<int> data) async {
      if (conn != null) {
        await classic.write(conn!, data);
      } else {
        throw StateError("Classic device not connected. Cannot write.");
      }
    }

    // The disconnect action uses the current handle
    Future<void> disconnectClassic() async {
      await _dataSub?.cancel();
      if (conn != null) {
        await classic.disconnect(conn!);
        conn = null;
      }
      _stateController.add(ConnState.disconnected);
    }

    return ConnectionWrapper(
      type: ConnType.classic,
      deviceId: address,
      startScan: () async => classic.discover().drain(),
      connect: connectClassic,
      discover: () async {},
      ready: () async {},
      disconnect: disconnectClassic,
      write: writeClassic,

      // Data stream is the local controller
      dataStream: _dataController.stream,

      // Connection State stream is the local controller that tracks connect/disconnect
      connectionStateStream: _stateController.stream.asBroadcastStream(),
    );
  }
}