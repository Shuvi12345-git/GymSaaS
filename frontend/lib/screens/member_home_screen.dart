import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../theme/app_theme.dart';

final _apiBase = ApiClient.baseUrl;
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
      final r = await ApiClient.instance.get('/payments', queryParameters: {'member_id': mid}, useCache: false);
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
    final lastAttendance = widget.member['last_attendance_date'] as String? ?? '';
    final workoutSchedule = widget.member['workout_schedule'] as String? ?? '';
    final dietChart = widget.member['diet_chart'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 28, width: 28, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center, color: AppTheme.primary, size: 24)),
            const SizedBox(width: 8),
            Text('Jupiter Arena', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
          ],
        ),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.onSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(_padding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: AppTheme.surfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppTheme.primary.withOpacity(0.5))),
                child: Padding(
                  padding: const EdgeInsets.all(_padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
                      const SizedBox(height: 8),
                      Text('Batch: $batch', style: GoogleFonts.poppins(color: AppTheme.primary)),
                      Text('Status: $status', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                      if (lastAttendance.isNotEmpty) Text('Last check-in: $lastAttendance', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_isPT) ...[
                if (workoutSchedule.isNotEmpty) ...[
                  Text('Workout Schedule', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                  const SizedBox(height: 8),
                  Card(
                    color: AppTheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(_padding),
                      child: SelectableText(workoutSchedule, style: GoogleFonts.poppins(color: AppTheme.onSurface)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (dietChart.isNotEmpty) ...[
                  Text('Diet Chart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                  const SizedBox(height: 8),
                  Card(
                    color: AppTheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(_padding),
                      child: SelectableText(dietChart, style: GoogleFonts.poppins(color: AppTheme.onSurface)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (workoutSchedule.isEmpty && dietChart.isEmpty)
                  Text('No schedule or diet assigned yet.', style: GoogleFonts.poppins(color: Colors.grey)),
              ] else ...[
                Text('Preset Weekly Workouts', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ['Chest Day', 'Leg Day', 'Back Day', 'Shoulder Day', 'Arm Day', 'Full Body'].map((preset) {
                    return ActionChip(
                      label: Text(preset),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected: $preset'))),
                      backgroundColor: AppTheme.primary.withOpacity(0.2),
                      side: const BorderSide(color: AppTheme.primary),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              Text('Pay Fees', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
              const SizedBox(height: 12),
              if (_loadingPayments)
                const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              else
                ...(_payments.where((p) => (p['status'] == 'Due' || p['status'] == 'Overdue')).map((p) {
                  final map = p as Map<String, dynamic>;
                  return Card(
                    color: AppTheme.surfaceVariant,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${map['fee_type']} • ₹${map['amount']}', style: GoogleFonts.poppins(color: AppTheme.onSurface)),
                      subtitle: Text('${map['status']}', style: const TextStyle(color: AppTheme.primary)),
                      trailing: FilledButton(
                        onPressed: () => _showPayDialog(map),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.onPrimary),
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
        backgroundColor: AppTheme.surfaceVariant,
        title: Text('Pay ₹${payment['amount']}', style: GoogleFonts.poppins(color: AppTheme.primary)),
        content: Text('Simulated payment (Razorpay/Stripe). Confirm to mark as paid.', style: GoogleFonts.poppins(color: AppTheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final mid = widget.member['id'] as String?;
              final pid = payment['id'] as String?;
              if (mid == null || pid == null) return;
              try {
                final r = await ApiClient.instance.post('/payments/pay?member_id=$mid&payment_id=$pid');
                if (mounted && r.statusCode >= 200 && r.statusCode < 300) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully!')));
                  _loadPayments();
                }
              } catch (_) {}
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.onPrimary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
