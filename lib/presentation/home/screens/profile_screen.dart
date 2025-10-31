import 'package:flutter/material.dart';

import '../../models/event_preview.dart';
import '../../models/match_preview.dart';
import '../../widgets/admin_panel_snippet.dart';
import '../../widgets/event_card.dart';
import '../../widgets/match_card.dart';
import '../../widgets/section_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.events, required this.matches});

  final List<EventPreview> events;
  final List<MatchPreview> matches;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFF5E60CE),
                  child: Icon(Icons.person_outline, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Андрей Карма', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Люблю техно, митапы и утренние пробежки. Готовится к запуску Andex Events.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Мои мероприятия',
            caption: 'Собственные события и сохранённые планы',
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Text('Начните с создания первого события!')
          else
            ...events.take(2).map((EventPreview event) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EventCard(event: event),
              );
            }),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Добавить новое событие'),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Связи и совпадения',
            caption: 'Последние матчи и приглашения',
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            const Text('Как только произойдут совпадения, они появятся здесь.')
          else
            ...matches.take(2).map((MatchPreview match) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MatchCard(match: match),
              );
            }),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Инструменты модератора',
            caption: 'Доступно для ролей admin и moderator',
          ),
          const SizedBox(height: 12),
          const AdminPanelSnippet(),
        ],
    );
  }
}
