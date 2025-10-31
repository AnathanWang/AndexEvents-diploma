import 'package:flutter/material.dart';

import '../../models/event_preview.dart';
import '../../widgets/event_card.dart';
import '../../widgets/section_header.dart';

class EventsFeedScreen extends StatelessWidget {
  const EventsFeedScreen({super.key, required this.events});

  final List<EventPreview> events;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: <Widget>[
          const SectionHeader(
            title: 'Афиша недели',
            caption: 'Выбирайте события по интересам и времени',
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Text('Пока нет событий рядом. Добавьте своё!')
          else
            ...events.map((EventPreview event) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EventCard(event: event),
              );
            }),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
            label: const Text('Фильтры и категории'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Расписание мероприятий'),
          ),
        ],
    );
  }
}
