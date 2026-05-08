import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import 'create_event_widgets.dart';

class CreateEventScheduleSection extends StatelessWidget {
  const CreateEventScheduleSection({
    super.key,
    required this.decoration,
    required this.selectedDate,
    required this.selectedTime,
    required this.hasEndDateTime,
    required this.selectedEndDate,
    required this.selectedEndTime,
    required this.onPickDate,
    required this.onPickTime,
    required this.onToggleHasEnd,
    required this.onPickEndDate,
    required this.onPickEndTime,
    required this.inputDecorationBuilder,
  });

  final BoxDecoration decoration;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final bool hasEndDateTime;
  final DateTime selectedEndDate;
  final TimeOfDay selectedEndTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<bool> onToggleHasEnd;
  final VoidCallback onPickEndDate;
  final VoidCallback onPickEndTime;
  final InputDecoration Function({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffix,
    bool alignLabelWithHint,
  }) inputDecorationBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CreateEventSectionHeader(
            icon: Icons.schedule_rounded,
            title: 'Когда',
            subtitle: 'Дата и время начала (и окончания при необходимости)',
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: inputDecorationBuilder(
                      label: 'Дата',
                      icon: Icons.calendar_today_rounded,
                      alignLabelWithHint: false,
                    ),
                    child: Text(
                      DateFormat('dd.MM.yyyy').format(selectedDate),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onPickTime,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: inputDecorationBuilder(
                      label: 'Время',
                      icon: Icons.access_time_rounded,
                      alignLabelWithHint: false,
                    ),
                    child: Text(
                      selectedTime.format(context),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: SwitchListTile(
              title: Text(
                'Указать окончание',
                style: TextStyle(
                  color: AppColors.dark.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                hasEndDateTime
                    ? 'Будет показано время окончания'
                    : 'Полезно для расписания и поиска',
                style: TextStyle(
                  color: AppColors.dark.withValues(alpha: 0.58),
                ),
              ),
              value: hasEndDateTime,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.22),
              onChanged: onToggleHasEnd,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: hasEndDateTime
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: InkWell(
                            onTap: onPickEndDate,
                            borderRadius: BorderRadius.circular(16),
                            child: InputDecorator(
                              decoration: inputDecorationBuilder(
                                label: 'Дата окончания',
                                icon: Icons.event_available_rounded,
                                alignLabelWithHint: false,
                              ),
                              child: Text(
                                DateFormat('dd.MM.yyyy').format(selectedEndDate),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.dark.withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: onPickEndTime,
                            borderRadius: BorderRadius.circular(16),
                            child: InputDecorator(
                              decoration: inputDecorationBuilder(
                                label: 'Время окончания',
                                icon: Icons.more_time_rounded,
                                alignLabelWithHint: false,
                              ),
                              child: Text(
                                selectedEndTime.format(context),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.dark.withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

