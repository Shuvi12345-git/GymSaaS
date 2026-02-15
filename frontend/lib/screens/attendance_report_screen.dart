import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../theme/app_theme.dart';

final _apiBase = ApiClient.baseUrl;

class AttendanceEntry {
  final String id;
  final String memberId;
  final String memberName;
  final DateTime checkInAt;
  final String dateIst;
  final String batch;

  AttendanceEntry({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.checkInAt,
    required this.dateIst,
    required this.batch,
  });

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) {
    final checkInStr = json['check_in_at'] as String?;
    DateTime checkIn = DateTime.now();
    if (checkInStr != null) {
      checkIn = DateTime.parse(checkInStr);
    }
    return AttendanceEntry(
      id: json['id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      memberName: json['member_name'] as String? ?? '',
      checkInAt: checkIn,
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final response = await ApiClient.instance.get(
        '/attendance/by-date',
        queryParameters: {'date': dateStr},
        useCache: false,
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final list = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _entries = list
              .map((e) => AttendanceEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
          _error = null;
        });
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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${r.statusCode}')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove')));
    }
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

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('hh:mm a');
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance by Date'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Pick date',
            onPressed: _loading ? null : _pickDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: AppTheme.surfaceVariant,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(FontAwesomeIcons.calendarDays, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, d MMM yyyy').format(_selectedDate),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _loading ? null : _pickDate,
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text('Loading attendance...', style: TextStyle(color: Colors.grey)),
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
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.onPrimary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_available, size: 64, color: Colors.grey.shade600),
                                const SizedBox(height: 16),
                                Text(
                                  'No check-ins ${isToday ? 'today' : 'on this date'} (IST)',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text('Check-ins will appear here', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppTheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _sortedByBatch().length,
                              itemBuilder: (context, index) {
                                final e = _sortedByBatch()[index];
                                final showBatchHeader = index == 0 || _sortedByBatch()[index - 1].batch != e.batch;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showBatchHeader) ...[
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                                        child: Text(
                                          e.batch,
                                          style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Card(
                                      color: AppTheme.surfaceVariant,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        leading: CircleAvatar(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: AppTheme.onPrimary,
                                          child: Text(
                                            (e.memberName.isNotEmpty ? e.memberName[0] : '?').toUpperCase(),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(
                                          e.memberName,
                                          style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Chip(
                                            label: Text(e.batch, style: const TextStyle(color: AppTheme.onPrimary, fontWeight: FontWeight.w600)),
                                            backgroundColor: AppTheme.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              timeFormat.format(e.checkInAt),
                                              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20),
                                              tooltip: 'Remove check-in',
                                              onPressed: () => _deleteAttendance(e),
                                              color: Colors.red.shade400,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
