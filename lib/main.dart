import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'app_colors.dart';
import 'services/auth_services.dart';
import 'services/notification_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/complete_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // start the local notifications
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eventhub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

// ------------------------------------------------------------
// DECIDES WHERE THE APP STARTS
// ------------------------------------------------------------
// - nobody logged in          -> WelcomeScreen
// - profile not finished yet  -> CompleteProfileScreen (new Google users)
// - completed profile         -> HomeScreen (returning users skip the form)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _decideWhereToGo();
  }

  Future<void> _decideWhereToGo() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _setDestination(const WelcomeScreen());
      return;
    }

    try {
      // returning students with a saved profile go straight home;
      // brand new Google users still need the short profile form
      bool complete = await AuthService().hasCompletedProfile(user);
      _setDestination(
          complete ? const HomeScreen() : const CompleteProfileScreen());
    } catch (_) {
      // offline or Firestore unavailable — don't lock the student out
      _setDestination(const HomeScreen());
    }
  }

  void _setDestination(Widget destination) {
    if (!mounted) return;
    setState(() {
      _destination = destination;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_destination != null) return _destination!;

    // short check: white screen with the app logo
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, color: AppColors.primary, size: 44),
            SizedBox(height: 14),
            CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
