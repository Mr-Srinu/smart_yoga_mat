// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import '../bluetooth/classic_adapter.dart';
// import '../bluetooth/connection_manager.dart';
// import '../bluetooth/connection_wrapper.dart';
// import '../bluetooth/ble_adapter.dart';
//
// class ClassicConsole extends StatefulWidget {
//   final ClassicDeviceInfo device;
//   const ClassicConsole({super.key, required this.device});
//   @override
//   State<ClassicConsole> createState() => _ClassicConsoleState();
// }
//
// class _ClassicConsoleState extends State<ClassicConsole> {
//   final _log = <String>[];
//   final _input = TextEditingController();
//   ConnectionWrapper? _wrapper;
//
//   bool _busy = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _connect();
//   }
//
//   Future<void> _connect() async {
//     setState(() => _busy = true);
//     try {
//       final classic = ClassicAdapter();
//       final cm = ConnectionManager(ble: BleAdapter(), classic: classic);
//       final w = await cm.createClassicWrapper(widget.device.id);
//       _wrapper = w;
//       w.dataStream?.listen((bytes) => _push('RX  ${_fmt(bytes)}'));
//       setState(() => _busy = false);
//       _push('Connected to ${widget.device.name}');
//     } catch (e) {
//       setState(() => _busy = false);
//       _push('ERROR: $e');
//     }
//   }
//
//   String _fmt(List<int> bytes) {
//     String asText;
//     try {
//       asText = utf8.decode(bytes);
//     } catch (_) {
//       asText = '';
//     }
//     final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
//     return '(${bytes.length}b) "$asText" | 0x[$hex]';
//   }
//
//   void _push(String s) => setState(() => _log.insert(0, '[${TimeOfDay.now().format(context)}] $s'));
//
//   Future<void> _send() async {
//     final text = _input.text;
//     if (text.isEmpty || _wrapper == null) return;
//     final bytes = Uint8List.fromList(utf8.encode('$text\n'));
//     await _wrapper!.send(bytes);
//     _push('TX  ${_fmt(bytes)}');
//     _input.clear();
//   }
//
//   @override
//   void dispose() {
//     _wrapper?.dispose();
//     _input.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final title = '${widget.device.name} (Classic)';
//     return Scaffold(
//       appBar: AppBar(title: Text(title)),
//       body: _busy
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _input,
//                     decoration: const InputDecoration(
//                       labelText: 'Write text (\\n appended)',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 FilledButton(onPressed: _send, child: const Text('Send')),
//               ],
//             ),
//           ),
//           Expanded(
//             child: ListView.separated(
//               padding: const EdgeInsets.all(12),
//               reverse: true,
//               itemCount: _log.length,
//               separatorBuilder: (_, __) => const SizedBox(height: 8),
//               itemBuilder: (_, i) => Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
//                 ),
//                 child: Text(_log[i], style: const TextStyle(fontFamily: 'monospace')),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
