import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'theme/app_theme.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/attendance_report_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/member_login_screen.dart';
import 'screens/registration_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jupiter Arena',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MyHomePage(title: 'Jupiter Arena'),
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

  @override
  void initState() {
    super.initState();
    ApiClient.loadSavedBaseUrl(() async =>
        (await SharedPreferences.getInstance()).getString(ApiClient.prefsKey))
        .then((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/logo.png'), context);
    });
  }

  Future<void> _showSetServerUrlDialog() async {
    final controller = TextEditingController(text: ApiClient.baseUrl);
    if (!mounted) return;
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set server URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://your-backend.up.railway.app',
            border: OutlineInputBorder(),
          ),
          autocorrect: false,
          keyboardType: TextInputType.url,
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated != true || !mounted) return;
    final url = controller.text.trim();
    if (url.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiClient.prefsKey, url);
    ApiClient.overrideBaseUrl = url;
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Server URL set to $url')),
    );
  }

  Future<void> _pingServer() async {
    if (_isPinging) return;
    setState(() => _isPinging = true);

    try {
      final response = await ApiClient.instance.get('/', useCache: false);

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
      final url = ApiClient.baseUrl;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFF0D0D0D), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Server unreachable. URL: $url — ${e.toString().split('\n').first}'),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
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
          padding: const EdgeInsets.all(8),
          child: _JupiterLogo(size: 40),
        ),
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      ApiClient.baseUrl,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: _showSetServerUrlDialog,
                    child: const Text('Set server URL'),
                  ),
                ],
              ),
            ),
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
                MaterialPageRoute(builder: (_) => const DashboardScreen(isEmbedded: false)),
              ),
              icon: const Icon(Icons.how_to_reg, size: 22),
              label: const Text('Check-In'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegistrationScreen()),
              ),
              icon: const Icon(Icons.person_add, size: 22),
              label: const Text('Register Member'),
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
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              ),
              icon: const Icon(Icons.admin_panel_settings, size: 22),
              label: const Text('Admin Login'),
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
      ),
    );
  }
}

/// Jupiter Arena logo: asset or placeholder.
class _JupiterLogo extends StatelessWidget {
  final double size;

  const _JupiterLogo({this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      height: size,
      width: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.fitness_center, color: AppTheme.primary, size: size * 0.6),
      ),
    );
  }
}
