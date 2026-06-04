import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;

  BluetoothService._internal() {
    // Skip platform channel stream subscriptions during widget tests to avoid pending timers
    bool isTest = false;
    try {
      isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
               WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {}

    if (isTest) return;

    // Monitor local bluetooth adapter state changes
    FlutterBluetoothSerial.instance.state.then((state) {
      _bluetoothState = state;
      notifyListeners();
    });

    FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
      _bluetoothState = state;
      notifyListeners();
    });
  }

  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection? _connection;
  bool _isConnecting = false;
  List<BluetoothDevice> _bondedDevices = [];
  final List<String> _consoleLogs = [];
  bool _isDisconnecting = false;

  BluetoothState get bluetoothState => _bluetoothState;
  bool get isConnected => _connection != null && _connection!.isConnected;
  bool get isConnecting => _isConnecting;
  List<BluetoothDevice> get bondedDevices => _bondedDevices;
  List<String> get consoleLogs => _consoleLogs;

  Future<bool> checkAndRequestPermissions() async {
    // Bluetooth Classic permissions for newer Android (API 31+)
    // permission_handler makes it easy to check and request them
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    final scan = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connect = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final location = statuses[Permission.location]?.isGranted ?? false;

    // Check if permissions are sufficient (scan + connect for Android 12+, location for older versions)
    return (connect && scan) || location;
  }

  Future<void> refreshBondedDevices() async {
    final hasPerms = await checkAndRequestPermissions();
    if (!hasPerms) {
      addLog("System: Bluetooth/Location permissions not granted.");
      return;
    }

    try {
      _bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      addLog("System: Loaded ${_bondedDevices.length} paired devices.");
      notifyListeners();
    } catch (e) {
      addLog("Error loading paired devices: $e");
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (isConnected) {
      await disconnect();
    }

    _isConnecting = true;
    _isDisconnecting = false;
    addLog("Connecting to ${device.name ?? device.address}...");
    notifyListeners();

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _isConnecting = false;
      addLog("System: Connected to ${device.name ?? device.address}!");
      notifyListeners();

      // Listen to incoming data from robot
      _connection!.input!.listen((Uint8List data) {
        final incoming = ascii.decode(data);
        addLog("Robot: $incoming");
      }).onDone(() {
        if (_isDisconnecting) {
          addLog("System: Disconnected.");
        } else {
          addLog("System: Connection lost (Remote disconnected).");
        }
        _connection = null;
        notifyListeners();
      });

      return true;
    } catch (e) {
      _isConnecting = false;
      _connection = null;
      addLog("Connection failed: $e");
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connection != null) {
      _isDisconnecting = true;
      addLog("System: Disconnecting...");
      try {
        await _connection!.finish();
      } catch (e) {
        addLog("Error closing connection: $e");
      }
      _connection = null;
      notifyListeners();
    }
  }

  void send(String data) {
    if (!isConnected) {
      addLog("Warning: Cannot send. Bluetooth not connected.");
      return;
    }

    try {
      _connection!.output.add(Uint8List.fromList(data.codeUnits));
      addLog("TX: '$data'");
    } catch (e) {
      addLog("Error sending data: $e");
      disconnect();
    }
  }

  void addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _consoleLogs.add("[$timestamp] $message");
    if (_consoleLogs.length > 80) {
      _consoleLogs.removeAt(0);
    }
    notifyListeners();
  }

  void clearLogs() {
    _consoleLogs.clear();
    notifyListeners();
  }
}
