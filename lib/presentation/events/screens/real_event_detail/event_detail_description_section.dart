import 'package:flutter/material.dart';

import '../../../../data/models/event_model.dart';
import 'real_event_detail_widgets.dart';

class EventDetailDescriptionSection extends StatelessWidget {
  const EventDetailDescriptionSection({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    if (event.description.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: EventDetailSectionContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EventDetailSectionTitle('Описание'),
            const SizedBox(height: 10),
            Text(
              event.description,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF4B5877),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

