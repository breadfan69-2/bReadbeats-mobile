import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/connection_provider.dart';
import 'screens/home_screen.dart';
import 'screens/setup_wizard_screen.dart';
import 'widgets/neumorphic_tile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BreadbeatsMobileApp());
}

class BreadbeatsMobileApp extends StatefulWidget {
  const BreadbeatsMobileApp({super.key});

  @override
  State<BreadbeatsMobileApp> createState() => _BreadbeatsMobileAppState();
}

class _BreadbeatsMobileAppState extends State<BreadbeatsMobileApp>
    with WidgetsBindingObserver {
  final _provider = ConnectionProvider();
  bool? _setupComplete;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSetupWizard();
  }

  Future<void> _checkSetupWizard() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _setupComplete = prefs.getBool(SetupWizardScreen.prefsKey) ?? false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _provider.stopAudioCapture(releaseProjection: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ConnectionProvider>.value(
      value: _provider,
      child: MaterialApp(
        title: 'bREadbeats Mobile',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00AAFF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: kNeumorphicBase,
          snackBarTheme: SnackBarThemeData(
            backgroundColor: kNeumorphicLighter,
            contentTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: kAccentCyan.withValues(alpha: 0.25)),
            ),
            behavior: SnackBarBehavior.floating,
            elevation: 0,
          ),
        ),
        themeMode: ThemeMode.dark,
        home: _setupComplete == null
            ? const Scaffold(
                backgroundColor: Color(0xFF1A1A2E),
                body: Center(child: CircularProgressIndicator()),
              )
            : _setupComplete!
            ? const HomeScreen()
            : const SetupWizardScreen(),
      ),
    );
  }
}
