import '../../../widgets/common/app_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/event_model.dart';
import 'real_event_detail_widgets.dart';

class EventDetailOrganizerSection extends StatelessWidget {
  const EventDetailOrganizerSection({
    super.key,
    required this.event,
    required this.categoryColor,
    required this.onOpenProfile,
  });

  final EventModel event;
  final Color categoryColor;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final name = event.creatorName?.trim();
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: EventDetailSectionContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EventDetailSectionTitle('Организатор'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E9FB)),
              ),
              child: Row(
                children: [
                  if (event.creatorPhotoUrl != null)
                    AppNetworkImage(
                      imageUrl: event.creatorPhotoUrl!,
                      imageBuilder: (context, imageProvider) => CircleAvatar(
                        radius: 26,
                        backgroundImage: imageProvider,
                      ),
                      placeholder: (context, url) => const CircleAvatar(
                        radius: 26,
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
                        radius: 26,
                        backgroundColor: categoryColor,
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: categoryColor,
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF243252),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Организатор событий',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF66739B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: onOpenProfile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5F76FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                        color: Color(0xFFBFD3FF),
                      ),
                    ),
                    child: const Text('Профиль'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

