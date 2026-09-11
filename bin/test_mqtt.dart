import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() async {
  print("Testing MQTT connections to broker.emqx.io...");

  // Test 1: Port 1883 (Raw TCP Unencrypted)
  await testPort1883();

  // Test 2: Port 8883 (MQTTS TLS)
  await testPort8883();

  // Test 3: Port 8084 (WSS WebSocket Secure)
  await testPort8084();

  exit(0);
}

Future<void> testPort1883() async {
  print("\n--- Testing Port 1883 (Standard TCP) ---");
  final id = 'test_1883_${DateTime.now().millisecondsSinceEpoch}';
  final client = MqttServerClient.withPort('broker.emqx.io', id, 1883);
  client.logging(on: false);
  client.keepAlivePeriod = 20;
  client.connectTimeoutPeriod = 5000;

  final connMessage = MqttConnectMessage()
      .withClientIdentifier(id)
      .startClean();
  client.connectionMessage = connMessage;

  try {
    final status = await client.connect();
    print("Port 1883 status: ${status?.state}");
    if (status?.state == MqttConnectionState.connected) {
      print("SUCCESS: Port 1883 Connected!");
      client.disconnect();
    }
  } catch (e) {
    print("FAILED Port 1883: $e");
  }
}

Future<void> testPort8883() async {
  print("\n--- Testing Port 8883 (TLS/MQTTS) ---");
  final id = 'test_8883_${DateTime.now().millisecondsSinceEpoch}';
  final client = MqttServerClient.withPort('broker.emqx.io', id, 8883);
  client.secure = true;
  client.securityContext = SecurityContext.defaultContext;
  client.onBadCertificate = (dynamic cert) => true;
  client.logging(on: false);
  client.keepAlivePeriod = 20;
  client.connectTimeoutPeriod = 5000;

  try {
    final status = await client.connect();
    print("Port 8883 status: ${status?.state}");
    if (status?.state == MqttConnectionState.connected) {
      print("SUCCESS: Port 8883 Connected!");
      client.disconnect();
    }
  } catch (e) {
    print("FAILED Port 8883: $e");
  }
}

Future<void> testPort8084() async {
  print("\n--- Testing Port 8084 (WSS WebSocket Secure) ---");
  final id = 'test_8084_${DateTime.now().millisecondsSinceEpoch}';
  final client = MqttServerClient.withPort('broker.emqx.io', id, 8084);
  client.useWebSocket = true;
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

  client.logging(on: false);
  client.keepAlivePeriod = 20;
  client.connectTimeoutPeriod = 5000;

  try {
    final status = await client.connect();
    print("Port 8084 status: ${status?.state}");
    if (status?.state == MqttConnectionState.connected) {
      print("SUCCESS: Port 8084 Connected!");
      client.disconnect();
    }
  } catch (e) {
    print("FAILED Port 8084: $e");
  }
}
