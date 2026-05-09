import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/event_sanction_model.dart';
import '../../../data/services/event_sanction_service.dart';
import '../../../data/services/event_service.dart';
import '../widgets/admin_card.dart';
import '../widgets/admin_pill.dart';
import '../widgets/moderation_toggle_chip.dart';
import 'event_moderation_item.dart';

class EventSanctionsSheet extends StatefulWidget {
  const EventSanctionsSheet({
    super.key,
    required this.item,
    required this.service,
    required this.onChanged,
  });

  final EventModerationItem item;
  final EventSanctionService service;
  final Future<void> Function() onChanged;

  @override
  State<EventSanctionsSheet> createState() => _EventSanctionsSheetState();
}

class _EventSanctionsSheetState extends State<EventSanctionsSheet> {
  bool _isLoading = true;
  String? _loadError;
  bool _actionInProgress = false;

  List<EventSanctionModel> _sanctions = <EventSanctionModel>[];
  EventSanctionType _selectedType = EventSanctionType.freezeParticipation;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results =
          await widget.service.getActiveSanctions(widget.item.event.id);
      if (!mounted) return;
      setState(() {
        _sanctions = results;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  String _typeLabel(EventSanctionType type) {
    switch (type) {
      case EventSanctionType.hideVisibility:
        return 'Hide';
      case EventSanctionType.freezeParticipation:
        return 'Freeze';
      case EventSanctionType.limitEdits:
        return 'Limit edits';
    }
  }

  Color _typeColor(EventSanctionType type) {
    switch (type) {
      case EventSanctionType.hideVisibility:
        return const Color(0xFF6D4CFF);
      case EventSanctionType.freezeParticipation:
        return const Color(0xFFD16A3A);
      case EventSanctionType.limitEdits:
        return const Color(0xFF2E9E71);
    }
  }

  Future<void> _create() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите причину')),
      );
      return;
    }

    int? days;
    final rawDays = _daysController.text.trim();
    if (rawDays.isNotEmpty) {
      days = int.tryParse(rawDays);
      if (days == null || days <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Срок должен быть числом дней > 0')),
        );
        return;
      }
    }

    setState(() => _actionInProgress = true);
    try {
      await widget.service.createSanction(
        eventId: widget.item.event.id,
        type: _selectedType,
        reason: reason,
        expiresAt:
            days == null ? null : DateTime.now().add(Duration(days: days)),
      );
      await _eventService.clearEventsCache();
      _reasonController.clear();
      _daysController.clear();
      await _load();
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Санкция применена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось применить санкцию: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _revoke(EventSanctionModel sanction) async {
    setState(() => _actionInProgress = true);
    try {
      await widget.service.revokeSanction(sanction.id);
      await _eventService.clearEventsCache();
      await _load();
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Санкция отозвана')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отозвать санкцию: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.item.event;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.dark.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.gavel_rounded,
                  color: AppColors.primary.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Санкции события',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AdminCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onLongPress: () async {
                      await Clipboard.setData(ClipboardData(text: event.id));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Event ID скопирован')),
                      );
                    },
                    child: Text(
                      'ID: ${event.id}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.dark.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              AdminCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Не удалось загрузить санкции',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loadError!,
                      style: TextStyle(
                        color: AppColors.dark.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _actionInProgress ? null : _load,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Повторить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            AppColors.dark.withValues(alpha: 0.72),
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              AdminCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Активные санкции',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        AdminPill(
                          label: '${_sanctions.length}',
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.10),
                          foregroundColor: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_sanctions.isEmpty)
                      Text(
                        'Нет активных санкций',
                        style: TextStyle(
                          color: AppColors.dark.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      ..._sanctions.map((s) {
                        final typeColor = _typeColor(s.type);
                        final expires = s.expiresAt == null
                            ? null
                            : DateFormat('dd.MM.yyyy', 'ru')
                                .format(s.expiresAt!);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AdminCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AdminPill(
                                      label: _typeLabel(s.type),
                                      backgroundColor:
                                          typeColor.withValues(alpha: 0.12),
                                      foregroundColor: typeColor,
                                    ),
                                    const SizedBox(width: 8),
                                    if (expires != null)
                                      Text(
                                        'до $expires',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.dark
                                              .withValues(alpha: 0.60),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    const Spacer(),
                                    OutlinedButton(
                                      onPressed: _actionInProgress
                                          ? null
                                          : () => _revoke(s),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.dark
                                            .withValues(alpha: 0.72),
                                        side: BorderSide(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.14),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        'Отозвать',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.reason,
                                  style: TextStyle(
                                    color: AppColors.dark
                                        .withValues(alpha: 0.80),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onLongPress: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: s.id),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('ID санкции скопирован'),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'ID: ${s.id}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.dark
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AdminCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Назначить санкцию',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ModerationToggleChip(
                            label: _typeLabel(EventSanctionType.hideVisibility),
                            selected: _selectedType ==
                                EventSanctionType.hideVisibility,
                            onTap: _actionInProgress
                                ? () {}
                                : () => setState(() => _selectedType =
                                    EventSanctionType.hideVisibility),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ModerationToggleChip(
                            label: _typeLabel(
                              EventSanctionType.freezeParticipation,
                            ),
                            selected: _selectedType ==
                                EventSanctionType.freezeParticipation,
                            onTap: _actionInProgress
                                ? () {}
                                : () => setState(() => _selectedType =
                                    EventSanctionType.freezeParticipation),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ModerationToggleChip(
                            label: _typeLabel(EventSanctionType.limitEdits),
                            selected:
                                _selectedType == EventSanctionType.limitEdits,
                            onTap: _actionInProgress
                                ? () {}
                                : () => setState(() => _selectedType =
                                    EventSanctionType.limitEdits),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reasonController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Причина (обязательно)',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.72),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _daysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Срок (дней) — опционально',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.72),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _actionInProgress ? null : _create,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Применить',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
