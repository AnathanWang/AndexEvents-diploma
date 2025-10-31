import 'package:flutter/material.dart';

import '../../models/event_preview.dart';
import '../../widgets/event_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/yandex_map_widget.dart';

class MapExploreScreen extends StatelessWidget {
  const MapExploreScreen({super.key, required this.events});

  final List<EventPreview> events;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: <Widget>[
        // Карта с фильтрами
        const SizedBox(
          height: 240,
          child: YandexMapWidget(),
        ),
        const SizedBox(height: 20),
        // Фильтры
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _buildFilterChip('Все события', true),
            _buildFilterChip('Спорт', false),
            _buildFilterChip('Культура', false),
            _buildFilterChip('Музыка', false),
            _buildFilterChip('Образование', false),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'События рядом',
          caption: 'В радиусе 5 км',
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text('Добавьте первое событие на карте!'),
          )
        else
          ...events.map((EventPreview event) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: EventCard(event: event),
          )),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF5E60CE) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF5E60CE) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF4A4D6A),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
