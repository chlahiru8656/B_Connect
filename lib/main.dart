import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/beacon_dashboard_screen.dart';
import 'services/beacon_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations (portrait only for premium layout lock)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system navigation overlay styles
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0C0A15),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize the BLE Beacon Service (generates/loads UUID)
  final BeaconService beaconService = BeaconService();
  await beaconService.init();

  runApp(const BleBeaconApp());
}

class BleBeaconApp extends StatelessWidget {
  const BleBeaconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital ID Beacon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFF0C0A15),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const BeaconDashboardScreen(),
    );
  }
}
