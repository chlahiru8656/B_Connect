import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/mqtt_service.dart';

/// A separate native WebView, owned only by this route.
class ColorShowScreen extends StatefulWidget {
  const ColorShowScreen({super.key});

  @override
  State<ColorShowScreen> createState() => _ColorShowScreenState();
}

class _ColorShowScreenState extends State<ColorShowScreen> {
  static const _windowChannel = MethodChannel('com.creativech.bconnect/color_show');
  final _mqtt = MqttService();
  late final WebViewController _controller;
  String? _url;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _setWindowActive(true);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          if (mounted && url == _url) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true) {
            setState(() {
              _loading = false;
              _error = 'Unable to load the color show. Check your connection.';
            });
          }
        },
      ));
    _mqtt.latestZoneNotifier.addListener(_onZone);
    _onZone();
  }

  Future<void> _setWindowActive(bool active) async {
    if (!Platform.isAndroid) return;
    try {
      await _windowChannel.invokeMethod<void>('setActive', active);
    } on PlatformException catch (error) {
      debugPrint('Color show window configuration failed: $error');
    } on MissingPluginException {
      debugPrint('Rebuild the Android app to enable immersive color shows.');
    }
  }

  void _onZone() {
    final url = _mqtt.latestZoneNotifier.value?.website;
    if (url == null || url.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      });
      return;
    }
    if (url == _url) return;
    _url = url;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _controller.loadRequest(Uri.parse(_url!));
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to open the color show.';
        });
      }
    }
  }

  @override
  void dispose() {
    _setWindowActive(false);
    _mqtt.latestZoneNotifier.removeListener(_onZone);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller),
          if (_loading || _error != null)
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.white)),
                          TextButton(onPressed: _load, child: const Text('Retry')),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Back'),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}



