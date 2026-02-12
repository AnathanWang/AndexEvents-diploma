import 'package:flutter/material.dart';
import 'package:andexevents/data/models/report_model.dart';
import 'package:andexevents/data/services/report_service.dart';
import 'package:andexevents/presentation/widgets/common/custom_notification.dart';

class ReportDialog extends StatefulWidget {
  final String reporterId; // The ID of the user submitting the report
  final String? targetUserId;
  final String? targetEventId;

  const ReportDialog({
    Key? key,
    required this.reporterId,
    this.targetUserId,
    this.targetEventId,
  }) : super(key: key);

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  ReportReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      CustomNotification.show(
        context,
        'Пожалуйста, выберите причину',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ReportService().submitReport(
        reporterId: widget.reporterId,
        targetUserId: widget.targetUserId,
        targetEventId: widget.targetEventId,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close dialog
      CustomNotification.success(
        context,
        'Жалоба отправлена. Спасибо!',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        'Ошибка при отправке жалобы',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Пожаловаться'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выберите причину:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...ReportReason.values.map((reason) {
                return RadioListTile<ReportReason>(
                  title: Text(reason.displayName),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (ReportReason? value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }).toList(),
              const SizedBox(height: 16),
              const Text(
                'Подробности (необязательно):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Опишите проблему...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ],
          ),
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Отправить'),
        ),
      ],
    );
  }
}
