import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/event_model.dart';
import '../../../../data/models/participant_model.dart';
import '../../../widgets/event_countdown_timer.dart';
import 'real_event_detail_widgets.dart';

class EventDetailWhenWhereSection extends StatelessWidget {
  const EventDetailWhenWhereSection({
    super.key,
    required this.event,
    required this.dateText,
    required this.timeText,
    required this.onOpenRoute,
    required this.onOpenParticipants,
  });

  final EventModel event;
  final String dateText;
  final String timeText;
  final VoidCallback? onOpenRoute;
  final VoidCallback onOpenParticipants;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: EventDetailSectionContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EventDetailSectionTitle(
              'Когда и где',
              subtitle: 'Дата, время, таймер и локация события',
            ),
            const SizedBox(height: 14),
            EventDetailInfoRow(
              icon: Icons.calendar_today,
              text: dateText,
            ),
            const SizedBox(height: 12),
            EventDetailInfoRow(
              icon: Icons.access_time,
              text: timeText,
            ),
            const SizedBox(height: 12),
            _CountdownRow(expirationTime: event.actualEndDateTime),
            const SizedBox(height: 12),
            EventDetailInfoRow(
              icon: Icons.location_on,
              text: event.location,
              onTap: onOpenRoute,
            ),
            const SizedBox(height: 18),
            const EventDetailSectionTitle('Участники'),
            const SizedBox(height: 12),
            Row(
              children: [
                if (event.previewParticipants.isNotEmpty)
                  _ParticipantsPreview(participants: event.previewParticipants),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onOpenParticipants,
                  child: _ParticipantsCountPill(count: event.participantsCount),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({required this.expirationTime});

  final DateTime expirationTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFE8EEFF), Color(0xFFE7F6F2)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.timer_outlined,
            color: Color(0xFF5F76FF),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'До окончания',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF66739B),
                ),
              ),
              const SizedBox(height: 4),
              EventCountdownTimer(
                expirationTime: expirationTime,
                isMinimal: true,
                textStyle: const TextStyle(
                  color: Color(0xFF243252),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantsPreview extends StatelessWidget {
  const _ParticipantsPreview({required this.participants});

  final List<ParticipantModel> participants;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 25.0 * (participants.length - 1) + 40,
      height: 40,
      child: Stack(
        children: List.generate(
          participants.length,
          (index) => Positioned(
            left: index * 25.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: participants[index].user.photoUrl != null
                    ? CachedNetworkImageProvider(participants[index].user.photoUrl!)
                    : null,
                child: participants[index].user.photoUrl == null
                    ? Text(
                        participants[index].user.displayName.isNotEmpty
                            ? participants[index].user.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF161823),
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantsCountPill extends StatelessWidget {
  const _ParticipantsCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E9FB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count == 0
                ? 'Нет участников'
                : '$count участник${count % 10 == 1 && count != 11 ? '' : 'ов'}',
            style: const TextStyle(
              color: Color(0xFF243252),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Color(0xFF9E9E9E),
            ),
          ],
        ],
      ),
    );
  }
}

