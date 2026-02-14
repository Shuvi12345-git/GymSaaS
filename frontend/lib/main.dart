import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'screens/admin_dashboard_screen.dart';
import 'screens/attendance_report_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/member_login_screen.dart';
import 'screens/registration_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const deepBlack = Color(0xFF0D0D0D);
    const gold = Color(0xFFD4AF37);
    const goldLight = Color(0xFFE8C547);

    return MaterialApp(
      title: 'GymSaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: deepBlack,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.dark(
          primary: gold,
          onPrimary: deepBlack,
          surface: deepBlack,
          onSurface: Colors.white,
          secondary: goldLight,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: deepBlack,
          foregroundColor: gold,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: deepBlack,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: deepBlack,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: gold),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: gold, width: 2)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade600)),
          border: const OutlineInputBorder(),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: gold,
          contentTextStyle: const TextStyle(
            color: Color(0xFF0D0D0D),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const MyHomePage(title: 'Gym SaaS'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isPinging = false;

  Future<void> _pingServer() async {
    if (_isPinging) return;
    setState(() => _isPinging = true);

    try {
      final response = await http
          .get(Uri.parse('http://localhost:8000/'))
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['message'] as String? ?? 'Gym API is Live!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF0D0D0D), size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFF0D0D0D), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Server unreachable: ${e.toString().split('\n').first}'),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPinging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fitness_center, color: Color(0xFF0D0D0D)),
          ),
        ),
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            ElevatedButton.icon(
              onPressed: _isPinging ? null : _pingServer,
              icon: _isPinging
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0D0D0D),
                      ),
                    )
                  : const Icon(Icons.wifi_find, size: 22),
              label: Text(_isPinging ? 'Pinging...' : 'Ping Gym Server'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegistrationScreen()),
              ),
              icon: const Icon(Icons.person_add, size: 22),
              label: const Text('Register Member'),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              ),
              icon: const Icon(Icons.dashboard, size: 22),
              label: const Text('Admin Dashboard'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AttendanceReportScreen()),
              ),
              icon: const Icon(Icons.calendar_today, size: 22),
              label: const Text('Today\'s Attendance'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MemberLoginScreen()),
              ),
              icon: const Icon(Icons.login, size: 22),
              label: const Text('Member Login'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
