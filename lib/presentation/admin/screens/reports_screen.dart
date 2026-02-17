import 'package:flutter/material.dart';
import 'package:andexevents/data/models/report_model.dart';
import 'package:andexevents/data/services/report_service.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();
  List<ReportModel> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _reportService.getReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Reports'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(child: Text('No reports found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(report.status),
                          child: Icon(_getReasonIcon(report.reason), color: Colors.white),
                        ),
                        title: Text(report.reason.displayName),
                        subtitle: Text(
                          'Reported ${DateFormat.yMMMd().add_Hm().format(report.createdAt)}',
                        ),
                        trailing: Chip(
                          label: Text(
                            report.status,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                          backgroundColor: _getStatusColor(report.status),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('Report ID:', report.id),
                                _buildDetailRow('Reporter:', report.reporterId),
                                _buildDetailRow('Target User:', report.targetUserId ?? 'N/A'),
                                _buildDetailRow('Target Event:', report.targetEventId ?? 'N/A'),
                                if (report.details != null) ...[
                                  const SizedBox(height: 8),
                                  const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(report.details!),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () {
                                        // TODO: Implement dismiss logic
                                      },
                                      child: const Text('Dismiss'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        // TODO: Implement ban logic
                                      },
                                      icon: const Icon(Icons.block, size: 16),
                                      label: const Text('Ban User'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        // TODO: Implement resolve logic
                                      },
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Resolve'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.green;
      case 'DISMISSED':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getReasonIcon(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return Icons.mail;
      case ReportReason.inappropriateContent:
        return Icons.explicit;
      case ReportReason.harassment:
        return Icons.back_hand;
      case ReportReason.fakeEvent:
        return Icons.event_busy;
      case ReportReason.other:
        return Icons.help_outline;
    }
  }
}
