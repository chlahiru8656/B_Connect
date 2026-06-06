import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/beacon_service.dart';

class BeaconDashboardScreen extends StatefulWidget {
  const BeaconDashboardScreen({super.key});

  @override
  State<BeaconDashboardScreen> createState() => _BeaconDashboardScreenState();
}

class _BeaconDashboardScreenState extends State<BeaconDashboardScreen> {
  final BeaconService _beaconService = BeaconService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isCopied = false;
  bool _permissionsGranted = false;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _checkInitialPermissions();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
      prefs.setBool('isDarkMode', _isDarkMode);
    });
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

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Allow custom inner Container theme color
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = _isDarkMode;
            final modalBgColor = isDark ? const Color(0xFF131124) : Colors.white;
            final textClr = isDark ? Colors.white : const Color(0xFF0F172A);
            final subTextClr = isDark ? Colors.white54 : const Color(0xFF64748B);

            return Container(
              decoration: BoxDecoration(
                color: modalBgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.settings_rounded,
                                color: textClr,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Settings",
                                style: TextStyle(
                                  color: textClr,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            color: subTextClr,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      Divider(color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 10),
                      // Theme Switcher Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                color: isDark ? Colors.cyanAccent : Colors.orangeAccent,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isDark ? "Dark Mode" : "Light Mode",
                                style: TextStyle(
                                  color: textClr,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: isDark,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) async {
                              await _toggleThemeMode();
                              setModalState(() {});
                              // Trigger rebuild of main dashboard
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _beaconService.isBroadcastingStream,
      initialData: false,
      builder: (context, snapshot) {
        final isAdvertising = snapshot.data ?? false;

        return Scaffold(
          key: _scaffoldKey,
          drawer: _buildDrawer(isAdvertising),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [
                        const Color(0xFF0F0C20), // Deep midnight blue
                        const Color(0xFF05030A), // Rich obsidian black
                      ]
                    : [
                        const Color(0xFFEBF2FF), // Soft light blue
                        const Color(0xFFF8FAFC), // Slate white
                      ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar (Safe area handled)
                    _buildHeader(),

                    const SizedBox(height: 30),

                    // Digital ID Card/Badge (Gradient & Mode Adaptive)
                    _buildDigitalBadge(),

                    // Large Broadcasting Button with Wave propagation
                    Expanded(
                      child: Center(
                        child: _buildBroadcastButton(isAdvertising),
                      ),
                    ),

                    // Free bottom space for AdMob ads
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Header Section
  Widget _buildHeader() {
    final primaryColor = _isDarkMode ? Colors.white : const Color(0xFF0F172A);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.menu_rounded, color: primaryColor, size: 28),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        Row(
          children: [
            Image.asset(
              "assets/images/logo.png",
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.blur_on, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 10),
            Text(
              "B Connect",
              style: TextStyle(
                color: primaryColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.settings_rounded, color: primaryColor, size: 26),
          onPressed: _showSettingsSheet,
        ),
      ],
    );
  }

  // Drawer Sidebar (Notch-safe and mode adaptive)
  Widget _buildDrawer(bool isAdvertising) {
    final fullUuid = _beaconService.uuid;
    final primaryColor = _isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBgColor = _isDarkMode ? const Color(0xFF1E1B33) : const Color(0xFFF8FAFC);
    final borderColor = _isDarkMode ? const Color(0xFF2E2A4F) : const Color(0xFFE2E8F0);

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isDarkMode
                ? [const Color(0xFF1E1B33), const Color(0xFF0F0C20)]
                : [Colors.white, const Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Drawer Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                color: _isDarkMode ? const Color(0xFF131124) : const Color(0xFFF1F5F9),
                child: Row(
                  children: [
                    Icon(Icons.menu_open_rounded, color: primaryColor, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      "Menu & Settings",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: secondaryColor,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Drawer Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  children: [
                    // 1. Connection Status
                    Text(
                      "CONNECTION STATUS",
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _permissionsGranted ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _permissionsGranted ? "Authorized" : "Awaiting Authorization",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. Full Security Identity (UUID) - Unmasked
                    Text(
                      "FULL SECURITY IDENTITY (UUID)",
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullUuid,
                              style: TextStyle(
                                color: _isDarkMode ? Colors.white70 : const Color(0xFF334155),
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _copyToClipboard,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isCopied
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : const Color(0xFF2563EB).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isCopied ? const Color(0xFF10B981) : const Color(0xFF2563EB).withOpacity(0.2),
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Icon(
                                  _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                                  key: ValueKey<bool>(_isCopied),
                                  color: _isCopied ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 3. BLE Permissions
                    Text(
                      "DEVICE BLE PERMISSIONS",
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _permissionsGranted
                                  ? "Bluetooth & location permissions are active."
                                  : "Permissions needed to scan/broadcast.",
                              style: TextStyle(
                                color: _isDarkMode ? Colors.white70 : const Color(0xFF334155),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (!_permissionsGranted)
                            TextButton(
                              onPressed: _requestPermissions,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: const BorderSide(color: Color(0xFF2563EB)),
                                ),
                              ),
                              child: const Text(
                                "Authorize",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 4. Transmission Feed / Activity Logs Console
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (isAdvertising)
                              const RunningBlinkDot()
                            else
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              "TRANSMISSION FEED",
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            _beaconService.logsNotifier.value = [];
                          },
                          child: Row(
                            children: const [
                              Icon(Icons.delete_sweep_outlined, size: 14, color: Colors.redAccent),
                              SizedBox(width: 4),
                              Text(
                                "CLEAR",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF07050F) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ValueListenableBuilder<List<String>>(
                        valueListenable: _beaconService.logsNotifier,
                        builder: (context, logs, child) {
                          if (logs.isEmpty) {
                            return const Center(
                              child: Text(
                                "No logs recorded.",
                                style: TextStyle(
                                  color: Colors.white30,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              final isError = log.contains('Error') || log.contains('denied') || log.contains('MISSING');
                              final isSuccess = log.contains('active') || log.contains('granted') || log.contains('Initialized');
                              
                              Color textColor = Colors.white70;
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
                                    fontSize: 9.5,
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
              ),

              // 5. Version Info at bottom
              Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: borderColor),
                  ),
                ),
                child: const Center(
                  child: Text(
                    "Version v1.0.0",
                    style: TextStyle(
                      color: Color(0xFF94A3B8), // Slate 400
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Digital Badge Widget (Gradient Card with soft shadow)
  Widget _buildDigitalBadge() {
    final fullUuid = _beaconService.uuid;
    final suffixId = fullUuid.length >= 4 ? fullUuid.substring(fullUuid.length - 4) : fullUuid;
    final secondaryColor = _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = _isDarkMode ? const Color(0xFF2E2A4F) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [
                  const Color(0xFF1E1B33), // Deep indigo
                  const Color(0xFF131124), // Slate obsidian
                ]
              : [
                  Colors.white,
                  const Color(0xFFF1F5F9), // Slate gray bottom-right tint
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              "assets/images/logo.png",
              width: 42,
              height: 42,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 42,
                height: 42,
                color: const Color(0xFF2563EB).withOpacity(0.1),
                child: const Icon(Icons.blur_on, color: Color(0xFF2563EB), size: 24),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "DEVICE SUFFIX ID",
            style: TextStyle(
              color: secondaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                suffixId.toUpperCase(),
                style: TextStyle(
                  color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "(Suffix)",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white30 : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Emoji-Based Broadcast Trigger Button with wave ripple propagation
  Widget _buildBroadcastButton(bool isAdvertising) {
    final offlineBgColor = _isDarkMode ? const Color(0xFF1E1B33) : const Color(0xFFE2E8F0);
    final offlineBorderColor = _isDarkMode ? const Color(0xFF2E2A4F) : const Color(0xFFCBD5E1);
    final offlineTextColor = _isDarkMode ? Colors.white70 : const Color(0xFF334155);
    final activeRippleColor = _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF2563EB);

    return WaveRippleEffect(
      isAdvertising: isAdvertising,
      rippleColor: activeRippleColor,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isAdvertising
              ? [
                  BoxShadow(
                    color: activeRippleColor.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    spreadRadius: 1,
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
                color: isAdvertising ? const Color(0xFF2563EB) : offlineBgColor,
                border: Border.all(
                  color: isAdvertising ? const Color(0xFF1D4ED8) : offlineBorderColor,
                  width: 2.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedEmoji(isAdvertising: isAdvertising),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      isAdvertising ? "BROADCASTING" : "TAP TO CONNECT",
                      key: ValueKey<bool>(isAdvertising),
                      style: TextStyle(
                        color: isAdvertising ? Colors.white : offlineTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      isAdvertising ? "ACTIVE" : "OFFLINE",
                      key: ValueKey<bool>(isAdvertising),
                      style: TextStyle(
                        color: isAdvertising ? const Color(0xFF93C5FD) : const Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Bouncing/Rocking Custom Animated Emoji with smooth AnimatedSwitcher transitions
class AnimatedEmoji extends StatefulWidget {
  final bool isAdvertising;

  const AnimatedEmoji({super.key, required this.isAdvertising});

  @override
  State<AnimatedEmoji> createState() => _AnimatedEmojiState();
}

class _AnimatedEmojiState extends State<AnimatedEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotationAnimation = Tween<double>(begin: -0.12, end: 0.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _bounceAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedEmoji oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAdvertising != oldWidget.isAdvertising) {
      if (widget.isAdvertising) {
        // Fast oscillation for active transmission
        _controller.duration = const Duration(milliseconds: 700);
      } else {
        // Slow gentle sleep oscillation
        _controller.duration = const Duration(seconds: 2);
      }
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Text(
                widget.isAdvertising ? "📡" : "💤",
                key: ValueKey<bool>(widget.isAdvertising),
                style: const TextStyle(fontSize: 54),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Spreading Expanding Wave / Ripple Propagation Effect
class WaveRippleEffect extends StatefulWidget {
  final Widget child;
  final bool isAdvertising;
  final Color rippleColor;

  const WaveRippleEffect({
    super.key,
    required this.child,
    required this.isAdvertising,
    required this.rippleColor,
  });

  @override
  State<WaveRippleEffect> createState() => _WaveRippleEffectState();
}

class _WaveRippleEffectState extends State<WaveRippleEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isAdvertising) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaveRippleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAdvertising != oldWidget.isAdvertising) {
      if (widget.isAdvertising) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!widget.isAdvertising) {
          return widget.child;
        }

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Wave 1
            _buildWave(0.0),
            // Wave 2
            _buildWave(0.33),
            // Wave 3
            _buildWave(0.66),
            widget.child,
          ],
        );
      },
    );
  }

  Widget _buildWave(double delay) {
    double progress = (_controller.value + delay) % 1.0;
    double size = 180 + (progress * 130); // Ripple expands from 180px to 310px
    double opacity = (1.0 - progress) * 0.45; // Fade out as progress increases

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.rippleColor.withOpacity(opacity),
        border: Border.all(
          color: widget.rippleColor.withOpacity(opacity * 0.8),
          width: 1.5,
        ),
      ),
    );
  }
}

// Simple internal helper class for the drawer blinking dot animation
class RunningBlinkDot extends StatefulWidget {
  const RunningBlinkDot({super.key});

  @override
  State<RunningBlinkDot> createState() => _RunningBlinkDotState();
}

class _RunningBlinkDotState extends State<RunningBlinkDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
