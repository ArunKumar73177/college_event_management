import 'package:flutter/material.dart';
import 'login.dart';
import 'organizer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCRIET Events',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // Define routes for navigation
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/organizer': (context) => const OrganizerDashboard(),
        // Add more routes here as you create more dashboards
        // '/student': (context) => const StudentDashboard(),
        // '/admin': (context) => const AdminDashboard(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  void _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // You can replace this with your logo
            Icon(
              Icons.event,
              size: 120,
              color: Colors.blue[700],
            ),
            const SizedBox(height: 24),
            const Text(
              'SCRIET Events',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Event Management System',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to make navigation easier throughout the app
extension NavigationExtension on BuildContext {
  // Navigate to login
  void navigateToLogin() {
    Navigator.pushReplacementNamed(this, '/login');
  }

  // Navigate to organizer dashboard
  void navigateToOrganizer() {
    Navigator.pushReplacementNamed(this, '/organizer');
  }

// Add more navigation helpers as needed
// void navigateToStudent() {
//   Navigator.pushReplacementNamed(this, '/student');
// }

// void navigateToAdmin() {
//   Navigator.pushReplacementNamed(this, '/admin');
// }
}