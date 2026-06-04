import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Imports for beacon service.
import '../services/beacon_service.dart';

class BeaconDashboardScreen extends StatefulWidget {
  const BeaconDashboardScreen({super.key});

  @override
  State<BeaconDashboardScreen> createState() => _BeaconDashboardScreenState();
}

class _BeaconDashboardScreenState extends State<BeaconDashboardScreen>
    with TickerProviderStateMixin {
  final BeaconService _beaconService = BeaconService();

  // Animation controllers for premium visual effects
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  bool _isCopied = false;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the glowing broadcasting button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 16.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Blinking animation for the transmission feed dot
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(_blinkController);

    // Check permissions on startup
    _checkInitialPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialPermissions() async {
    final granted = await _beaconService.checkPermissions();
    if (mounted) {
      setState(() {
        _permissionsGranted = granted;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await _beaconService.requestPermissions();
    if (mounted) {
      setState(() {
        _permissionsGranted = granted;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _beaconService.uuid));
    setState(() {
      _isCopied = true;
    });
    _beaconService.addLog("Copied Device UUID to clipboard.");
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A15), // Deep obsidian background
      body: StreamBuilder<bool>(
        stream: _beaconService.isBroadcastingStream,
        initialData: false,
        builder: (context, snapshot) {
          final isAdvertising = snapshot.data ?? false;

          // Manage pulse animation based on broadcasting state
          if (isAdvertising) {
            if (!_pulseController.isAnimating) {
              _pulseController.repeat(reverse: true);
            }
          } else {
            _pulseController.stop();
            _pulseController.value = 0.0;
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0C0A15),
                  Color(0xFF160E2C),
                  Color(0xFF0C0A15),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    _buildHeader(),

                    const SizedBox(height: 20),

                    // Digital ID Card/Badge (Glassmorphic)
                    _buildDigitalBadge(),

                    const SizedBox(height: 30),

                    // Large Glowing Broadcasting Button
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: _buildBroadcastButton(isAdvertising),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Permission Panel
                    _buildPermissionPanel(),

                    const SizedBox(height: 20),

                    // Activity Logs Console
                    Expanded(
                      flex: 3,
                      child: _buildLogConsole(isAdvertising),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Header Section
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "DIGITAL ID BADGE",
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(
                    color: Colors.purple.withOpacity(0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 80,
              height: 3,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purpleAccent, Colors.cyanAccent],
                ),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
        Icon(
          Icons.nfc_outlined,
          color: Colors.cyanAccent.withOpacity(0.8),
          size: 28,
        ),
      ],
    );
  }

  // Glassmorphic Digital Badge Widget
  Widget _buildDigitalBadge() {
    return Container(
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge chip & signal indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.network(
                "https://cdn-icons-png.flaticon.com/512/6404/6404106.png", // Chip graphics placeholder
                width: 45,
                height: 45,
                color: Colors.amberAccent.withOpacity(0.85),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 45,
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amberAccent, width: 1),
                    ),
                    child: const Icon(Icons.developer_board, color: Colors.amberAccent, size: 20),
                  );
                },
              ),
              const Icon(
                Icons.wifi_tethering,
                color: Colors.cyanAccent,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            "SECURE TRANSMISSION IDENTITY",
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          // Readable UUID block
          Row(
            children: [
              Expanded(
                child: Text(
                  _beaconService.uuid,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Copy Button
              GestureDetector(
                onTap: _copyToClipboard,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isCopied
                        ? const Color(0xFF10B981).withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isCopied
                          ? const Color(0xFF10B981).withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Icon(
                    _isCopied ? Icons.check_circle_outline : Icons.copy_rounded,
                    color: _isCopied ? const Color(0xFF10B981) : Colors.cyanAccent,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "STATUS",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _permissionsGranted ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _permissionsGranted ? "Authorized" : "Awaiting Auth",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Text(
                "v1.0.0",
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  // Large Broadcast Trigger Button
  Widget _buildBroadcastButton(bool isAdvertising) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isAdvertising
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.3),
                      blurRadius: 15 + _pulseAnimation.value,
                      spreadRadius: 2 + _pulseAnimation.value / 3,
                    ),
                    BoxShadow(
                      color: Colors.purpleAccent.withOpacity(0.2),
                      blurRadius: 25 + _pulseAnimation.value,
                      spreadRadius: 5 + _pulseAnimation.value / 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (isAdvertising) {
                  await _beaconService.stopBroadcasting();
                } else {
                  await _beaconService.startBroadcasting();
                }
              },
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: isAdvertising
                        ? [
                            const Color(0xFF1E5275), // Glowing blue-cyan
                            const Color(0xFF0F1836),
                          ]
                        : [
                            const Color(0xFF281C4E), // Subdued violet
                            const Color(0xFF0F0A1F),
                          ],
                    radius: 0.85,
                  ),
                  border: Border.all(
                    color: isAdvertising
                        ? Colors.cyanAccent.withOpacity(0.8)
                        : Colors.purpleAccent.withOpacity(0.3),
                    width: 2.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAdvertising ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                      color: isAdvertising ? Colors.cyanAccent : Colors.purpleAccent.withOpacity(0.7),
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isAdvertising ? "BROADCASTING" : "TAP TO START",
                      style: TextStyle(
                        color: isAdvertising ? Colors.cyanAccent : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdvertising ? "ACTIVE" : "OFFLINE",
                      style: TextStyle(
                        color: isAdvertising ? Colors.greenAccent : Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Permission Section
  Widget _buildPermissionPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _permissionsGranted ? Icons.security : Icons.warning_amber_rounded,
                color: _permissionsGranted ? Colors.green : Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Device BLE Permissions",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _permissionsGranted
                        ? "Bluetooth & location access granted."
                        : "Permissions required to scan and broadcast.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!_permissionsGranted)
            ElevatedButton(
              onPressed: _requestPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                foregroundColor: Colors.purpleAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.purpleAccent, width: 1),
                ),
              ),
              child: const Text(
                "Authorize",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          else
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 20,
            ),
        ],
      ),
    );
  }

  // Terminal console logger UI
  Widget _buildLogConsole(bool isAdvertising) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF05050A), // Jet-black terminal color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdvertising
              ? Colors.cyanAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Console Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(
                color: Colors.white.withOpacity(0.04),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Blinking dot when broadcasting
                    if (isAdvertising)
                      AnimatedBuilder(
                        animation: _blinkAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _blinkAnimation.value,
                            child: Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      isAdvertising ? "TRANSMISSION FEED" : "STATUS LOGGER",
                      style: TextStyle(
                        color: isAdvertising ? Colors.cyanAccent : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    // Reset logs list (only in notifier list representation)
                    _beaconService.logsNotifier.value = [];
                  },
                  child: Text(
                    "CLEAR",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Console body
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _beaconService.logsNotifier,
              builder: (context, logs, child) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No activity log recorded.",
                      style: TextStyle(
                        color: Colors.white24,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isError = log.contains('Error') || log.contains('denied') || log.contains('MISSING');
                    final isSuccess = log.contains('active') || log.contains('granted') || log.contains('Initialized');
                    
                    Color textColor = Colors.white54;
                    if (isError) {
                      textColor = Colors.redAccent;
                    } else if (isSuccess) {
                      textColor = Colors.greenAccent;
                    } else if (log.contains('Configuring') || log.contains('Starting')) {
                      textColor = Colors.cyanAccent;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
