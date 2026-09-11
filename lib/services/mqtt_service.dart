import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  WebViewController? webViewController;
  
  final ValueNotifier<MqttConnectionState> connectionStateNotifier =
      ValueNotifier<MqttConnectionState>(MqttConnectionState.disconnected);

  final ValueNotifier<ZoneResponse?> latestZoneNotifier = ValueNotifier<ZoneResponse?>(null);
  
  String? _lastOpenedUrl;
  DateTime? _lastOpenedTime;

  static const String _brokerHost = 'broker.emqx.io';
  static const int _brokerPort = 8084;
  static const String _publishTopic = 'phones/location';

  String get phoneId => _phoneId.isNotEmpty ? _phoneId : BeaconService().uuid;
  String get encodedPhoneId => Uri.encodeComponent(phoneId);
  String get subscribeTopic => 'phones/$encodedPhoneId/zone';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceUuid = await BeaconService().getOrCreateUuid();
    _phoneId = prefs.getString('mqtt_phone_id') ?? deviceUuid;
    BeaconService().addLog("MQTT Service initialized. Assigned Phone ID: $_phoneId");
  }

  Future<void> updatePhoneId(String newPhoneId) async {
    if (newPhoneId.trim().isEmpty || newPhoneId == _phoneId) return;
    
    // Unsubscribe from old topic if connected
    if (connectionStateNotifier.value == MqttConnectionState.connected && _client != null) {
      _client!.unsubscribe(subscribeTopic);
      BeaconService().addLog("Unsubscribed from topic: $subscribeTopic");
    }

    _phoneId = newPhoneId.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mqtt_phone_id', _phoneId);
    BeaconService().addLog("Updated Phone ID to: $_phoneId");

    // Subscribe to new topic if connected
    if (connectionStateNotifier.value == MqttConnectionState.connected && _client != null) {
      _subscribeToZoneTopic();
    }
  }

  Future<void> connect() async {
    if (connectionStateNotifier.value == MqttConnectionState.connected ||
        connectionStateNotifier.value == MqttConnectionState.connecting) {
      return;
    }

    connectionStateNotifier.value = MqttConnectionState.connecting;
    BeaconService().addLog("Connecting to MQTT Broker at wss://$_brokerHost:$_brokerPort/mqtt...");

    final clientIdentifier = 'flutter_bconnect_${DateTime.now().millisecondsSinceEpoch}';
    
    _client = MqttServerClient.withPort(_brokerHost, clientIdentifier, _brokerPort);
    _client!.useWebSocket = true;
    _client!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    _client!.keepAlivePeriod = 30;
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
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      BeaconService().addLog("MQTT Connection Exception: $e");
      connectionStateNotifier.value = MqttConnectionState.error;
      _client?.disconnect();
    }
  }

  void _onConnected() {
    connectionStateNotifier.value = MqttConnectionState.connected;
    BeaconService().addLog("MQTT Connected successfully to $_brokerHost");

    _subscribeToZoneTopic();

    // Listen for incoming messages
    _client!.updates?.listen(_onMessagesReceived);
  }

  void _onDisconnected() {
    if (connectionStateNotifier.value != MqttConnectionState.reconnecting) {
      connectionStateNotifier.value = MqttConnectionState.disconnected;
    }
    BeaconService().addLog("MQTT Disconnected.");
  }

  void _onAutoReconnect() {
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
      final payloadStr = MqttPublishPayload.bytesToStringAsString(recMsg.payload.message);

      BeaconService().addLog("Received MQTT on [${event.topic}]: $payloadStr");

      try {
        final Map<String, dynamic> jsonMap = jsonDecode(payloadStr);
        final zoneData = ZoneResponse.fromJson(jsonMap);

        latestZoneNotifier.value = zoneData;

        // Extract website URL
        if (zoneData.website.isNotEmpty) {
          _handleWebsiteUrl(zoneData.website, zoneData.zone);
        }
      } catch (e) {
        BeaconService().addLog("Error parsing MQTT JSON: $e");
      }
    }
  }

  void _handleWebsiteUrl(String url, String zoneName) {
    final now = DateTime.now();

    // Deduplication check: Avoid re-navigating exact same URL if received within 10 seconds
    if (_lastOpenedUrl == url &&
        _lastOpenedTime != null &&
        now.difference(_lastOpenedTime!).inSeconds < 10) {
      BeaconService().addLog("Duplicate URL ($url) within 10s. Skipping navigate.");
      return;
    }

    _lastOpenedUrl = url;
    _lastOpenedTime = now;

    BeaconService().addLog("New Zone Link received ($zoneName): $url");

    if (webViewController != null) {
      try {
        BeaconService().addLog("Navigating in-app WebView to: $url");
        webViewController!.loadRequest(Uri.parse(url));
      } catch (e) {
        BeaconService().addLog("Error navigating WebView: $e");
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
    _client?.disconnect();
    connectionStateNotifier.value = MqttConnectionState.disconnected;
    BeaconService().addLog("Disconnected from MQTT Broker.");
  }
}
