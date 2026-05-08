import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/event_draft_model.dart';

class CreateEventDraftsSheet extends StatelessWidget {
  const CreateEventDraftsSheet({
    super.key,
    required this.drafts,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final List<EventDraftModel> drafts;
  final ValueChanged<EventDraftModel> onOpen;
  final Future<void> Function(EventDraftModel draft) onRename;
  final Future<void> Function(EventDraftModel draft) onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: AppColors.primary.withValues(alpha: 0.92),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Черновики',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dark.withValues(alpha: 0.86),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.dark.withValues(alpha: 0.65),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: drafts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final draft = drafts[index];
                          final savedAtLabel = DateFormat(
                            'dd.MM.yyyy HH:mm',
                            'ru',
                          ).format(draft.savedAt.toLocal());

                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.84),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        draft.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.dark.withValues(alpha: 0.86),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        savedAtLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.dark.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Переименовать',
                                  onPressed: () => onRename(draft),
                                  icon: const Icon(Icons.edit_rounded, size: 20),
                                  color: AppColors.dark.withValues(alpha: 0.62),
                                ),
                                IconButton(
                                  tooltip: 'Удалить',
                                  onPressed: () => onDelete(draft),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  color: Colors.redAccent.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  onPressed: () => onOpen(draft),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.92),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Открыть',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

