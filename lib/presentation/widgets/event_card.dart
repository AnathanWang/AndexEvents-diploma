import 'package:flutter/material.dart';

import '../models/event_preview.dart';
import '../events/screens/event_detail_screen.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.width});

  final EventPreview event;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => EventDetailScreen(event: event),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(18),
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
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: event.badgeColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              event.category,
              style: TextStyle(
                color: event.badgeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(Icons.schedule, size: 18, color: Color(0xFF5E60CE)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(event.time, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(Icons.place_outlined, size: 18, color: Color(0xFF5E60CE)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(event.distance, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              SizedBox(
                width: 70,
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: List<Widget>.generate(3, (int index) {
                    return Positioned(
                      left: index * 18,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: event.badgeColor.withOpacity(0.7 - index * 0.2),
                        child: const Icon(Icons.person, size: 16, color: Colors.white),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Text('${event.attendees}+ участников', style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
