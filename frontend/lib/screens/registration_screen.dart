import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../theme/app_theme.dart';

const _apiBase = ApiClient.baseUrl;

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String _membershipType = 'Regular';
  String _batch = 'Morning';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiClient.instance.post(
        '/members',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'membership_type': _membershipType,
          'batch': _batch,
          'status': 'Active',
        }),
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _formKey.currentState!.reset();
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        setState(() {
          _membershipType = 'Regular';
          _batch = 'Morning';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.surface, size: 22),
                SizedBox(width: 12),
                Expanded(child: Text('Member registered successfully!')),
              ],
            ),
          ),
        );
      } else {
        final body = response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.surface, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${body.length > 80 ? '${body.substring(0, 80)}...' : body}')),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.surface, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to register: ${e.toString().split('\n').first}')),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Member'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Full name',
                labelStyle: GoogleFonts.poppins(color: AppTheme.primary),
                hintStyle: GoogleFonts.poppins(color: Colors.grey),
              ),
              style: GoogleFonts.poppins(color: AppTheme.onSurface, fontSize: 16),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                return null;
              },
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'^\s'))],
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone',
                hintText: 'Phone number',
                labelStyle: GoogleFonts.poppins(color: AppTheme.primary),
                hintStyle: GoogleFonts.poppins(color: Colors.grey),
              ),
              style: GoogleFonts.poppins(color: AppTheme.onSurface, fontSize: 16),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone is required';
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'email@example.com',
                labelStyle: GoogleFonts.poppins(color: AppTheme.primary),
                hintStyle: GoogleFonts.poppins(color: Colors.grey),
              ),
              style: GoogleFonts.poppins(color: AppTheme.onSurface, fontSize: 16),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _membershipType,
              decoration: InputDecoration(
                labelText: 'Membership Type',
                labelStyle: GoogleFonts.poppins(color: AppTheme.primary),
              ),
              dropdownColor: AppTheme.surfaceVariant,
              style: GoogleFonts.poppins(color: AppTheme.onSurface, fontSize: 16),
              items: [
                DropdownMenuItem(value: 'Regular', child: Text('Regular', style: GoogleFonts.poppins(color: AppTheme.onSurface))),
                DropdownMenuItem(value: 'PT', child: Text('PT', style: GoogleFonts.poppins(color: AppTheme.onSurface))),
              ],
              onChanged: (v) => setState(() => _membershipType = v ?? 'Regular'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _batch,
              decoration: InputDecoration(
                labelText: 'Batch',
                labelStyle: GoogleFonts.poppins(color: AppTheme.primary),
              ),
              dropdownColor: AppTheme.surfaceVariant,
              style: GoogleFonts.poppins(color: AppTheme.onSurface, fontSize: 16),
              items: [
                DropdownMenuItem(value: 'Morning', child: Text('Morning', style: GoogleFonts.poppins(color: AppTheme.onSurface))),
                DropdownMenuItem(value: 'Evening', child: Text('Evening', style: GoogleFonts.poppins(color: AppTheme.onSurface))),
                DropdownMenuItem(value: 'Ladies', child: Text('Ladies', style: GoogleFonts.poppins(color: AppTheme.onSurface))),
              ],
              onChanged: (v) => setState(() => _batch = v ?? 'Morning'),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary),
                    )
                  : const Icon(Icons.person_add),
              label: Text(_isSubmitting ? 'Saving...' : 'Register Member'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
