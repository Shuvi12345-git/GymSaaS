import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../theme/app_theme.dart';
import 'member_home_screen.dart';

const _apiBase = ApiClient.baseUrl;
const _padding = 20.0;

class MemberLoginScreen extends StatefulWidget {
  const MemberLoginScreen({super.key});

  @override
  State<MemberLoginScreen> createState() => _MemberLoginScreenState();
}

class _MemberLoginScreenState extends State<MemberLoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() { _otpSent = true; _loading = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP sent (simulated). Use 123456 to login.')),
    );
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiClient.instance.get('/members/by-phone/${Uri.encodeComponent(phone)}', useCache: false);
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final member = jsonDecode(r.body) as Map<String, dynamic>;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MemberHomeScreen(member: member)),
        );
      } else {
        setState(() { _error = 'Member not found or invalid phone'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().split('\n').first; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Member Login', style: GoogleFonts.poppins(color: AppTheme.onSurface)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.onSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 80,
                  width: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fitness_center, color: AppTheme.primary, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Sign in with your registered phone', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 14)),
                const SizedBox(height: 16),
              ],
              if (!_otpSent)
                FilledButton(
                  onPressed: _loading ? null : _requestOtp,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary)) : const Text('Request OTP'),
                )
              else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'OTP (use 123456)'),
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary)) : const Text('Login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
