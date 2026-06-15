import 'package:flutter/material.dart';
import '../../../data/models/participant_model.dart';
import '../../widgets/common/network_avatar.dart';

/// Dialog для отображения списка участников события
class EventParticipantsDialog extends StatelessWidget {
  final List<ParticipantModel> participants;
  final String eventTitle;
  final ScrollController? scrollController;

  const EventParticipantsDialog({
    super.key,
    required this.participants,
    required this.eventTitle,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Индикатор перетаскивания
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Участники',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3436),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${participants.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF161823),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Список участников
          Expanded(
            child: participants.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет участников',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: participants.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      return _ParticipantTile(participant: participant);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Плитка для одного участника
class _ParticipantTile extends StatelessWidget {
  final ParticipantModel participant;

  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Аватар
        NetworkAvatar(
          url: participant.user.photoUrl,
          label: participant.user.displayName,
          size: 50,
          fontSize: 18,
        ),
        const SizedBox(width: 16),
        // Информация о пользователе
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                participant.user.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(participant.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusLabel(participant.status),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'GOING':
        return 'Идет на событие';
      case 'INTERESTED':
        return 'Заинтересован';
      case 'MAYBE':
        return 'Может быть';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'GOING':
        return Colors.green;
      case 'INTERESTED':
        return Colors.blue;
      case 'MAYBE':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
