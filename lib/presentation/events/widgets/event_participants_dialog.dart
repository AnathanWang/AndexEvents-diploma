import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/participant_model.dart';

/// Dialog для отображения списка участников события
class EventParticipantsDialog extends StatelessWidget {
  final List<ParticipantModel> participants;
  final String eventTitle;

  const EventParticipantsDialog({
    super.key,
    required this.participants,
    required this.eventTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Участники',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${participants.length} участник${participants.length % 10 == 1 && participants.length != 11 ? '' : 'ов'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Список участников
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: participants.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Аватар
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[300],
            backgroundImage: participant.user.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(participant.user.photoUrl)
                : null,
            child: participant.user.photoUrl.isEmpty
                ? const Icon(Icons.person, size: 28)
                : null,
          ),
          const SizedBox(width: 12),
          // Информация о пользователе
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.user.displayName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  participant.user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusLabel(participant.status),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _getStatusColor(participant.status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
