import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../theme/app_theme.dart';
import 'attendance_report_screen.dart';
import 'billing_screen.dart';
import 'dashboard_screen.dart';
import 'registration_screen.dart';

final _apiBase = ApiClient.baseUrl;
const _padding = 20.0;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  int _membersRefreshKey = 0;
  final List<Widget?> _tabBodies = [null, null, null, null];

  Widget _buildTabAt(int index) {
    switch (index) {
      case 0:
        return _OverviewTab();
      case 1:
        return _MembersTab(
          refreshKey: _membersRefreshKey,
          onRegisterPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationScreen()));
            setState(() => _membersRefreshKey++);
          },
        );
      case 2:
        return _FeesTab();
      case 3:
        return const _BillingTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabBodies[_selectedIndex] == null) {
      _tabBodies[_selectedIndex] = _buildTabAt(_selectedIndex);
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', height: 32, width: 32, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Container(
              width: 32, height: 32, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.fitness_center, color: AppTheme.primary, size: 20),
            )),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Jupiter Arena Admin',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.calendarDays),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceReportScreen())),
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.fileExport),
            onPressed: _showExportMenu,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(_padding),
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _tabBodies[0] ?? const SizedBox.shrink(),
            _tabBodies[1] ?? const SizedBox.shrink(),
            _tabBodies[2] ?? const SizedBox.shrink(),
            _tabBodies[3] ?? const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          if (_tabBodies[i] == null) _tabBodies[i] = _buildTabAt(i);
          setState(() => _selectedIndex = i);
        },
        backgroundColor: AppTheme.surfaceVariant,
        indicatorColor: AppTheme.primary,
        destinations: const [
          NavigationDestination(icon: Icon(FontAwesomeIcons.chartPie), label: 'Overview'),
          NavigationDestination(icon: Icon(FontAwesomeIcons.users), label: 'Members'),
          NavigationDestination(icon: Icon(FontAwesomeIcons.indianRupeeSign), label: 'Fees'),
          NavigationDestination(icon: Icon(FontAwesomeIcons.fileInvoiceDollar), label: 'Billing'),
        ],
      ),
    );
  }

  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceVariant,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(FontAwesomeIcons.users, color: AppTheme.primary),
                title: const Text('Export Members to Excel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadExport('/export/members', 'members.xlsx');
                },
              ),
              ListTile(
                leading: const Icon(FontAwesomeIcons.fileInvoiceDollar, color: AppTheme.primary),
                title: const Text('Export Payments to Excel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadExport('/export/payments', 'payments.xlsx');
                },
              ),
              ListTile(
                leading: const Icon(FontAwesomeIcons.fileExport, color: AppTheme.primary),
                title: const Text('Export Billing to Excel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadExport('/export/billing', 'billing_history.xlsx');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _downloadExport(String path, String filename) async {
    final uri = Uri.parse('$_apiBase$path');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading $filename')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open $uri to download $filename')));
      }
    }
  }
}

class _BillingTab extends StatelessWidget {
  const _BillingTab();

  @override
  Widget build(BuildContext context) {
    return const BillingScreen();
  }
}

class _OverviewTab extends StatefulWidget {
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _sendingReminders = false;
  String? _error;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      Map<String, String>? params;
      if (_dateFrom != null && _dateTo != null) {
        params = {
          'date_from': '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}',
          'date_to': '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}',
        };
      }
      final r = await ApiClient.instance.get('/analytics/dashboard', queryParameters: params, useCache: true);
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        setState(() { _data = jsonDecode(r.body) as Map<String, dynamic>; _loading = false; });
      } else {
        setState(() { _error = 'Failed to load'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().split('\n').first; _loading = false; });
    }
  }

  Future<void> _pickDateRange() async {
    final from = _dateFrom ?? DateTime.now().subtract(const Duration(days: 30));
    final to = _dateTo ?? DateTime.now();
    final pickedFrom = await showDatePicker(context: context, initialDate: from, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (pickedFrom == null || !mounted) return;
    final pickedTo = await showDatePicker(context: context, initialDate: to.isAfter(pickedFrom) ? to : pickedFrom, firstDate: pickedFrom, lastDate: DateTime.now());
    if (pickedTo == null || !mounted) return;
    setState(() {
      _dateFrom = pickedFrom;
      _dateTo = pickedTo;
    });
    _load();
  }

  void _clearDateRange() {
    setState(() { _dateFrom = null; _dateTo = null; });
    _load();
  }

  Future<void> _sendReminders() async {
    setState(() => _sendingReminders = true);
    try {
      final r = await ApiClient.instance.post('/admin/run-fee-reminders');
      if (mounted) {
        final body = r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic>? : null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body?['message']?.toString() ?? 'Done')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send reminders')));
    }
    if (mounted) setState(() => _sendingReminders = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)));
    final d = _data!;
    return RefreshIndicator(
      onRefresh: () {
        ApiClient.instance.invalidateCache();
        return _load();
      },
      color: AppTheme.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: _padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_dateFrom != null && _dateTo != null
                      ? '${_dateFrom!.day}/${_dateFrom!.month} - ${_dateTo!.day}/${_dateTo!.month}'
                      : 'Past period'),
                ),
                if (_dateFrom != null && _dateTo != null)
                  IconButton(
                    onPressed: _clearDateRange,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear date range',
                  ),
              ],
            ),
            if (d['date_from'] != null && d['date_to'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AnalyticsCard(
                      title: 'Attendance (period)',
                      value: '${d['attendance_count_in_range'] ?? 0}',
                      icon: FontAwesomeIcons.userCheck,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _AnalyticsCard(
                      title: 'Payments received (₹)',
                      value: '${d['payments_received_in_range'] ?? 0}',
                      icon: FontAwesomeIcons.indianRupeeSign,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _AnalyticsCard(
              title: 'Active Members',
              value: '${d['active_members'] ?? 0}',
              icon: FontAwesomeIcons.userCheck,
              color: AppTheme.success,
            ),
            const SizedBox(height: 16),
            _AnalyticsCard(
              title: 'Inactive Members',
              value: '${d['inactive_members'] ?? 0}',
              icon: FontAwesomeIcons.userXmark,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            _AnalyticsCard(
              title: 'Total Collections (₹)',
              value: '${d['total_collections'] ?? 0}',
              icon: FontAwesomeIcons.indianRupeeSign,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            _AnalyticsCard(
              title: 'Pending Dues (₹)',
              value: '${d['pending_fees_amount'] ?? 0}',
              icon: FontAwesomeIcons.clock,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AnalyticsCard(
                    title: 'Regular',
                    value: '${d['regular_count'] ?? 0}',
                    icon: FontAwesomeIcons.users,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _AnalyticsCard(
                    title: 'PT',
                    value: '${d['pt_count'] ?? 0}',
                    icon: FontAwesomeIcons.dumbbell,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sendingReminders ? null : _sendReminders,
              icon: _sendingReminders ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(FontAwesomeIcons.whatsapp),
              label: Text(_sendingReminders ? 'Sending...' : 'Send Month-End Reminders'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticsCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.5))),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: FaIcon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(value, style: GoogleFonts.poppins(color: AppTheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersTab extends StatelessWidget {
  final int refreshKey;
  final VoidCallback onRegisterPressed;

  const _MembersTab({required this.refreshKey, required this.onRegisterPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onRegisterPressed,
            icon: const Icon(FontAwesomeIcons.userPlus, size: 18),
            label: const Text('Register Member'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.onPrimary),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: DashboardScreen(key: ValueKey(refreshKey), isEmbedded: true)),
      ],
    );
  }
}

class _FeesTab extends StatefulWidget {
  @override
  State<_FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends State<_FeesTab> {
  Map<String, dynamic>? _summary;
  List<dynamic> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r1 = await ApiClient.instance.get('/payments/fees-summary', useCache: true);
      final r2 = await ApiClient.instance.get('/payments', useCache: true);
      if (!mounted) return;
      if (r1.statusCode >= 200 && r1.statusCode < 300)
        _summary = jsonDecode(r1.body) as Map<String, dynamic>;
      if (r2.statusCode >= 200 && r2.statusCode < 300)
        _payments = jsonDecode(r2.body) as List<dynamic>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    final paid = _summary?['paid'] as Map<String, dynamic>? ?? {};
    final due = _summary?['due'] as Map<String, dynamic>? ?? {};
    final overdue = _summary?['overdue'] as Map<String, dynamic>? ?? {};
    return RefreshIndicator(
      onRefresh: () {
        ApiClient.instance.invalidateCache();
        return _load();
      },
      color: AppTheme.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: _padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _FeeChip('Paid', paid['count'] ?? 0, paid['total_amount'] ?? 0, AppTheme.success)),
                const SizedBox(width: 12),
                Expanded(child: _FeeChip('Due', due['count'] ?? 0, due['total_amount'] ?? 0, AppTheme.primary)),
                const SizedBox(width: 12),
                Expanded(child: _FeeChip('Overdue', overdue['count'] ?? 0, overdue['total_amount'] ?? 0, Colors.orange)),
              ],
            ),
            const SizedBox(height: 24),
            Text('All Payments', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
            const SizedBox(height: 12),
            ...(_payments.map((p) {
              final map = p as Map<String, dynamic>;
              final pid = map['id'] as String? ?? '';
              return Card(
                color: AppTheme.surfaceVariant,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withOpacity(0.3))),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: _padding, vertical: 8),
                  title: Text(map['member_name'] ?? '', style: GoogleFonts.poppins(color: AppTheme.onSurface, fontWeight: FontWeight.w500)),
                  subtitle: Text('${map['fee_type']} • ${map['period'] ?? 'Registration'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${map['amount']}', style: GoogleFonts.poppins(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                          Text(map['status'] ?? '', style: TextStyle(color: _statusColor(map['status']), fontSize: 12)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit status',
                        onPressed: () => _showEditPaymentStatus(context, map, _load),
                      ),
                    ],
                  ),
                ),
              );
            })),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? s) {
    if (s == 'Paid') return AppTheme.success;
    if (s == 'Overdue') return Colors.orange;
    return AppTheme.primary;
  }

  static void _showEditPaymentStatus(BuildContext context, Map<String, dynamic> payment, VoidCallback onSuccess) {
    String selected = payment['status'] as String? ?? 'Due';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit payment status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${payment['member_name']} • ₹${payment['amount']} • ${payment['fee_type']}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selected,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'Due', child: Text('Due')),
                  DropdownMenuItem(value: 'Overdue', child: Text('Overdue')),
                  DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                ],
                onChanged: (v) => setState(() => selected = v ?? selected),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final pid = payment['id'] as String?;
                if (pid == null) return;
                try {
                  final r = await ApiClient.instance.patch(
                    '/payments/$pid',
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'status': selected}),
                  );
                  if (ctx.mounted) {
                    if (r.statusCode >= 200 && r.statusCode < 300) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Payment status updated')));
                      onSuccess();
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: ${r.body}')));
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeChip extends StatelessWidget {
  final String label;
  final int count;
  final int amount;
  final Color color;

  const _FeeChip(this.label, this.count, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.5))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$count', style: GoogleFonts.poppins(color: AppTheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
            Text('₹$amount', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
