import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_adapter.dart';
import 'classic_adapter.dart';
import 'demo_device.dart';

enum ScanMode { none, ble, classic }

class BluetoothManager extends ChangeNotifier {
  final BleAdapter bleAdapter = BleAdapter();
  final ClassicAdapter classicAdapter = ClassicAdapter();

  ScanMode mode = ScanMode.none;
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _bleOn = false;
  bool get bleOn => _bleOn;
  bool _classicOn = false;
  bool get classicOn => _classicOn;

  final Map<String, BleDeviceInfo> bleDevices = {};
  final Map<String, ClassicDeviceInfo> classicDevices = {};

  StreamSubscription? _bleSub;
  StreamSubscription? _classicSub;
  StreamSubscription? _bleAdapterStateSub;

  BluetoothManager() {
    _initAdapterStateListeners();
  }

  void _initAdapterStateListeners() {
    _bleAdapterStateSub = bleAdapter.adapterState.listen((state) {
      final newBleOn = state == BluetoothAdapterState.on;
      if (_bleOn != newBleOn) {
        _bleOn = newBleOn;
        notifyListeners();
      }
    });

    _checkClassicStatus();
  }

  Future<void> _checkClassicStatus() async {
    try {
      final newClassicOn = await classicAdapter.isEnabled();
      if (_classicOn != newClassicOn) {
        _classicOn = newClassicOn;
        notifyListeners();
      }
    } catch (e) {
      if (_classicOn) {
        _classicOn = false;
        notifyListeners();
      }
    }
    if (!_isDisposed) {
      Future.delayed(const Duration(seconds: 5), _checkClassicStatus);
    }
  }

  void startBleScan() {
    if (!_bleOn) {
      throw StateError("BLE adapter is off.");
    }
    stopAll();

    mode = ScanMode.ble;
    _isScanning = true;
    bleDevices.clear();

    bleDevices[DemoDeviceIds.bleId] = BleDeviceInfo(
      id: DemoDeviceIds.bleId,
      name: "${DemoDeviceIds.name} • BLE (Demo)",
      rssi: -42,
    );
    notifyListeners();

    _bleSub = bleAdapter.stream.listen((d) {
      bleDevices[d.id] = d;
      notifyListeners();
    }, onDone: () {
      _isScanning = false;
      notifyListeners();
    }, onError: (e) {
      _isScanning = false;
      notifyListeners();
    });

    try {
      bleAdapter.startScan();
    } catch (e) {
      _isScanning = false;
      notifyListeners();
      rethrow;
    }
  }

  void startClassicDiscovery() {
    if (!_classicOn) {
      throw StateError("Classic Bluetooth adapter is off.");
    }
    stopAll();

    mode = ScanMode.classic;
    _isScanning = true;
    classicDevices.clear();

    // Add Demo device immediately for testing simplicity
    classicDevices[DemoDeviceIds.classicAddr] = ClassicDeviceInfo(
      address: DemoDeviceIds.classicAddr,
      name: "${DemoDeviceIds.name} • Classic (Demo)",
      bonded: false,
    );
    notifyListeners();

    try {
      _classicSub = classicAdapter.discover().listen((d) {
        classicDevices[d.address] = d;
        notifyListeners();
      }, onDone: () {
        _isScanning = false;
        notifyListeners();
      }, onError: (e) {
        _isScanning = false;
        notifyListeners();
      });
    } catch (e) {
      _isScanning = false;
      notifyListeners();
      rethrow;
    }
  }

  void stopAll() {
    _bleSub?.cancel();
    _classicSub?.cancel();
    bleAdapter.stop();
    classicAdapter.stop();
    _isScanning = false;
    mode = ScanMode.none;
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _bleAdapterStateSub?.cancel();
    stopAll();
    super.dispose();
  }
}