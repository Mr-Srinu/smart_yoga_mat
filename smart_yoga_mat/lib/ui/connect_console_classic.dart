import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_yoga_mat/ui/widgets/status_banter.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../bluetooth/classic_adapter.dart';
import '../bluetooth/connection_manager.dart';
import '../bluetooth/connection_wrapper.dart';


class ClassicConnectConsole extends StatefulWidget {
  final ClassicDeviceInfo device;
  const ClassicConnectConsole({required this.device, super.key});

  @override
  State<ClassicConnectConsole> createState() => _ClassicConnectConsoleState();
}

class _ClassicConnectConsoleState extends State<ClassicConnectConsole> {
  ConnectionWrapper? _wrapper;
  final List<String> _log = [];
  final TextEditingController _controller = TextEditingController();
  ConnState _state = ConnState.disconnected;
  StreamSubscription? _logSub;
  StreamSubscription? _dataSub;

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  Future<void> _initConnection() async {
    final mgr = context.read<BluetoothManager>();
    try {
      final connectionMgr = ConnectionManager(
        ble: mgr.bleAdapter,
        classic: mgr.classicAdapter,
      );
      // NOTE: Classic devices use address as the ID
      _wrapper = await connectionMgr.createClassicWrapper(widget.device.address);

      _logSub = _wrapper!.events.listen((event) {
        if (!mounted) return;
        setState(() {
          _state = event.state;
          _log.add('STATE: ${event.state.name.toUpperCase()}');
          if (event.message != null) _log.add(' • ${event.message!}');
        });
      });

      _dataSub = _wrapper!.dataStream?.listen((data) {
        if (!mounted) return;
        // Classic SPP usually transmits simple strings ending with \n
        final text = utf8.decode(data, allowMalformed: true).trim();
        if (text.isNotEmpty) {
          setState(() {
            _log.add('<< STREAM: $text');
          });
        }
      });

      await _wrapper!.start(widget.device.address);

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = ConnState.error;
        _log.add('FATAL ERROR: $e');
      });
    }
  }

  Future<void> _sendData() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // SPP usually expects a line ending, adding it here for the prototype
    final data = utf8.encode('$text\n');
    _controller.clear();

    setState(() => _log.add('>> WRITE: $text'));
    try {
      await _wrapper?.send(data);
      setState(() => _log.add('   [ACK] Write successful'));
    } catch (e) {
      setState(() {
        _log.add('   [ERR] Write failed: $e');
        _state = ConnState.error;
      });
    }
  }

  void _retryConnection() {
    _log.add('--- Manual Retry Initiated ---');
    _wrapper?.start(widget.device.address);
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
    final isError = _state == ConnState.error;
    final isLoading = _state == ConnState.connecting;
    final statusText = isReady ? 'Connected: Streaming Data' : isLoading ? 'Connecting/Retrying...' : isError ? 'Error: Check Log & Retry' : 'Disconnected';
    final statusOk = isReady || isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
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
          // Connection Status Banner
          StatusBanner(
            ok: statusOk,
            okText: statusText,
            badText: statusText,
            onRetry: _retryConnection,
          ),
          const SizedBox(height: 12),

          // Data Log Console
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _log[_log.length - 1 - i],
                  style: TextStyle(
                    fontSize: 12,
                    color: _log[_log.length - 1 - i].startsWith('>>')
                        ? Colors.blue.shade700
                        : _log[_log.length - 1 - i].startsWith('<<')
                        ? Colors.green.shade700
                        : _log[_log.length - 1 - i].contains('READY')
                        ? Colors.lightGreen
                        : _log[_log.length - 1 - i].contains('ERROR')
                        ? Colors.red
                        : Colors.black54,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),

          // Command Input
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              enabled: isReady,
              decoration: InputDecoration(
                labelText: 'Command (appends "\\n")',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: isReady ? _sendData : null,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: isReady ? (_) => _sendData() : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}