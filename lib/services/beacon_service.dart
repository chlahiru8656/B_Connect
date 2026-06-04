import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:beacon_broadcast/beacon_broadcast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class BeaconService {
  static final BeaconService _instance = BeaconService._internal();
  factory BeaconService() => _instance;
  BeaconService._internal();

  final BeaconBroadcast _beaconBroadcast = BeaconBroadcast();
  String? _uuid;

  // Track logs for the console output in the UI
  final List<String> _logs = [];
  final ValueNotifier<List<String>> logsNotifier = ValueNotifier<List<String>>([]);

  Future<void> init() async {
    _uuid = await getOrCreateUuid();
    addLog("System initialized. Device ID: $_uuid");
  }

  void addLog(String message) {
    final timestamp = DateTime.now().toLocal().toString().split(' ')[1].substring(0, 8);
    final log = "[$timestamp] $message";
    _logs.insert(0, log); // Newest logs first
    if (_logs.length > 50) {
      _logs.removeLast();
    }
    logsNotifier.value = List.from(_logs);
  }

  String get uuid => _uuid ?? 'Unknown-ID';

  static const String _uuidPrefix = "00000000-0000-0000-0000-00000000";

  /// Retrieves the saved UUID or generates a new one on first launch.
  Future<String> getOrCreateUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedUuid = prefs.getString('beacon_uuid');
    
    // If the stored UUID is empty or does not start with our app prefix, generate a new one
    if (storedUuid == null || storedUuid.isEmpty || !storedUuid.startsWith(_uuidPrefix)) {
      final fullRandomUuid = const Uuid().v4();
      final suffix = fullRandomUuid.substring(32); // Extract the last 4 characters
      storedUuid = "$_uuidPrefix$suffix";
      await prefs.setString('beacon_uuid', storedUuid);
      addLog("Generated new prefix-based UUID: $storedUuid");
    } else {
      addLog("Retrieved prefix-based UUID: $storedUuid");
    }
    return storedUuid;
  }

  /// Checks if required permissions are granted.
  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      final advertise = await Permission.bluetoothAdvertise.status;
      final connect = await Permission.bluetoothConnect.status;
      final scan = await Permission.bluetoothScan.status;
      final location = await Permission.location.status;
      
      final granted = advertise.isGranted && connect.isGranted && scan.isGranted && location.isGranted;
      addLog("Permission Check: ${granted ? 'ALL GRANTED' : 'MISSING PERMISSIONS'}");
      return granted;
    } else if (Platform.isIOS) {
      final bluetooth = await Permission.bluetooth.status;
      addLog("Permission Check: Bluetooth status is ${bluetooth.toString()}");
      return bluetooth.isGranted;
    }
    return false;
  }

  /// Requests the necessary permissions for BLE peripheral advertising.
  Future<bool> requestPermissions() async {
    addLog("Requesting permissions...");
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();
      
      final granted = statuses[Permission.bluetoothAdvertise]?.isGranted == true &&
          statuses[Permission.bluetoothConnect]?.isGranted == true &&
          statuses[Permission.bluetoothScan]?.isGranted == true &&
          statuses[Permission.location]?.isGranted == true;

      addLog("Android permissions requested. Status: ${granted ? 'GRANTED' : 'DENIED'}");
      return granted;
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      addLog("iOS Bluetooth permission requested. Status: ${status.isGranted ? 'GRANTED' : 'DENIED'}");
      return status.isGranted;
    }
    return false;
  }

  /// Starts BLE broadcasting (advertising).
  Future<void> startBroadcasting() async {
    final hasPermissions = await checkPermissions();
    if (!hasPermissions) {
      final requested = await requestPermissions();
      if (!requested) {
        addLog("Cannot start advertising: Permissions denied.");
        return;
      }
    }

    final BeaconStatus transmissionSupportStatus = await _beaconBroadcast.checkTransmissionSupported();
    if (transmissionSupportStatus != BeaconStatus.supported) {
      addLog("Error: BLE Peripheral transmission is not supported on this device. Status: $transmissionSupportStatus");
      return;
    }

    final String currentUuid = uuid;

    addLog("Configuring iBeacon (Legacy BLE 4.0)...");
    
    try {
      addLog("Starting iBeacon Broadcast...");
      await _beaconBroadcast
          .setUUID(currentUuid)
          .setMajorId(1)
          .setMinorId(100)
          .setLayout('m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24') // Standard iBeacon layout
          .setManufacturerId(0x004C) // Apple CoID to force 4C 00
          .start();
      addLog("Broadcasting active! iBeacon UUID: $currentUuid");
    } catch (e) {
      addLog("Error starting advertisement: $e");
    }
  }

  /// Stops BLE broadcasting (advertising).
  Future<void> stopBroadcasting() async {
    try {
      addLog("Stopping iBeacon Broadcast...");
      await _beaconBroadcast.stop();
      addLog("Broadcasting stopped.");
    } catch (e) {
      addLog("Error stopping advertisement: $e");
    }
  }

  /// Stream of broadcasting status changes (true if broadcasting, false otherwise).
  Stream<bool> get isBroadcastingStream => _beaconBroadcast.getAdvertisingStateChange();

  /// Helper to get the current advertising status.
  Future<bool> get isAdvertising async => (await _beaconBroadcast.isAdvertising()) ?? false;
}
