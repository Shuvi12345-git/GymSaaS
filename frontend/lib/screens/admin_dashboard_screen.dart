import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'attendance_report_screen.dart';
import 'dashboard_screen.dart';
import 'registration_screen.dart';

const _apiBase = 'http://localhost:8000';
const _deepBlack = Color(0xFF0D0D0D);
const _gold = Color(0xFFD4AF37);
const _padding = 20.0;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  int _membersRefreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fitness_center, color: _deepBlack, size: 22),
            ),
            Text('GymSaaS Admin', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: _deepBlack,
        foregroundColor: _gold,
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
            _OverviewTab(),
            _MembersTab(
              refreshKey: _membersRefreshKey,
              onRegisterPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationScreen()));
                setState(() => _membersRefreshKey++);
              },
            ),
            _FeesTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: const Color(0xFF1A1A1A),
        indicatorColor: _gold,
        destinations: const [
          NavigationDestination(icon: Icon(FontAwesomeIcons.chartPie), label: 'Overview'),
          NavigationDestination(icon: Icon(FontAwesomeIcons.users), label: 'Members'),
          NavigationDestination(icon: Icon(FontAwesomeIcons.indianRupeeSign), label: 'Fees'),
        ],
      ),
    );
  }

  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(FontAwesomeIcons.users, color: _gold),
                title: const Text('Export Members to Excel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadExport('/export/members', 'members.xlsx');
                },
              ),
              ListTile(
                leading: const Icon(FontAwesomeIcons.fileInvoiceDollar, color: _gold),
                title: const Text('Export Payments to Excel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadExport('/export/payments', 'payments.xlsx');
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

class _OverviewTab extends StatefulWidget {
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await http.get(Uri.parse('$_apiBase/analytics/dashboard')).timeout(const Duration(seconds: 10));
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _gold));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)));
    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      color: _gold,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: _padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AnalyticsCard(
              title: 'Active Members',
              value: '${d['active_members'] ?? 0}',
              icon: FontAwesomeIcons.userCheck,
              color: const Color(0xFF22C55E),
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
              title: 'Pending Fees (₹)',
              value: '${d['pending_fees_amount'] ?? 0}',
              icon: FontAwesomeIcons.indianRupeeSign,
              color: _gold,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AnalyticsCard(
                    title: 'Regular',
                    value: '${d['regular_count'] ?? 0}',
                    icon: FontAwesomeIcons.users,
                    color: _gold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _AnalyticsCard(
                    title: 'PT',
                    value: '${d['pt_count'] ?? 0}',
                    icon: FontAwesomeIcons.dumbbell,
                    color: _gold,
                  ),
                ),
              ],
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
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _gold.withOpacity(0.5))),
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
                  Text(title, style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
            style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepBlack),
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
      final r1 = await http.get(Uri.parse('$_apiBase/payments/fees-summary')).timeout(const Duration(seconds: 10));
      final r2 = await http.get(Uri.parse('$_apiBase/payments')).timeout(const Duration(seconds: 10));
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: _gold));
    final paid = _summary?['paid'] as Map<String, dynamic>? ?? {};
    final due = _summary?['due'] as Map<String, dynamic>? ?? {};
    final overdue = _summary?['overdue'] as Map<String, dynamic>? ?? {};
    return RefreshIndicator(
      onRefresh: _load,
      color: _gold,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: _padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _FeeChip('Paid', paid['count'] ?? 0, paid['total_amount'] ?? 0, const Color(0xFF22C55E))),
                const SizedBox(width: 12),
                Expanded(child: _FeeChip('Due', due['count'] ?? 0, due['total_amount'] ?? 0, _gold)),
                const SizedBox(width: 12),
                Expanded(child: _FeeChip('Overdue', overdue['count'] ?? 0, overdue['total_amount'] ?? 0, Colors.orange)),
              ],
            ),
            const SizedBox(height: 24),
            Text('All Payments', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 12),
            ...(_payments.map((p) {
              final map = p as Map<String, dynamic>;
              return Card(
                color: const Color(0xFF1A1A1A),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _gold.withOpacity(0.3))),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: _padding, vertical: 8),
                  title: Text(map['member_name'] ?? '', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
                  subtitle: Text('${map['fee_type']} • ${map['period'] ?? 'Registration'}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${map['amount']}', style: GoogleFonts.poppins(color: _gold, fontWeight: FontWeight.bold)),
                      Text(map['status'] ?? '', style: TextStyle(color: _statusColor(map['status']), fontSize: 12)),
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
    if (s == 'Paid') return const Color(0xFF22C55E);
    if (s == 'Overdue') return Colors.orange;
    return _gold;
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
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.5))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$count', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text('₹$amount', style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
