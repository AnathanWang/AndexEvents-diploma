import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../widgets/common/custom_notification.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/event_participants_manage_service.dart';
import '../../../../data/models/managed_participant_model.dart';
import '../../../../data/models/waitlist_entry_model.dart';
import '../../../../data/models/user_preview_model.dart';

class EventManageParticipantsSheet extends StatefulWidget {
  const EventManageParticipantsSheet({
    super.key,
    required this.eventId,
    required this.service,
  });

  final String eventId;
  final EventParticipantsManageService service;

  @override
  State<EventManageParticipantsSheet> createState() =>
      _EventManageParticipantsSheetState();
}

class _EventManageParticipantsSheetState
    extends State<EventManageParticipantsSheet> {
  int _tab = 0;
  bool _loading = true;
  bool _actionInProgress = false;
  String? _error;

  List<ManagedParticipantModel> _participants = const [];
  List<WaitlistEntryModel> _waitlist = const [];
  List<UserPreviewModel> _blocked = const [];

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
      final results = await Future.wait<dynamic>([
        widget.service.listManageParticipants(widget.eventId),
        widget.service.listWaitlist(widget.eventId),
        widget.service.listGlobalBlocked(),
      ]);
      if (!mounted) return;
      setState(() {
        _participants = results[0] as List<ManagedParticipantModel>;
        _waitlist = results[1] as List<WaitlistEntryModel>;
        _blocked = results[2] as List<UserPreviewModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _actionInProgress = true);
    try {
      await fn();
      await _load();
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        e.toString().replaceFirst('Exception: ', '').trim(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Widget _pill(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.86;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Управление участниками',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark.withValues(alpha: 0.88),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _actionInProgress ? null : _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Segmented(
                            index: _tab,
                            labels: const ['Участники', 'Ожидание', 'Блоклист'],
                            onChanged: (v) => setState(() => _tab = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 44,
                                        color: Colors.redAccent,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        onPressed: _load,
                                        child: const Text('Повторить'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : _tab == 0
                                ? _buildParticipants()
                                : _tab == 1
                                    ? _buildWaitlist()
                                    : _buildBlocked(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipants() {
    if (_participants.isEmpty) {
      return _EmptyState(
        title: 'Пока никого нет',
        subtitle: 'Когда участники появятся — вы сможете управлять списком здесь.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _participants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = _participants[i];
        final u = p.participant.user;
        return _GlassRow(
          leading: _Avatar(url: u.photoUrl, label: u.displayName),
          title: u.displayName,
          subtitle: u.email ?? '',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pill(
                p.checkedIn ? 'CHECK‑IN' : 'NO CHECK‑IN',
                bg: p.checkedIn
                    ? const Color(0xFFE7FBEE)
                    : const Color(0xFFFFF3E6),
                fg: p.checkedIn
                    ? const Color(0xFF1F9E57)
                    : const Color(0xFFB66A1E),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                enabled: !_actionInProgress,
                onSelected: (v) {
                  if (v == 'kick') {
                    _run(() => widget.service.kick(widget.eventId, p.participant.userId));
                  } else if (v == 'ban') {
                    _run(() => widget.service.banForEvent(widget.eventId, p.participant.userId));
                  } else if (v == 'checkin') {
                    _run(() => widget.service.setCheckIn(
                          widget.eventId,
                          p.participant.userId,
                          checkedIn: !p.checkedIn,
                        ));
                  } else if (v == 'block') {
                    _run(() => widget.service.blockGlobally(p.participant.userId));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'checkin', child: Text('Toggle check‑in')),
                  PopupMenuItem(value: 'kick', child: Text('Кикнуть')),
                  PopupMenuItem(value: 'ban', child: Text('Забанить на событии')),
                  PopupMenuItem(value: 'block', child: Text('Заблокировать глобально')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaitlist() {
    if (_waitlist.isEmpty) {
      return _EmptyState(
        title: 'Лист ожидания пуст',
        subtitle: 'Заявки попадут сюда, если у события есть лимит участников.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _waitlist.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final w = _waitlist[i];
        final user = w.user;
        return _GlassRow(
          leading: _Avatar(url: user.photoUrl, label: user.displayName),
          title: user.displayName,
          subtitle: user.email ?? '',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: _actionInProgress
                    ? null
                    : () => _run(() => widget.service.rejectWaitlist(widget.eventId, user.id)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Откл.'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _actionInProgress
                    ? null
                    : () => _run(() => widget.service.approveWaitlist(widget.eventId, user.id)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Принять'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlocked() {
    if (_blocked.isEmpty) {
      return _EmptyState(
        title: 'Блоклист пуст',
        subtitle: 'Здесь будут пользователи, которых вы заблокировали глобально.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _blocked.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final u = _blocked[i];
        return _GlassRow(
          leading: _Avatar(url: u.photoUrl, label: u.displayName),
          title: u.displayName,
          subtitle: u.email ?? '',
          trailing: OutlinedButton(
            onPressed: _actionInProgress ? null : () => _run(() => widget.service.unblockGlobally(u.id)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.34)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Разблок.'),
          ),
        );
      },
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.34)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: selected
                          ? AppColors.primary
                          : AppColors.dark.withValues(alpha: 0.64),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 44,
              color: AppColors.dark.withValues(alpha: 0.38),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.dark.withValues(alpha: 0.84),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.dark.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassRow extends StatelessWidget {
  const _GlassRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark.withValues(alpha: 0.86),
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.label});

  final String? url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      alignment: Alignment.center,
      child: url != null && url!.trim().isNotEmpty
          ? ClipOval(
              child: Image.network(
                url!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials(initials),
              ),
            )
          : _initials(initials),
    );
  }

  Widget _initials(String initials) {
    return Text(
      initials.isEmpty ? '??' : initials,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        color: AppColors.primary.withValues(alpha: 0.92),
      ),
    );
  }
}

