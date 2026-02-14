import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const _apiBase = 'http://localhost:8000';
const _deepBlack = Color(0xFF0D0D0D);
const _gold = Color(0xFFD4AF37);

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

    try {
      final response = await http
          .get(Uri.parse('$_apiBase/attendance/today'))
          .timeout(const Duration(seconds: 10));

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _gold),
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
                          style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepBlack),
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
                          Text('No check-ins today (IST)', style: TextStyle(color: Colors.grey.shade400, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('Check-ins will appear here', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _gold,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sortedByBatch().length,
                        itemBuilder: (context, index) {
                          final e = _sortedByBatch()[index];
                          final showBatchHeader = index == 0 ||
                              _sortedByBatch()[index - 1].batch != e.batch;
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
                                      color: _gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                              Card(
                                color: const Color(0xFF1A1A1A),
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: _gold, width: 0.5),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  leading: CircleAvatar(
                                    backgroundColor: _gold,
                                    foregroundColor: _deepBlack,
                                    child: Text(
                                      (e.memberName.isNotEmpty ? e.memberName[0] : '?').toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    e.memberName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Chip(
                                      label: Text(e.batch, style: const TextStyle(color: _deepBlack, fontWeight: FontWeight.w600)),
                                      backgroundColor: _gold,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  trailing: Text(
                                    timeFormat.format(e.checkInAt),
                                    style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
    );
  }
}
