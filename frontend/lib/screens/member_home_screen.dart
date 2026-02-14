import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

const _apiBase = 'http://localhost:8000';
const _deepBlack = Color(0xFF0D0D0D);
const _gold = Color(0xFFD4AF37);
const _padding = 20.0;

class MemberHomeScreen extends StatefulWidget {
  final Map<String, dynamic> member;

  const MemberHomeScreen({super.key, required this.member});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  List<dynamic> _payments = [];
  bool _loadingPayments = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final mid = widget.member['id'] as String?;
    if (mid == null) return;
    setState(() => _loadingPayments = true);
    try {
      final r = await http.get(Uri.parse('$_apiBase/payments?member_id=$mid')).timeout(const Duration(seconds: 10));
      if (mounted && r.statusCode >= 200 && r.statusCode < 300)
        setState(() { _payments = jsonDecode(r.body) as List<dynamic>; _loadingPayments = false; });
      else if (mounted) setState(() => _loadingPayments = false);
    } catch (_) {
      if (mounted) setState(() => _loadingPayments = false);
    }
  }

  bool get _isPT => (widget.member['membership_type'] as String? ?? '').toLowerCase() == 'pt';

  @override
  Widget build(BuildContext context) {
    final name = widget.member['name'] as String? ?? '';
    final batch = widget.member['batch'] as String? ?? '';
    final status = widget.member['status'] as String? ?? 'Active';
    final workoutSchedule = widget.member['workout_schedule'] as String? ?? '';
    final dietChart = widget.member['diet_chart'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('My Gym', style: GoogleFonts.poppins()),
        backgroundColor: _deepBlack,
        foregroundColor: _gold,
      ),
      body: Padding(
        padding: const EdgeInsets.all(_padding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _gold)),
                child: Padding(
                  padding: const EdgeInsets.all(_padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Batch: $batch', style: GoogleFonts.poppins(color: _gold)),
                      Text('Status: $status', style: GoogleFonts.poppins(color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_isPT) ...[
                if (workoutSchedule.isNotEmpty) ...[
                  Text('Workout Schedule', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 8),
                  Card(
                    color: const Color(0xFF1A1A1A),
                    child: Padding(
                      padding: const EdgeInsets.all(_padding),
                      child: SelectableText(workoutSchedule, style: GoogleFonts.poppins(color: Colors.grey.shade300)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (dietChart.isNotEmpty) ...[
                  Text('Diet Chart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 8),
                  Card(
                    color: const Color(0xFF1A1A1A),
                    child: Padding(
                      padding: const EdgeInsets.all(_padding),
                      child: SelectableText(dietChart, style: GoogleFonts.poppins(color: Colors.grey.shade300)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (workoutSchedule.isEmpty && dietChart.isEmpty)
                  Text('No schedule or diet assigned yet.', style: GoogleFonts.poppins(color: Colors.grey)),
              ] else ...[
                Text('Workout Planner', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ['Chest Day', 'Leg Day', 'Back Day', 'Shoulder Day', 'Arm Day', 'Full Body'].map((preset) {
                    return ActionChip(
                      label: Text(preset),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected: $preset'))),
                      backgroundColor: _gold.withOpacity(0.2),
                      side: const BorderSide(color: _gold),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              Text('Pay Fees', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 12),
              if (_loadingPayments)
                const Center(child: CircularProgressIndicator(color: _gold))
              else
                ...(_payments.where((p) => (p['status'] == 'Due' || p['status'] == 'Overdue')).map((p) {
                  final map = p as Map<String, dynamic>;
                  return Card(
                    color: const Color(0xFF1A1A1A),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${map['fee_type']} • ₹${map['amount']}', style: GoogleFonts.poppins(color: Colors.white)),
                      subtitle: Text('${map['status']}', style: TextStyle(color: _gold)),
                      trailing: FilledButton(
                        onPressed: () => _showPayDialog(map),
                        style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepBlack),
                        child: const Text('Pay'),
                      ),
                    ),
                  );
                })),
              if (_payments.where((p) => (p['status'] == 'Due' || p['status'] == 'Overdue')).isEmpty && !_loadingPayments)
                Text('No pending fees.', style: GoogleFonts.poppins(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Pay ₹${payment['amount']}', style: GoogleFonts.poppins(color: _gold)),
        content: Text('Simulated payment (Razorpay/Stripe). Confirm to mark as paid.', style: GoogleFonts.poppins(color: Colors.grey.shade300)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final mid = widget.member['id'] as String?;
              final pid = payment['id'] as String?;
              if (mid == null || pid == null) return;
              try {
                final r = await http.post(
                  Uri.parse('$_apiBase/payments/pay?member_id=$mid&payment_id=$pid'),
                ).timeout(const Duration(seconds: 10));
                if (mounted && r.statusCode >= 200 && r.statusCode < 300) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully!')));
                  _loadPayments();
                }
              } catch (_) {}
            },
            style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepBlack),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
