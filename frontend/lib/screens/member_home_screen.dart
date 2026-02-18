// ---------------------------------------------------------------------------
// Member home – post-login screen for a member: check-in/out, payments, profile.
// ---------------------------------------------------------------------------
// Receives [member] map from login. Shows today's check-in/out buttons,
// payment dues list, and profile/attendance summary. All API calls use
// member id from [widget.member].
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../widgets/skeleton_loading.dart';
import '../theme/app_theme.dart';

final _apiBase = ApiClient.baseUrl;

class MemberHomeScreen extends StatefulWidget {
  final Map<String, dynamic> member;

  const MemberHomeScreen({super.key, required this.member});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  List<dynamic> _payments = [];
  bool _loadingPayments = false;
  bool _checkingIn = false;
  bool _checkingOut = false;
  bool _checkedInToday = false;
  bool _checkedOutToday = false;
  final GlobalKey _inboxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _checkInSelf() async {
    final mid = widget.member['id'] as String?;
    if (mid == null || _checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      final r = await ApiClient.instance.post('/attendance/check-in/$mid');
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        hapticSuccess();
        setState(() { _checkedInToday = true; _checkingIn = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in successfully!')),
        );
      } else {
        final body = jsonDecode(r.body) as Map<String, dynamic>?;
        final detail = body?['detail']?.toString() ?? 'Check-in failed';
        setState(() => _checkingIn = false);
        if (detail.toLowerCase().contains('already') || detail.toLowerCase().contains('today')) {
          setState(() => _checkedInToday = true);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().split('\n').first}')));
      }
    }
  }

  Future<void> _checkOutSelf() async {
    final mid = widget.member['id'] as String?;
    if (mid == null || _checkingOut) return;
    setState(() => _checkingOut = true);
    try {
      final r = await ApiClient.instance.post('/attendance/check-out/$mid');
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        hapticSuccess();
        setState(() { _checkedOutToday = true; _checkingOut = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked out successfully!')));
      } else {
        final body = jsonDecode(r.body) as Map<String, dynamic>?;
        final detail = body?['detail']?.toString() ?? 'Check-out failed';
        setState(() => _checkingOut = false);
        if (detail.toLowerCase().contains('already')) setState(() => _checkedOutToday = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().split('\n').first}')));
      }
    }
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

  List<Map<String, dynamic>> get _duePayments {
    return _payments
        .where((p) => p['status'] == 'Due' || p['status'] == 'Overdue')
        .map((p) => p as Map<String, dynamic>)
        .toList();
  }

  bool get _hasOverdue => _duePayments.any((p) => p['status'] == 'Overdue');

  @override
  Widget build(BuildContext context) {
    final name = widget.member['name'] as String? ?? '';
    final batch = widget.member['batch'] as String? ?? '';
    final status = widget.member['status'] as String? ?? 'Active';
    final lastAttendance = widget.member['last_attendance_date'] as String? ?? '';
    final workoutSchedule = widget.member['workout_schedule'] as String? ?? '';
    final dietChart = widget.member['diet_chart'] as String? ?? '';
    final padding = LayoutConstants.screenPadding(context);
    final radius = LayoutConstants.cardRadius(context);

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
        padding: EdgeInsets.all(padding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: AppTheme.surfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: AppTheme.primary.withOpacity(0.5))),
                child: Padding(
                  padding: EdgeInsets.all(padding),
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
              const SizedBox(height: 20),
              // Inbox, Check In, Check Out – for viewing due fees and marking entry/exit
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_inboxKey.currentContext != null) {
                          Scrollable.ensureVisible(
                            _inboxKey.currentContext!,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      icon: Icon(Icons.inbox_rounded, size: 20, color: _duePayments.isNotEmpty ? AppTheme.primary : Colors.grey),
                      label: Text(
                        'Inbox',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: _duePayments.isNotEmpty ? AppTheme.primary : Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_checkedInToday || _checkingIn) ? null : _checkInSelf,
                      icon: _checkingIn
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary))
                          : Icon(_checkedInToday ? Icons.check_circle : Icons.login, size: 20),
                      label: Text(
                        _checkedInToday ? 'Checked in' : (_checkingIn ? '...' : 'Check In'),
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_checkedOutToday || _checkingOut || !_checkedInToday) ? null : _checkOutSelf,
                      icon: _checkingOut
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_checkedOutToday ? Icons.check_circle : Icons.logout, size: 20),
                      label: Text(
                        _checkedOutToday ? 'Checked out' : (_checkingOut ? '...' : 'Check Out'),
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) => Opacity(opacity: value, child: child),
                child: _buildInboxSection(context, padding, radius, _inboxKey),
              ),
              const SizedBox(height: 24),
              Text('Attendance', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
              const SizedBox(height: 8),
              Card(
                color: AppTheme.surfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          lastAttendance.isEmpty ? 'No check-ins yet' : 'Last check-in: $lastAttendance',
                          style: GoogleFonts.poppins(color: AppTheme.onSurface),
                        ),
                      ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInboxSection(BuildContext context, double padding, double radius, [GlobalKey? scrollKey]) {
    return Card(
      key: scrollKey,
      elevation: 0,
      color: AppTheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AppTheme.primary, width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inbox_rounded, color: AppTheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inbox', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                      Text('Due fees & reminders', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            if (_hasOverdue) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, size: 20, color: AppTheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pay your dues to avoid interruption.',
                        style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_loadingPayments)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppTheme.primary)))
            else if (_duePayments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "No pending fees. You're all set.",
                  style: GoogleFonts.poppins(color: AppTheme.onSurfaceVariant, fontSize: 14),
                ),
              )
            else
              ...List.generate(_duePayments.length, (i) {
                final map = _duePayments[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: i < _duePayments.length - 1 ? 8 : 0),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${map['fee_type']} • ₹${map['amount']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: AppTheme.onSurface)),
                    subtitle: Text(map['status'] as String? ?? '', style: TextStyle(color: map['status'] == 'Overdue' ? AppTheme.error : AppTheme.primary, fontSize: 12)),
                    trailing: FilledButton(
                      onPressed: () => _showPayDialog(map),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.onPrimary),
                      child: const Text('Pay'),
                    ),
                  ),
                );
              }),
          ],
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
