import 'package:flutter/material.dart';

import '../models/event_preview.dart';
import '../models/match_preview.dart';

class SampleData {
  const SampleData._();

  static final List<EventPreview> events = <EventPreview>[
    EventPreview(
      title: 'Andex Meetup: Networking & Coffee',
      category: 'Комьюнити',
      time: 'Сегодня · 19:00',
      distance: '1,2 км от вас',
      badgeColor: const Color(0xFF5E60CE),
      attendees: 42,
      date: DateTime.now().add(const Duration(hours: 3)),
      location: 'Кофейня "The Brew", ул. Тверская 12',
      price: 0,
      attendeeNames: const <String>['Алексей', 'Мария', 'Игорь', 'Анна', 'Дмитрий'],
    ),
    EventPreview(
      title: 'Sunrise Yoga в Парке Горького',
      category: 'Здоровье',
      time: 'Завтра · 07:30',
      distance: '3,5 км от вас',
      badgeColor: const Color(0xFF4ECCA3),
      attendees: 18,
      date: DateTime.now().add(const Duration(days: 1, hours: 7, minutes: 30)),
      location: 'Парк Горького, Центральная поляна',
      price: 500,
      attendeeNames: const <String>['Ольга', 'Светлана', 'Екатерина'],
    ),
    EventPreview(
      title: 'Techno Night by Local DJs',
      category: 'Музыка',
      time: 'Пятница · 22:00',
      distance: '850 м от вас',
      badgeColor: const Color(0xFFFF8383),
      attendees: 76,
      date: DateTime.now().add(const Duration(days: 4, hours: 22)),
      location: 'Клуб "Forma", Трубная площадь 2',
      price: 1500,
      attendeeNames: const <String>['Максим', 'Виктория', 'Андрей', 'Полина'],
    ),
  ];

  static const List<MatchPreview> matches = <MatchPreview>[
    MatchPreview(
      name: 'Лиза, 24',
      subtitle: 'Ищет напарника на TEDx',
      avatarColor: Color(0xFF5E60CE),
      matchPercentage: 89,
      commonInterests: <String>['Технологии', 'Нетворкинг', 'Стартапы'],
    ),
    MatchPreview(
      name: 'Никита, 27',
      subtitle: 'Пойдет на Jazz Rooftop',
      avatarColor: Color(0xFF4ECCA3),
      matchPercentage: 76,
      commonInterests: <String>['Джаз', 'Музыка', 'Вечеринки'],
    ),
    MatchPreview(
      name: 'Камила, 22',
      subtitle: 'Организует Art Picnic',
      avatarColor: Color(0xFFFF8383),
      matchPercentage: 92,
      commonInterests: <String>['Искусство', 'Пикники', 'Фотография', 'Дизайн'],
    ),
  ];
}
