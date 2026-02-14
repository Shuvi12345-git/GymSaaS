import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'member_home_screen.dart';

const _apiBase = 'http://localhost:8000';
const _deepBlack = Color(0xFF0D0D0D);
const _gold = Color(0xFFD4AF37);
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
      final r = await http.get(Uri.parse('$_apiBase/members/by-phone/${Uri.encodeComponent(phone)}')).timeout(const Duration(seconds: 10));
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
      appBar: AppBar(
        title: Text('Member Login', style: GoogleFonts.poppins()),
        backgroundColor: _deepBlack,
        foregroundColor: _gold,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text('Sign in with your registered phone', style: GoogleFonts.poppins(color: Colors.grey.shade400)),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                ),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: GoogleFonts.poppins(color: Colors.red, fontSize: 14)),
                const SizedBox(height: 16),
              ],
              if (!_otpSent)
                FilledButton(
                  onPressed: _loading ? null : _requestOtp,
                  style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepBlack, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _deepBlack)) : const Text('Request OTP'),
                )
              else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'OTP (use 123456)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                  ),
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepBlack, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _deepBlack)) : const Text('Login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
