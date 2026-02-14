import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const _apiBase = 'http://localhost:8000';
const _deepBlack = Color(0xFF0D0D0D);
const _gold = Color(0xFFD4AF37);

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
      final response = await http
          .post(
            Uri.parse('$_apiBase/members'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'email': _emailController.text.trim(),
              'membership_type': _membershipType,
              'batch': _batch,
              'status': 'Active',
            }),
          )
          .timeout(const Duration(seconds: 10));

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
                Icon(Icons.check_circle, color: _deepBlack, size: 22),
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
                const Icon(Icons.error_outline, color: _deepBlack, size: 22),
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
              const Icon(Icons.error_outline, color: _deepBlack, size: 22),
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
    final theme = Theme.of(context);

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
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Full name',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _gold, width: 2)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                labelStyle: TextStyle(color: _gold),
              ),
              style: const TextStyle(color: Colors.white),
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
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: 'Phone number',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _gold, width: 2)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                labelStyle: TextStyle(color: _gold),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone is required';
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'email@example.com',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _gold, width: 2)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                labelStyle: TextStyle(color: _gold),
              ),
              style: const TextStyle(color: Colors.white),
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
              decoration: const InputDecoration(
                labelText: 'Membership Type',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _gold, width: 2)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                labelStyle: TextStyle(color: _gold),
              ),
              dropdownColor: _deepBlack,
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'Regular', child: Text('Regular')),
                DropdownMenuItem(value: 'PT', child: Text('PT')),
              ],
              onChanged: (v) => setState(() => _membershipType = v ?? 'Regular'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _batch,
              decoration: const InputDecoration(
                labelText: 'Batch',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _gold, width: 2)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                labelStyle: TextStyle(color: _gold),
              ),
              dropdownColor: _deepBlack,
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                DropdownMenuItem(value: 'Ladies', child: Text('Ladies')),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: _deepBlack),
                    )
                  : const Icon(Icons.person_add),
              label: Text(_isSubmitting ? 'Saving...' : 'Register Member'),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _deepBlack,
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
