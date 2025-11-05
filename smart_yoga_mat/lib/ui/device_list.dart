import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/ble_adapter.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../bluetooth/classic_adapter.dart';
import '../utils/permissions.dart';
import 'connect_console_ble.dart';
import 'connect_console_classic.dart';
import 'device_detail.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  // Removed: final Map<String, BleDeviceInfo> bleDevices = {};
  // Removed: final Map<String, ClassicDeviceInfo> classicDevices = {};

  @override
  void initState() {
    super.initState();
    final mgr = context.read<BluetoothManager>();
    // FIX 1: Rely solely on the ChangeNotifier mechanism (m.addListener).
    mgr.addListener(_onManagerUpdate);
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _recheckPermissions() async {
    final ok = await AppPermissions.ensure();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Permissions OK' : 'Permissions missing')),
    );
    setState(() {});
  }

  Future<void> _turnOnBle(BluetoothManager m) async {
    await m.bleAdapter.requestEnable();
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  Future<void> _turnOnClassic(BluetoothManager m) async {
    await m.classicAdapter.requestEnable();
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  @override
  void dispose() {
    context.read<BluetoothManager>().removeListener(_onManagerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<BluetoothManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Yoga Mat • Bluetooth'),
        actions: [
          IconButton(
            tooltip: 'Stop',
            icon: const Icon(Icons.stop_circle),
            onPressed: () => m.stopAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _statusTile(
            icon: Icons.bluetooth_searching,
            ok: m.bleOn,
            okText: 'BLE is ON',
            badText: 'BLE is OFF — tap to turn on',
            onTap: () => _turnOnBle(m),
          ),
          const SizedBox(height: 8),
          _statusTile(
            icon: Icons.bluetooth,
            ok: m.classicOn,
            okText: 'Classic is ON',
            badText: 'Classic is OFF — tap to turn on',
            onTap: () => _turnOnClassic(m),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Scan BLE'),
                  onPressed: m.bleOn
                      ? () async {
                    try {
                      // FIX 2: Correctly calling Future<void> method.
                      m.startBleScan();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scanning BLE…')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('BLE: $e')),
                      );
                    }
                  }
                      : () => _recheckPermissions(),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Discover Classic'),
                  onPressed: m.classicOn
                      ? () async {
                    try {
                      // FIX 2: Correctly calling Future<void> method.
                      m.startClassicDiscovery();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Discovering Classic…')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Classic: $e')),
                      );
                    }
                  }
                      : () => _recheckPermissions(),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Recheck Permissions'),
                  onPressed: _recheckPermissions,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(tabs: [Tab(text: 'BLE'), Tab(text: 'Classic')]),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildBleList(m),
                        _buildClassicList(m),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTile({
    required IconData icon,
    required bool ok,
    required String okText,
    required String badText,
    required VoidCallback onTap,
  }) {
    final color = ok ? Colors.green : Colors.red;
    final text = ok ? okText : badText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(color: color.shade700))),
              if (!ok)
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('Turn On'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBleList(BluetoothManager m) {
    final list = m.bleDevices.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    if (list.isEmpty) {
      return const Center(child: Text('No BLE devices yet. Tap “Scan BLE”.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final d = list[i];
        final signalColor = d.rssi > -60
            ? Colors.green
            : d.rssi > -80
            ? Colors.orange
            : Colors.red;

        return _tile(
          child: ListTile(
            leading: Icon(Icons.bluetooth_searching, color: signalColor),
            title: Text(d.name.isNotEmpty ? d.name : "Unknown",
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('ID: ${d.id}\nRSSI: ${d.rssi} dBm'),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  child: const Text('Details'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DeviceDetailScreen.ble(device: d)),
                    );
                  },
                ),
                FilledButton(
                  child: const Text('Connect'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BleConnectConsole(device: d)),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClassicList(BluetoothManager m) {
    final list = m.classicDevices.values.toList();
    if (list.isEmpty) {
      return const Center(child: Text('No Classic devices yet. Tap “Discover Classic”.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final d = list[i];
        return _tile(
          child: ListTile(
            leading: Icon(d.bonded ? Icons.link : Icons.bluetooth,
                color: d.bonded ? Colors.green : Colors.blue),
            title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Address: ${d.address}\nBonded: ${d.bonded ? "Yes" : "No"}'),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 8,
              children: [
                if (!d.bonded)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('Pair'),
                    onPressed: () async {
                      final adapter = context.read<BluetoothManager>().classicAdapter;
                      final success = await adapter.pair(d.address);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? 'Paired with ${d.name}' : 'Pair failed')),
                      );
                      // FIX: Update the manager's list and notify listeners
                      m.classicDevices[d.address] =
                          ClassicDeviceInfo(address: d.address, name: d.name, bonded: success);
                      m.notifyListeners();
                    },
                  ),
                if (d.bonded)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link_off),
                    label: const Text('Unpair'),
                    onPressed: () async {
                      final adapter = context.read<BluetoothManager>().classicAdapter;
                      final success = await adapter.unpair(d.address);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? 'Unpaired' : 'Unpair failed')),
                      );
                      // FIX: Update the manager's list and notify listeners
                      m.classicDevices[d.address] =
                          ClassicDeviceInfo(address: d.address, name: d.name, bonded: !success);
                      m.notifyListeners();
                    },
                  ),
                OutlinedButton(
                  child: const Text('Details'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DeviceDetailScreen.classic(device: d)),
                    );
                  },
                ),
                FilledButton(
                  child: const Text('Connect'),
                  onPressed: () {
                    // Navigate to the Classic Connection Console
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ClassicConnectConsole(device: d)),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile({required Widget child}) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}