import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../theme/app_theme.dart';

const _apiBase = ApiClient.baseUrl;
const _padding = 20.0;

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invoices = [];
  bool _loadingMembers = false;
  bool _loadingInvoices = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMembers();
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final r = await ApiClient.instance.get('/members', useCache: true);
      if (mounted && r.statusCode == 200) {
        final list = jsonDecode(r.body) as List<dynamic>;
        setState(() {
          _members = list.map((e) => e as Map<String, dynamic>).toList();
          _loadingMembers = false;
        });
      } else if (mounted) setState(() => _loadingMembers = false);
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadInvoices() async {
    setState(() => _loadingInvoices = true);
    try {
      final r = await ApiClient.instance.get('/billing/history', useCache: true);
      if (mounted && r.statusCode == 200) {
        final list = jsonDecode(r.body) as List<dynamic>;
        setState(() {
          _invoices = list.map((e) => e as Map<String, dynamic>).toList();
          _loadingInvoices = false;
        });
      } else if (mounted) setState(() => _loadingInvoices = false);
    } catch (_) {
      if (mounted) setState(() => _loadingInvoices = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Walk-in'),
            Tab(text: 'Existing Member'),
            Tab(text: 'Invoice / History'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _WalkInTab(onSuccess: () { _loadMembers(); _loadInvoices(); }),
              _ExistingMemberTab(members: _members, loading: _loadingMembers, onSuccess: _loadInvoices),
              _InvoiceHistoryTab(invoices: _invoices, loading: _loadingInvoices, onRefresh: _loadInvoices),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalkInTab extends StatefulWidget {
  final VoidCallback onSuccess;

  const _WalkInTab({required this.onSuccess});

  @override
  State<_WalkInTab> createState() => _WalkInTabState();
}

class _WalkInTabState extends State<_WalkInTab> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String _membershipType = 'Regular';
  String _batch = 'Morning';
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields')));
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.post(
        '/billing/issue',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
          'membership_type': _membershipType,
          'batch': _batch,
        }),
      );
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final inv = jsonDecode(r.body) as Map<String, dynamic>;
        widget.onSuccess();
        _name.clear();
        _phone.clear();
        _email.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Member added. Invoice #${inv['id']} issued for ₹${inv['total']}')));
      } else {
        final body = jsonDecode(r.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body['detail']?.toString() ?? 'Failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(_padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _membershipType,
            decoration: const InputDecoration(labelText: 'Membership'),
            items: ['Regular', 'PT'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _membershipType = v ?? 'Regular'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _batch,
            decoration: const InputDecoration(labelText: 'Batch'),
            items: ['Morning', 'Evening', 'Ladies'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _batch = v ?? 'Morning'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add Member & Issue First Bill'),
          ),
        ],
      ),
    );
  }
}

class _ExistingMemberTab extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final bool loading;
  final VoidCallback onSuccess;

  const _ExistingMemberTab({required this.members, required this.loading, required this.onSuccess});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (members.isEmpty) return const Center(child: Text('No members. Use Walk-in or Members tab.'));
    return ListView.builder(
      padding: const EdgeInsets.all(_padding),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final m = members[i];
        final name = m['name'] as String? ?? '';
        final id = m['id'] as String? ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(name),
            subtitle: Text('ID: $id'),
            trailing: TextButton(
              onPressed: () => _showExistingMemberPayDialog(context, id, name, onSuccess),
              child: const Text('Log payment'),
            ),
          ),
        );
      },
    );
  }

  static void _showExistingMemberPayDialog(BuildContext context, String memberId, String name, VoidCallback onSuccess) async {
    List<dynamic> payments = [];
    try {
      final r = await ApiClient.instance.get('/payments', queryParameters: {'member_id': memberId}, useCache: false);
      if (r.statusCode == 200) payments = jsonDecode(r.body) as List<dynamic>;
    } catch (_) {}
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Dues for $name', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...(payments.where((p) => p['status'] != 'Paid').map((p) => ListTile(
                  title: Text('${p['fee_type']} • ₹${p['amount']}'),
                  trailing: FilledButton(
                    onPressed: () async {
                      final pid = p['id'];
                      final pay = await ApiClient.instance.post('/payments/pay?member_id=$memberId&payment_id=$pid');
                      if (pay.statusCode >= 200 && pay.statusCode < 300) {
                        setModalState(() => payments = payments.where((x) => x['id'] != pid).toList());
                        onSuccess();
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Payment recorded')));
                      }
                    },
                    child: const Text('Pay'),
                  ),
                ))),
                if (payments.where((p) => p['status'] != 'Paid').isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No pending dues')),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> invoices;
  final bool loading;
  final VoidCallback onRefresh;

  const _InvoiceHistoryTab({required this.invoices, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Billing history', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await launchUrl(Uri.parse('$_apiBase/export/billing'), mode: LaunchMode.externalApplication);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export started')));
                  } catch (_) {}
                },
                icon: const Icon(FontAwesomeIcons.fileExport, size: 18),
                label: const Text('Export CSV/Excel'),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ListView.builder(
                  padding: const EdgeInsets.all(_padding),
                  itemCount: invoices.length,
                  itemBuilder: (context, i) {
                    final inv = invoices[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(inv['member_name'] ?? ''),
                        subtitle: Text('₹${inv['total']} • ${inv['status']}'),
                        trailing: inv['status'] == 'Unpaid'
                            ? FilledButton(
                                onPressed: () => _InvoiceHistoryTab.showInvoiceWithQR(context, inv, onRefresh),
                                child: const Text('View / Pay'),
                              )
                            : null,
                        onTap: () => _InvoiceHistoryTab.showInvoiceWithQR(context, inv, onRefresh),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static void showInvoiceWithQR(BuildContext context, Map<String, dynamic> inv, VoidCallback onRefresh) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Invoice • ${inv['member_name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...(inv['items'] as List<dynamic>? ?? []).map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e['description'] ?? ''),
                    Text('₹${e['amount']}'),
                  ],
                ),
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  Text('₹${inv['total']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ],
              ),
              if (inv['status'] == 'Unpaid') ...[
                const SizedBox(height: 16),
                const Center(child: Text('Simulated UPI QR', style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.qr_code_2, size: 80),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (inv['status'] == 'Unpaid')
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final r = await ApiClient.instance.post('/billing/pay?invoice_id=${inv['id']}');
                if (r.statusCode >= 200 && r.statusCode < 300) {
                  onRefresh();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded')));
                }
              },
              child: const Text('Mark as Paid'),
            ),
        ],
      ),
    );
  }
}
