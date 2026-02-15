import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import 'attendance_report_screen.dart';

const _apiBase = ApiClient.baseUrl;
const _deepBlack = Color(0xFF0D0D0D);
const _gold = Color(0xFFD4AF37);
const _activeGreen = Color(0xFF22C55E);
const _inactiveGrey = Color(0xFF6B7280);

class Member {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String membershipType;
  final String batch;
  final String status;
  final String? workoutSchedule;
  final String? dietChart;

  Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.membershipType,
    required this.batch,
    required this.status,
    this.workoutSchedule,
    this.dietChart,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      membershipType: json['membership_type'] as String? ?? '',
      batch: json['batch'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
      workoutSchedule: json['workout_schedule'] as String?,
      dietChart: json['diet_chart'] as String?,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final bool isEmbedded;

  const DashboardScreen({super.key, this.isEmbedded = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Member> _members = [];
  bool _loading = true;
  String? _error;
  final Set<String> _checkingInIds = {};
  bool _runningAdminAction = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.get('/members', useCache: true);

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final list = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _members = list.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Failed to load members';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().split('\n').first;
        _loading = false;
      });
    }
  }

  Future<void> _checkIn(Member m) async {
    if (_checkingInIds.contains(m.id)) return;
    setState(() => _checkingInIds.add(m.id));

    try {
      final response = await ApiClient.instance.post('/attendance/check-in/${m.id}');

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String batchLabel = 'Unknown';
        if (response.body.isNotEmpty) {
          try {
            final body = jsonDecode(response.body) as Map<String, dynamic>?;
            batchLabel = body?['batch'] as String? ?? batchLabel;
          } catch (_) {}
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: _deepBlack, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text('Checked in for $batchLabel Batch!')),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        _loadMembers();
      } else {
        String detail = 'Check-in failed';
        if (response.body.isNotEmpty) {
          try {
            final body = jsonDecode(response.body) as Map<String, dynamic>?;
            final d = body?['detail'];
            detail = d is String ? d : (d?.toString() ?? detail);
          } catch (_) {}
        }
        detail = '${detail.trim()} (${response.statusCode})';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: _deepBlack, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(detail)),
              ],
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().split('\n').first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connection error: $msg'),
              const SizedBox(height: 6),
              const Text(
                'If you tapped Check-In, refresh the dashboard or open Today\'s Attendance — the check-in may have succeeded.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          duration: const Duration(seconds: 12),
          action: SnackBarAction(
            label: 'Refresh',
            onPressed: () => _loadMembers(),
            textColor: _deepBlack,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingInIds.remove(m.id));
    }
  }

  void _showMemberEditDialog(BuildContext context, Member m) {
    final nameController = TextEditingController(text: m.name);
    final phoneController = TextEditingController(text: m.phone);
    final emailController = TextEditingController(text: m.email);
    String batch = m.batch;
    String status = m.status;
    String membershipType = m.membershipType;
    final scheduleController = TextEditingController(text: m.workoutSchedule ?? '');
    final dietController = TextEditingController(text: m.dietChart ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: membershipType,
                  decoration: const InputDecoration(labelText: 'Membership type'),
                  items: const [
                    DropdownMenuItem(value: 'Regular', child: Text('Regular')),
                    DropdownMenuItem(value: 'PT', child: Text('PT')),
                  ],
                  onChanged: (v) => setState(() => membershipType = v ?? membershipType),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: batch,
                  decoration: const InputDecoration(labelText: 'Batch'),
                  items: const [
                    DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                    DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                    DropdownMenuItem(value: 'Ladies', child: Text('Ladies')),
                  ],
                  onChanged: (v) => setState(() => batch = v ?? batch),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) => setState(() => status = v ?? status),
                ),
                if (membershipType.toLowerCase() == 'pt') ...[
                  const SizedBox(height: 12),
                  TextField(controller: scheduleController, maxLines: 3, decoration: const InputDecoration(labelText: 'Workout schedule', alignLabelWithHint: true)),
                  const SizedBox(height: 12),
                  TextField(controller: dietController, maxLines: 3, decoration: const InputDecoration(labelText: 'Diet chart', alignLabelWithHint: true)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final body = <String, dynamic>{
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'email': emailController.text.trim(),
                  'batch': batch,
                  'status': status,
                  'membership_type': membershipType,
                };
                if (membershipType.toLowerCase() == 'pt') {
                  body['workout_schedule'] = scheduleController.text;
                  body['diet_chart'] = dietController.text;
                }
                try {
                  final r = await ApiClient.instance.patch(
                    '/members/${m.id}',
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(body),
                  );
                  if (!mounted) return;
                  if (r.statusCode >= 200 && r.statusCode < 300) {
                    _loadMembers();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member updated')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${r.body}')));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepBlack),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPTEditSheet(BuildContext context, Member m) {
    final scheduleController = TextEditingController(text: m.workoutSchedule ?? '');
    final dietController = TextEditingController(text: m.dietChart ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit PT: ${m.name}', style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: scheduleController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Workout Schedule',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dietController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Diet Chart',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    final r = await ApiClient.instance.patch(
                      '/members/${m.id}',
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'workout_schedule': scheduleController.text,
                        'diet_chart': dietController.text,
                      }),
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    if (r.statusCode >= 200 && r.statusCode < 300) {
                      _loadMembers();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PT details updated')));
                    }
                  } catch (_) {}
                },
                style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepBlack),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _seedInactiveTest() async {
    if (_runningAdminAction) return;
    setState(() => _runningAdminAction = true);
    try {
      final response = await ApiClient.instance.post('/admin/seed-inactive-test');
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _loadMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Created 2 test members (last check-in 91 days ago). Tap menu → Mark inactive (90d) to test.'),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seed failed: ${response.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().split('\n').first}')));
    } finally {
      if (mounted) setState(() => _runningAdminAction = false);
    }
  }

  Future<void> _markInactiveByAttendance() async {
    if (_runningAdminAction) return;
    setState(() => _runningAdminAction = true);
    try {
      final response = await ApiClient.instance.post('/admin/mark-inactive-by-attendance');
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final count = body?['updated_count'] as int? ?? 0;
        _loadMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count member(s) marked Inactive (no check-in for 90+ days).')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mark inactive failed: ${response.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().split('\n').first}')));
    } finally {
      if (mounted) setState(() => _runningAdminAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildBody(context);
    if (widget.isEmbedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Today\'s Attendance',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AttendanceReportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadMembers,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: '90-day automation test',
            onSelected: (value) {
              if (value == 'seed') _seedInactiveTest();
              if (value == 'mark') _markInactiveByAttendance();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'seed', child: Text('Seed 90-day test data')),
              const PopupMenuItem(value: 'mark', child: Text('Mark inactive (90d)')),
            ],
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return _loading
        ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _gold),
                  SizedBox(height: 16),
                  Text('Loading members...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _loadMembers,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepBlack),
                        ),
                      ],
                    ),
                  ),
                )
              : _members.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          Text('No members yet', style: TextStyle(color: Colors.grey.shade400, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('Register members from the home screen', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () {
                        ApiClient.instance.invalidateCache();
                        return _loadMembers();
                      },
                      color: _gold,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final m = _members[index];
                          final isActive = m.status.toLowerCase() == 'active';
                          final isCheckingIn = _checkingInIds.contains(m.id);
                          return RepaintBoundary(
                            child: Card(
                            color: isActive ? const Color(0xFF1A1A1A) : const Color(0xFF151515),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isActive ? _gold : _inactiveGrey,
                                width: isActive ? 1 : 0.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: _gold,
                                        foregroundColor: _deepBlack,
                                        child: Text((m.name.isNotEmpty ? m.name[0] : '?').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: isActive ? _activeGreen : _inactiveGrey,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  m.name,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(m.email, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                            Text(m.phone, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                _chip(m.membershipType, _gold),
                                                const SizedBox(width: 8),
                                                _chip(m.batch, Colors.grey.shade700),
                                                const SizedBox(width: 8),
                                                _chip(m.status, isActive ? _activeGreen : _inactiveGrey),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => _showMemberEditDialog(context, m),
                                        child: const Text('Edit'),
                                      ),
                                      if (m.membershipType.toLowerCase() == 'pt')
                                        TextButton(
                                          onPressed: () => _showPTEditSheet(context, m),
                                          child: const Text('PT plan'),
                                        ),
                                      FilledButton(
                                        onPressed: isCheckingIn ? null : () => _checkIn(m),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _gold,
                                          foregroundColor: _deepBlack,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          minimumSize: Size.zero,
                                        ),
                                        child: isCheckingIn
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: _deepBlack),
                                              )
                                            : const Text('Check-In'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          );
                        },
                      ),
                    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}
