import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'beacon_service.dart';


enum MqttConnectionState { disconnected, connecting, connected, reconnecting, error }

class ZoneResponse {
  final String phoneId;
  final String zone;
  final String baseWebsite;
  final String zonePath;
  final String website;
  final DateTime receivedAt;

  ZoneResponse({
    required this.phoneId,
    required this.zone,
    required this.baseWebsite,
    required this.zonePath,
    required this.website,
    required this.receivedAt,
  });

  factory ZoneResponse.fromJson(Map<String, dynamic> json) {
    final base = json['baseWebsite']?.toString() ?? '';
    final path = json['zonePath']?.toString() ?? '';
    String web = json['website']?.toString() ?? '';
    if (web.isEmpty && base.isNotEmpty) {
      web = '$base$path';
    }

    return ZoneResponse(
      phoneId: json['phoneId']?.toString() ?? '',
      zone: json['zone']?.toString() ?? 'Unknown Zone',
      baseWebsite: base,
      zonePath: path,
      website: web,
      receivedAt: DateTime.now(),
    );
  }
}

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  String _phoneId = '';

  
  final ValueNotifier<MqttConnectionState> connectionStateNotifier =
      ValueNotifier<MqttConnectionState>(MqttConnectionState.disconnected);

  final ValueNotifier<ZoneResponse?> latestZoneNotifier = ValueNotifier<ZoneResponse?>(null);
  final ValueNotifier<int> activeOptionNotifier = ValueNotifier<int>(1); // 1 = Option 1 (1883 TCP), 2 = Option 2 (8883 SSL)
  


  static const String _brokerHost = 'broker.emqx.io';
  static const String _publishTopic = 'phones/location';

  Timer? _reconnectTimer;
  bool _isManualDisconnect = false;
  bool acceptingZoneMessages = false;

  void setBroadcastingActive(bool active) {
    acceptingZoneMessages = active;
    latestZoneNotifier.value = null;
  }

  String get phoneId {
  final id = _phoneId.isNotEmpty ? _phoneId : BeaconService().uuid;
  return id.length >= 4 ? id.substring(id.length - 4) : id;
  }
  String get encodedPhoneId => Uri.encodeComponent(phoneId);
  String get subscribeTopic => 'phones/$phoneId/zone';

  Future<void> init() async {
    setBroadcastingActive(false);
    final prefs = await SharedPreferences.getInstance();
    final deviceUuid = await BeaconService().getOrCreateUuid();
    _phoneId = prefs.getString('mqtt_phone_id') ?? deviceUuid;
    activeOptionNotifier.value = prefs.getInt('mqtt_option') ?? 1; // Default to Option 1 (Port 1883 TCP)
    BeaconService().addLog("MQTT Service initialized. Assigned Phone ID: $_phoneId | Active Option: Option ${activeOptionNotifier.value}");
  }

  Future<void> setOption(int option) async {
    if (option != 1 && option != 2) return;
    activeOptionNotifier.value = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mqtt_option', option);
    BeaconService().addLog("MQTT Configuration set to Option $option (${option == 1 ? 'Port 1883 TCP' : 'Port 8883 SSL'})");
    
    // Reconnect with selected option
    _isManualDisconnect = false;
    _clearOldClient();
    connect();
  }

  Future<void> updatePhoneId(String newPhoneId) async {
    if (newPhoneId.trim().isEmpty || newPhoneId == _phoneId) return;
    
    if (connectionStateNotifier.value == MqttConnectionState.connected && _client != null) {
      try {
        _client!.unsubscribe(subscribeTopic);
        BeaconService().addLog("Unsubscribed from topic: $subscribeTopic");
      } catch (_) {}
    }

    _phoneId = newPhoneId.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mqtt_phone_id', _phoneId);
    BeaconService().addLog("Updated Phone ID to: $_phoneId");

    if (connectionStateNotifier.value == MqttConnectionState.connected && _client != null) {
      _subscribeToZoneTopic();
    }
  }

  void _clearOldClient() {
    if (_client != null) {
      _client!.onConnected = null;
      _client!.onDisconnected = null;
      _client!.onSubscribed = null;
      _client!.onAutoReconnect = null;
      _client!.onAutoReconnected = null;
      try {
        _client!.disconnect();
      } catch (_) {}
      _client = null;
    }
  }

  Future<void> connect() async {
    if (connectionStateNotifier.value == MqttConnectionState.connected ||
        connectionStateNotifier.value == MqttConnectionState.connecting) {
      return;
    }

    _isManualDisconnect = false;
    _clearOldClient();

    final targetOption = activeOptionNotifier.value;
    final port = targetOption == 2 ? 8883 : 1883;

    connectionStateNotifier.value = MqttConnectionState.connecting;
    BeaconService().addLog("Connecting to MQTT Broker at $_brokerHost:$port (Option $targetOption)...");

    final clientIdentifier = 'flutter_bconnect_${DateTime.now().millisecondsSinceEpoch}';
    
    _client = MqttServerClient.withPort(_brokerHost, clientIdentifier, port);
    if (port == 8883) {
      _client!.secure = true;
      _client!.securityContext = SecurityContext.defaultContext;
      _client!.onBadCertificate = (dynamic certificate) => true;
      _client!.useWebSocket = false;
    } else {
      _client!.secure = false;
      _client!.useWebSocket = false;
    }

    _client!.keepAlivePeriod = 30;
    _client!.connectTimeoutPeriod = 8000;
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;
    _client!.logging(on: false);

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean();

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      BeaconService().addLog("MQTT Connection Exception on port $port: $e");
      
      // If Option 2 (8883 SSL) fails, fallback to Option 1 (1883 TCP)
      if (port == 8883) {
        BeaconService().addLog("Option 2 (Port 8883 SSL) failed. Falling back to Option 1 (Port 1883 TCP)...");
        _clearOldClient();
        await _connectPort1883();
        return;
      }
      
      connectionStateNotifier.value = MqttConnectionState.error;
      _clearOldClient();
      _startReconnectTimer();
    }
  }

  Future<void> _connectPort1883() async {
    const fallbackPort = 1883;
    connectionStateNotifier.value = MqttConnectionState.connecting;
    BeaconService().addLog("Connecting via Option 1 to $_brokerHost:$fallbackPort...");
    
    final clientIdentifier = 'flutter_bconnect_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient.withPort(_brokerHost, clientIdentifier, fallbackPort);
    _client!.secure = false;
    _client!.useWebSocket = false;
    _client!.keepAlivePeriod = 30;
    _client!.connectTimeoutPeriod = 8000;
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;
    _client!.logging(on: false);

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean();

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      BeaconService().addLog("Option 1 Connection Exception: $e");
      connectionStateNotifier.value = MqttConnectionState.error;
      _clearOldClient();
      _startReconnectTimer();
    }
  }

  void _onConnected() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    connectionStateNotifier.value = MqttConnectionState.connected;
    BeaconService().addLog("MQTT Connected successfully to $_brokerHost");

    _subscribeToZoneTopic();

    // Listen for incoming messages
    _client!.updates?.listen(_onMessagesReceived);
  }

  void _onDisconnected() {
    latestZoneNotifier.value = null;
    if (connectionStateNotifier.value != MqttConnectionState.reconnecting) {
      connectionStateNotifier.value = MqttConnectionState.disconnected;
    }
    BeaconService().addLog("MQTT Disconnected.");

    if (!_isManualDisconnect) {
      _startReconnectTimer();
    }
  }

  void _startReconnectTimer() {
    if (_isManualDisconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (connectionStateNotifier.value == MqttConnectionState.disconnected ||
          connectionStateNotifier.value == MqttConnectionState.error) {
        BeaconService().addLog("Auto-retry: Attempting to reconnect to MQTT...");
        connect();
      } else {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }
    });
  }

  void _onAutoReconnect() {
    latestZoneNotifier.value = null;
    connectionStateNotifier.value = MqttConnectionState.reconnecting;
    BeaconService().addLog("MQTT Auto-reconnecting...");
  }

  void _onAutoReconnected() {
    connectionStateNotifier.value = MqttConnectionState.connected;
    BeaconService().addLog("MQTT Auto-reconnected!");
    _subscribeToZoneTopic();
  }

  void _onSubscribed(String topic) {
    BeaconService().addLog("Subscribed to MQTT Topic: $topic");
  }

  void _subscribeToZoneTopic() {
    if (_client == null || connectionStateNotifier.value != MqttConnectionState.connected) return;
    
    final topic = subscribeTopic;
    BeaconService().addLog("Subscribing to: $topic");
    _client!.subscribe(topic, MqttQos.atLeastOnce);
  }

  void _onMessagesReceived(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final recMsg = event.payload as MqttPublishMessage;
      if (!acceptingZoneMessages ||
          connectionStateNotifier.value != MqttConnectionState.connected) {
        BeaconService().addLog('Ignored zone message: broadcasting is inactive.');
        continue;
      }
      if (recMsg.header?.retain == true) {
        BeaconService().addLog('Ignored retained zone message.');
        continue;
      }
      final payloadStr = MqttPublishPayload.bytesToStringAsString(recMsg.payload.message);

      BeaconService().addLog("Received MQTT on [${event.topic}]: $payloadStr");

      try {
        final Map<String, dynamic> jsonMap = jsonDecode(payloadStr);
        final zoneData = ZoneResponse.fromJson(jsonMap);

        // The installation has four valid zones. Normalize the incoming
        // label so ESP firmware may send either `ZONE_C` or `zone_c`.
        final normalizedZone = zoneData.zone.toUpperCase();
        if (!RegExp(r'^ZONE_[A-D]$').hasMatch(normalizedZone)) {
          BeaconService().addLog('Ignored zone message: unsupported zone ${zoneData.zone}.');
          continue;
        }

        final uri = Uri.tryParse(zoneData.website);
        if (event.topic != subscribeTopic || zoneData.phoneId != phoneId ||
            uri == null || !uri.hasAuthority ||
            (uri.scheme != 'https' && uri.scheme != 'http')) {
          BeaconService().addLog('Ignored zone message: invalid phone ID or website.');
          continue;
        }
        latestZoneNotifier.value = ZoneResponse(
          phoneId: zoneData.phoneId,
          zone: normalizedZone,
          baseWebsite: zoneData.baseWebsite,
          zonePath: zoneData.zonePath,
          website: zoneData.website,
          receivedAt: zoneData.receivedAt,
        );
      } catch (e) {
        BeaconService().addLog("Error parsing MQTT JSON: $e");
      }
    }
  }

  Future<bool> openWebsite(String urlStr) async {
    try {
      final Uri? uri = Uri.tryParse(urlStr);
      if (uri != null && await canLaunchUrl(uri)) {
        BeaconService().addLog("Opening browser URL: $urlStr");
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        BeaconService().addLog("Cannot launch invalid URL: $urlStr");
        return false;
      }
    } catch (e) {
      BeaconService().addLog("Error launching URL: $e");
      return false;
    }
  }

  Future<void> publishLocationData({
    required Map<String, int> espRssiMap,
  }) async {
    if (_client == null || connectionStateNotifier.value != MqttConnectionState.connected) {
      BeaconService().addLog("Cannot publish: MQTT client is not connected.");
      return;
    }

    final Map<String, dynamic> payloadMap = {
      'phoneId': phoneId,
      ...espRssiMap,
    };

    final String jsonString = jsonEncode(payloadMap);

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonString);

    try {
      _client!.publishMessage(
        _publishTopic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );
      BeaconService().addLog("Published location data to [$_publishTopic]: $jsonString");
    } catch (e) {
      BeaconService().addLog("Error publishing location data: $e");
    }
  }

  void disconnect() {
    latestZoneNotifier.value = null;
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _clearOldClient();
    connectionStateNotifier.value = MqttConnectionState.disconnected;
    BeaconService().addLog("Disconnected from MQTT Broker.");
  }
}


