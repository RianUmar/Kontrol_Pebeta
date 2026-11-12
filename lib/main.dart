// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/control_mapping_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/controller_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force portrait orientation for consistent layout
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system navigation/status bar styles
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF070B12),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize mapping service
  final mappingService = ControlMappingService();
  await mappingService.init();

  runApp(const HexapodControllerApp());
}

class HexapodControllerApp extends StatelessWidget {
  const HexapodControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PEBETA 2026',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B12),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),      // Cyber Neon Cyan
          secondary: Color(0xFFFF007F),    // Cyber Pink/Magenta
          surface: Color(0xFF111726),      // Slate Card Background
          background: Color(0xFF070B12),   // Dark space background
          error: Color(0xFFFF3D00),        // Neon Red/Orange
        ),
        textTheme: GoogleFonts.rajdhaniTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: const Color(0xFFE2E8F0),
          displayColor: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0A0F1D),
          elevation: 0,
          titleTextStyle: GoogleFonts.orbitron(
            color: const Color(0xFF00E5FF),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
          centerTitle: true,
          shape: const Border(
            bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
          ),
        ),
      ),
      home: const MainTabScreen(),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ControllerScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Start with portrait orientation for the dashboard
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    // Reset to portrait when exiting the tab screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    // Dynamically change orientation based on the selected tab
    if (index == 1) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B12), // Deep dark space background
      body: SafeArea(
        child: Stack(
          children: [
            // Centered Cyberpunk Logo Background
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.50, // Subtle transparency to stay in background
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            // Sub-screens
            IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: const Color(0xFF070B12),
          selectedItemColor: const Color(0xFF00E5FF),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          unselectedLabelStyle: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
          iconSize: 22,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.bluetooth_searching),
              activeIcon: Icon(Icons.bluetooth_connected, color: Color(0xFF00E5FF)),
              label: 'CONNECT',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gamepad_outlined),
              activeIcon: Icon(Icons.gamepad, color: Color(0xFFFF007F)),
              label: 'CONTROL',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined),
              activeIcon: Icon(Icons.tune, color: Color(0xFF00E5FF)),
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }
}
