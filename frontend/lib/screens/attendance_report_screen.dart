// ---------------------------------------------------------------------------
// Attendance report – view/filter check-in/out by date or range, delete record.
// ---------------------------------------------------------------------------
// Admin tab: fetches attendance via /attendance/by-date or by-date-range,
// displays [AttendanceEntry] list. Supports date picker and optional batch filter.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/date_utils.dart';
import '../theme/app_theme.dart';

final _apiBase = ApiClient.baseUrl;

class AttendanceEntry {
  final String id;
  final String memberId;
  final String memberName;
  final String? memberPhone;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final String dateIst;
  final String batch;

  AttendanceEntry({
    required this.id,
    required this.memberId,
    required this.memberName,
    this.memberPhone,
    required this.checkInAt,
    this.checkOutAt,
    required this.dateIst,
    required this.batch,
  });

  String get durationMinutes {
    if (checkOutAt == null) return '—';
    final min = checkOutAt!.difference(checkInAt).inMinutes;
    if (min < 60) return '${min}m';
    return '${min ~/ 60}h ${min % 60}m';
  }

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) {
    final checkInStr = json['check_in_at'] as String?;
    DateTime checkIn = DateTime.now();
    if (checkInStr != null) checkIn = DateTime.parse(checkInStr);
    DateTime? checkOut;
    final checkOutStr = json['check_out_at'] as String?;
    if (checkOutStr != null && checkOutStr.isNotEmpty) checkOut = DateTime.tryParse(checkOutStr);
    return AttendanceEntry(
      id: json['id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      memberName: json['member_name'] as String? ?? '',
      memberPhone: json['member_phone'] as String?,
      checkInAt: checkIn,
      checkOutAt: checkOut,
      dateIst: json['date_ist'] as String? ?? '',
      batch: json['batch'] as String? ?? '',
    );
  }
}

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  List<AttendanceEntry> _entries = [];
  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  bool _useRange = false;
  DateTime _rangeStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _rangeEnd = DateTime.now();
  Map<String, dynamic>? _summary;
  final _searchController = TextEditingController();
  String _filterBatch = 'All'; // All, Morning, Evening, Ladies

  @override
  void initState() {
    super.initState();
    _load();
    _loadSummary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final r = await ApiClient.instance.get('/attendance/summary', useCache: false);
      if (mounted && r.statusCode == 200) {
        setState(() => _summary = jsonDecode(r.body) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = _useRange
          ? await ApiClient.instance.get(
              '/attendance/by-date-range',
              queryParameters: {
                'date_from': formatApiDate(_rangeStart),
                'date_to': formatApiDate(_rangeEnd),
              },
              useCache: false,
            )
          : await ApiClient.instance.get(
              '/attendance/by-date',
              queryParameters: {'date': formatApiDate(_selectedDate)},
              useCache: false,
            );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final list = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _entries = list.map((e) => AttendanceEntry.fromJson(e as Map<String, dynamic>)).toList();
          _loading = false;
          _error = null;
        });
        _loadSummary();
      } else {
        setState(() {
          _error = 'Failed to load attendance';
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Future<void> _pickRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _rangeStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (from == null || !mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _rangeEnd.isBefore(from) ? from : _rangeEnd,
      firstDate: from,
      lastDate: DateTime.now(),
    );
    if (to != null && mounted) {
      setState(() {
        _rangeStart = from;
        _rangeEnd = to;
        _useRange = true;
      });
      _load();
    }
  }

  Future<void> _deleteAttendance(AttendanceEntry e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove check-in?'),
        content: Text('Remove ${e.memberName} (${e.batch}) from this date? Use for wrong person or duplicate.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final r = await ApiClient.instance.delete('/attendance/${e.id}');
      if (mounted && r.statusCode >= 200 && r.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in removed')));
        _load();
        _loadSummary();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${r.statusCode}')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove')));
    }
  }

  Future<void> _showManualCheckIn() async {
    List<Map<String, dynamic>> members = [];
    try {
      final r = await ApiClient.instance.get('/members', queryParameters: {'brief': 'true', 'limit': '200'}, useCache: false);
      if (r.statusCode == 200) members = (jsonDecode(r.body) as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (!mounted) return;
    final todayStr = formatApiDate(DateTime.now());
    final alreadyIds = _entries.where((e) => e.dateIst == todayStr).map((e) => e.memberId).toSet();
    final available = members.where((m) => !alreadyIds.contains(m['id']?.toString())).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All members already checked in today or no members')));
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Manual Check-in – Select member', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: available.length,
                itemBuilder: (context, i) {
                  final m = available[i];
                  final name = m['name'] as String? ?? '';
                  final id = m['id'] as String? ?? '';
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(m['phone']?.toString() ?? ''),
                    trailing: FilledButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final res = await ApiClient.instance.post('/attendance/check-in/$id');
                          if (mounted) {
                            if (res.statusCode >= 200 && res.statusCode < 300) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name checked in')));
                              _load();
                              _loadSummary();
                            } else {
                              final body = jsonDecode(res.body);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body['detail']?.toString() ?? 'Failed')));
                            }
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: const Text('Check-in'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _batchOrder = ['Morning', 'Evening', 'Ladies'];

  List<AttendanceEntry> _sortedByBatch() {
    final copy = List<AttendanceEntry>.from(_entries);
    copy.sort((a, b) {
      final ai = _batchOrder.indexOf(a.batch);
      final bi = _batchOrder.indexOf(b.batch);
      if (ai != bi) return ai.compareTo(bi);
      return a.checkInAt.compareTo(b.checkInAt);
    });
    return copy;
  }

  List<AttendanceEntry> _filteredEntries() {
    var list = _sortedByBatch();
    if (_filterBatch != 'All') list = list.where((e) => e.batch == _filterBatch).toList();
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final name = e.memberName.toLowerCase();
        final phone = (e.memberPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        final qDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
        return name.contains(q) || (qDigits.isNotEmpty && phone.contains(qDigits));
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isToday = !_useRange && _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;
    final padding = LayoutConstants.screenPadding(context);
    final summary = _summary ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Records'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : () { _load(); _loadSummary(); }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { await _load(); await _loadSummary(); },
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dashboard: title, subtitle, Manual Check-in, 4 cards
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Attendance', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
                        const SizedBox(height: 4),
                        Text('Track member check-ins and gym visits.', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showManualCheckIn,
                    icon: const Icon(Icons.person_add_alt_1, size: 20),
                    label: const Text('Manual Check-in'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _SummaryCard('Today\'s Check-ins', '${summary['today_check_ins'] ?? 0}', Icons.login, Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard('Currently In Gym', '${summary['currently_in_gym'] ?? 0}', Icons.people, Colors.blue)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _SummaryCard('This Week', '${summary['this_week'] ?? 0}', Icons.calendar_today, Colors.purple)),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard('Average Daily', '${summary['average_daily'] ?? 0}', Icons.show_chart, Colors.grey)),
                ],
              ),
              const SizedBox(height: 24),
              // Date navigation: < Today >
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _loading ? null : () {
                      setState(() {
                        if (_useRange) {
                          _rangeStart = _rangeStart.subtract(const Duration(days: 1));
                          _rangeEnd = _rangeEnd.subtract(const Duration(days: 1));
                        } else {
                          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                        }
                      });
                      _load();
                    },
                  ),
                  TextButton(
                    onPressed: _loading ? null : () async {
                      if (_useRange) {
                        _pickRange();
                      } else {
                        await _pickDate();
                      }
                    },
                    child: Text(
                      _useRange ? '${formatDisplayDate(_rangeStart)} – ${formatDisplayDate(_rangeEnd)}' : (isToday ? 'Today' : formatDisplayDate(_selectedDate)),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _loading ? null : () {
                      final now = DateTime.now();
                      setState(() {
                        if (_useRange) {
                          if (_rangeEnd.isBefore(now)) {
                            _rangeStart = _rangeStart.add(const Duration(days: 1));
                            _rangeEnd = _rangeEnd.add(const Duration(days: 1));
                            if (_rangeEnd.isAfter(now)) _rangeEnd = now;
                          }
                        } else {
                          if (_selectedDate.isBefore(now)) _selectedDate = _selectedDate.add(const Duration(days: 1));
                          if (_selectedDate.isAfter(now)) _selectedDate = now;
                        }
                      });
                      _load();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() { _useRange = false; _load(); }), child: const Text('Day')),
                  TextButton(onPressed: _loading ? null : _pickRange, child: const Text('Range')),
                ],
              ),
              const SizedBox(height: 16),
              // Search and filter
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone...',
                        prefixIcon: const Icon(Icons.search, size: 22),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _filterBatch,
                    items: ['All', 'Morning', 'Evening', 'Ladies'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _filterBatch = v ?? 'All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Table / Records
              Text('Attendance Records', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              else if (_filteredEntries().isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy, size: 48, color: Colors.grey.shade600),
                        const SizedBox(height: 12),
                        Text('No attendance records found', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useTable = constraints.maxWidth > 500;
                    final list = _filteredEntries();
                    if (useTable) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Member')),
                            DataColumn(label: Text('Phone')),
                            DataColumn(label: Text('Check-in')),
                            DataColumn(label: Text('Check-out')),
                            DataColumn(label: Text('Duration')),
                            DataColumn(label: Text('Method')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: list.map((e) => DataRow(
                            cells: [
                              DataCell(Text(e.memberName)),
                              DataCell(Text(e.memberPhone ?? '—')),
                              DataCell(Text(formatDisplayTime(e.checkInAt))),
                              DataCell(Text(e.checkOutAt != null ? formatDisplayTime(e.checkOutAt!) : '—')),
                              DataCell(Text(e.durationMinutes)),
                              const DataCell(Text('Manual')),
                              DataCell(IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _deleteAttendance(e),
                                color: Colors.red,
                              )),
                            ],
                          )).toList(),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = list[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: Text(e.memberName, style: GoogleFonts.poppins(fontWeight: FontWeight.w500))),
                              Expanded(child: Text(e.memberPhone ?? '—', style: GoogleFonts.poppins(fontSize: 12))),
                              Text(formatDisplayTime(e.checkInAt), style: GoogleFonts.poppins(fontSize: 12)),
                              const SizedBox(width: 8),
                              Text(e.checkOutAt != null ? formatDisplayTime(e.checkOutAt!) : '—', style: GoogleFonts.poppins(fontSize: 12)),
                              const SizedBox(width: 8),
                              Text(e.durationMinutes, style: GoogleFonts.poppins(fontSize: 12)),
                              IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _deleteAttendance(e), color: Colors.red),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.5))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
            const SizedBox(height: 4),
            Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
