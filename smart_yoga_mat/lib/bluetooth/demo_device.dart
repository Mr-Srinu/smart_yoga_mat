import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'connection_wrapper.dart';

/// Single source of truth for the demo device id/name for both BLE & Classic.
class DemoDeviceIds {
  static const bleId = "DE:MO:BL:EE:SP:32";
  static const classicAddr = "00:11:22:33:44:55";
  static const name = "Smart Yoga Mat (Demo)";
}

/// Emits fake pose/sensor data every 800ms. Accepts writes (logs them).
class DemoBleLink {
  final _ctrl = StreamController<List<int>>.broadcast();
  // New: Connection State stream for wrapper auto-reconnect test
  final _stateCtrl = StreamController<ConnState>.broadcast();
  Stream<ConnState> get connectionStateStream => _stateCtrl.stream;

  Timer? _timer;
  bool _connected = false;

  Stream<List<int>> get notifyStream => _ctrl.stream;

  Future<void> connect() async {
    _connected = true;
    _stateCtrl.add(ConnState.ready); // Indicate immediate success
    _timer?.cancel();
    int t = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!_connected) return;
      final sample = {
        "pose": ["mountain", "plank", "cobra", "down_dog"][t % 4],
        "pressure": (500 + (t * 17) % 300),
        "stability": (70 + (t * 3) % 30),
        "ts": DateTime.now().toIso8601String(),
      };
      t++;
      _ctrl.add(utf8.encode(jsonEncode(sample)));
    });
  }

  Future<void> write(List<int> data) async {
    // echo back acks for UI proof
    final txt = utf8.decode(data, allowMalformed: true);
    final ack = {"ack": txt.trim(), "ok": true, "ts": DateTime.now().toIso8601String()};
    _ctrl.add(utf8.encode(jsonEncode(ack)));
  }

  Future<void> disconnect() async {
    _connected = false;
    _timer?.cancel();
    _stateCtrl.add(ConnState.disconnected); // Indicate disconnection
  }

  void dispose() {
    _timer?.cancel();
    _ctrl.close();
    _stateCtrl.close();
  }
}

/// Simple text stream demo for Classic SPP
class DemoClassicLink {
  final _ctrl = StreamController<List<int>>.broadcast();
  // New: Connection State stream for wrapper auto-reconnect test
  final _stateCtrl = StreamController<ConnState>.broadcast();
  Stream<ConnState> get connectionStateStream => _stateCtrl.stream;

  Timer? _timer;
  bool _connected = false;

  Stream<List<int>> get input => _ctrl.stream;

  Future<void> connect() async {
    _connected = true;
    _stateCtrl.add(ConnState.ready); // Indicate immediate success
    _timer?.cancel();
    int i = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_connected) return;
      final line = "demo-stream-$i pressure=${520 + (i * 13) % 200}\n";
      i++;
      // Corrected: Removed unnecessary 'as List<int>' cast
      _ctrl.add(Uint8List.fromList(utf8.encode(line)));
    });
  }

  Future<void> write(List<int> data) async {
    final txt = utf8.decode(data, allowMalformed: true).trim();
    final echo = "demo-ack:$txt\n";
    _ctrl.add(Uint8List.fromList(utf8.encode(echo)));
  }

  Future<void> disconnect() async {
    _connected = false;
    _timer?.cancel();
    _stateCtrl.add(ConnState.disconnected); // Indicate disconnection
  }

  void dispose() {
    _timer?.cancel();
    _ctrl.close();
    _stateCtrl.close();
  }
}