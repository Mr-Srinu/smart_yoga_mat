import 'dart:async';

enum ConnType { ble, classic }
// Reduced to key states for the UI and Wrapper logic
enum ConnState { disconnected, connecting, ready, error }

class ConnectionEvent {
  final ConnState state;
  final String? message;
  const ConnectionEvent(this.state, {this.message});
}

typedef WriteHandler = Future<void> Function(List<int> data);
typedef Action = Future<void> Function();
typedef DeviceConnectAction = Future<void> Function(String id);

class ConnectionWrapper {
  final ConnType type;
  final String deviceId;
  final Action startScan;
  final DeviceConnectAction connect;
  final Action discover;
  final Action ready;
  final Action disconnect;
  final WriteHandler? write;
  final Stream<List<int>>? dataStream;
  // New: Stream from the underlying package to monitor connection health
  final Stream<ConnState> connectionStateStream;
  final Duration retryDelay;
  final int maxRetries;

  final _controller = StreamController<ConnectionEvent>.broadcast();
  Stream<ConnectionEvent> get events => _controller.stream;

  ConnState _currentState = ConnState.disconnected;
  ConnState get currentState => _currentState;

  bool _disposed = false;
  StreamSubscription? _connectionStateSub;
  Completer<void>? _connectionAttemptCompleter;

  ConnectionWrapper({
    required this.type,
    required this.deviceId,
    required this.startScan,
    required this.connect,
    required this.discover,
    required this.ready,
    required this.disconnect,
    required this.connectionStateStream,
    this.write,
    this.dataStream,
    this.retryDelay = const Duration(seconds: 3),
    this.maxRetries = 5,
  });

  void _emit(ConnState s, [String? msg]) {
    if (_disposed) return;
    _currentState = s;
    _controller.add(ConnectionEvent(s, message: msg));
  }

  // Monitors the connection stream and triggers auto-reconnect on unexpected drop
  void _listenForDrop() {
    _connectionStateSub = connectionStateStream.listen((state) async {
      if (_disposed) return;

      // If the underlying package reports DISCONNECTED while we were READY,
      // and we are not currently retrying a connection, initiate auto-reconnect.
      if (state == ConnState.disconnected && _currentState == ConnState.ready) {
        _emit(ConnState.error, 'Unexpected Disconnection. Initiating auto-reconnect...');
        // Automatically restart the connection process
        await start(deviceId);
      }

      // Update the wrapper's main state only if we aren't in a transient phase
      if (_connectionAttemptCompleter == null || _connectionAttemptCompleter!.isCompleted) {
        _emit(state);
      }

    }, onError: (e) {
      if (!_disposed) {
        _emit(ConnState.error, 'Connection Stream Error: $e');
        // Treat stream error as an unexpected drop and try to reconnect
        start(deviceId);
      }
    });
  }

  Future<void> start(String deviceId) async {
    if (_connectionAttemptCompleter?.isCompleted == false) {
      _emit(ConnState.connecting, 'Connection already in progress. Ignoring new request.');
      return;
    }
    _connectionAttemptCompleter = Completer<void>();
    _connectionStateSub?.cancel(); // Cancel old sub before new attempt

    int attempt = 0;
    while (!_disposed && attempt < maxRetries) {
      attempt++;
      try {
        _emit(ConnState.connecting);
        _emit(ConnState.connecting, 'Attempt $attempt/$maxRetries: Scanning...');
        await startScan().timeout(const Duration(seconds: 4)); // Scan timeout

        _emit(ConnState.connecting, 'Attempt $attempt/$maxRetries: Connecting...');
        await connect(deviceId).timeout(const Duration(seconds: 12)); // Connect timeout

        _emit(ConnState.connecting, 'Attempt $attempt/$maxRetries: Discovering services...');
        await discover().timeout(const Duration(seconds: 5)); // Discover timeout

        // This is the true "Ready" state after all protocol work is done
        _emit(ConnState.ready);
        _emit(ConnState.ready, 'Connection Stable (Attempt $attempt)');

        _listenForDrop(); // Start monitoring the actual connection state
        _connectionAttemptCompleter!.complete();
        return;
      } catch (e) {
        if (_disposed) break;
        _emit(ConnState.error, 'Attempt $attempt/$maxRetries failed: $e');
        if (attempt >= maxRetries) {
          _emit(ConnState.disconnected, 'Max retries reached. Permanently disconnected.');
          break;
        }
        final delay = retryDelay * attempt;
        _emit(ConnState.connecting, 'Retrying in ${delay.inSeconds}s...');
        await Future.delayed(delay);
      }
    }
    if (_connectionAttemptCompleter?.isCompleted == false) {
      _connectionAttemptCompleter!.completeError('Connection failed after $maxRetries retries.');
    }
  }

  Future<void> send(List<int> data) async {
    if (currentState != ConnState.ready || write == null) {
      throw StateError('Cannot send data: Not connected or write not supported.');
    }
    await write!(data);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _connectionStateSub?.cancel();
    _connectionAttemptCompleter?.complete();
    try {
      _emit(ConnState.disconnected);
      await disconnect();
    } catch (_) {}
    await _controller.close();
  }
}