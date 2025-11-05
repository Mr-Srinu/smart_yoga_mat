import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_yoga_mat/ui/widgets/status_banter.dart';
import '../bluetooth/ble_adapter.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../bluetooth/connection_manager.dart';
import '../bluetooth/connection_wrapper.dart';

// Renamed the class to BleConnectConsole to match the previous response's usage
class BleConnectConsole extends StatefulWidget {
  final BleDeviceInfo device;
  const BleConnectConsole({super.key, required this.device});
  @override
  State<BleConnectConsole> createState() => _BleConnectConsoleState();
}

class _BleConnectConsoleState extends State<BleConnectConsole> {
  ConnectionWrapper? _wrapper;
  final List<String> _log = [];
  final TextEditingController _controller = TextEditingController();
  ConnState _state = ConnState.disconnected;
  StreamSubscription? _logSub;
  StreamSubscription? _dataSub;

  bool _isBusy = true; // Use a dedicated busy state for initial setup

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  Future<void> _initConnection() async {
    final mgr = context.read<BluetoothManager>();

    // Step 1: Initialize ConnectionManager
    final connectionMgr = ConnectionManager(
      ble: mgr.bleAdapter,
      classic: mgr.classicAdapter, // Requires ClassicAdapter instance
    );

    try {
      // Step 2: Create the ConnectionWrapper (which contains the complex connection logic)
      _wrapper = await connectionMgr.createBleWrapper(widget.device.id);

      // Step 3: Subscribe to the wrapper's state machine events (CRITICAL for robustness)
      _logSub = _wrapper!.events.listen((event) {
        if (!mounted) return;
        setState(() {
          _state = event.state;
          // Log state changes and wrapper messages
          _pushLog('STATE: ${event.state.name.toUpperCase()}');
          if (event.message != null) _pushLog(' • ${event.message!}');
          _isBusy = event.state == ConnState.connecting; // Update busy based on wrapper state
        });
      });

      // Step 4: Subscribe to the incoming data stream
      _dataSub = _wrapper!.dataStream?.listen((data) {
        if (!mounted) return;
        // Attempt to decode as JSON for pretty printing (Demo device is JSON)
        try {
          final jsonStr = utf8.decode(data, allowMalformed: true);
          final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(jsonStr));
          _pushLog('<< DATA: $pretty');
        } catch (_) {
          // Fallback to raw hex
          final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          _pushLog('<< RAW: 0x[$hex]');
        }
      });

      // Step 5: Start the connection process (which includes scanning, connecting, and retries)
      await _wrapper!.start(widget.device.id);

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = ConnState.error;
        _pushLog('FATAL SETUP ERROR: $e');
        _isBusy = false;
      });
    }
  }

  String _fmt(List<int> bytes) {
    String asText;
    try {
      asText = utf8.decode(bytes);
    } catch (_) {
      asText = '';
    }
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    return '(${bytes.length}b) "$asText" | 0x[$hex]';
  }

  void _pushLog(String s) {
    setState(() => _log.insert(0, '[${TimeOfDay.now().format(context)}] $s'));
  }

  Future<void> _sendData() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _wrapper == null || _state != ConnState.ready) return;

    final data = utf8.encode(text);
    _controller.clear();

    _pushLog('>> WRITE: $text');
    try {
      await _wrapper!.send(data);
      _pushLog('   [ACK] Write successful');
    } catch (e) {
      _pushLog('   [ERR] Write failed: $e');
      // The wrapper should handle auto-reconnect after transient failure
    }
  }

  void _retryConnection() {
    _pushLog('--- Manual Retry Initiated ---');
    if (_wrapper != null) {
      _wrapper!.start(widget.device.id);
    } else {
      _initConnection(); // Re-initialize if wrapper setup failed
    }
  }

  @override
  void dispose() {
    _wrapper?.dispose();
    _logSub?.cancel();
    _dataSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _state == ConnState.ready;
    final isError = _state == ConnState.error || _state == ConnState.disconnected;
    final isLoading = _isBusy || _state == ConnState.connecting;

    final statusText = isReady ? 'Connected: Streaming Data'
        : isLoading ? 'Connecting/Retrying...'
        : isError ? 'Error/Disconnected: Retry Connection'
        : 'Disconnected';
    final statusOk = isReady || isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.device.name} (BLE)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _wrapper?.dispose();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // Connection Status Banner managed by the Wrapper State
          StatusBanner(
            ok: statusOk,
            okText: statusText,
            badText: statusText,
            onRetry: _retryConnection,
          ),
          const SizedBox(height: 12),

          // Action Buttons (Read functionality not directly supported by the simplified wrapper design,
          // but added back for completeness, only usable when connected)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: isReady,
                    decoration: const InputDecoration(
                      labelText: 'Write text',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: isReady ? _sendData : null, child: const Text('Send')),
                const SizedBox(width: 8),
                // NOTE: This Read button is for synchronous read requests, which should be
                // implemented directly in the BleAdapter if required by the actual yoga mat device.
                // OutlinedButton(onPressed: isReady ? _read : null, child: const Text('Read')),
              ],
            ),
          ),

          // Data Log Console
          Expanded(
            child: ListView.separated(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Text(
                  _log[i],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _log[i].contains('FATAL') || _log[i].contains('[ERR]')
                        ? Colors.red
                        : _log[i].contains('STATE: READY') || _log[i].contains('<< DATA:')
                        ? Colors.green.shade700
                        : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}