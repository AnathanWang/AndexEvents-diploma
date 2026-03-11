import 'package:flutter/material.dart';

class EventModerationScreen extends StatelessWidget {
  const EventModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data
    final events = List.generate(5, (index) => {
      'id': 'event_$index',
      'title': 'Community Meetup $index',
      'organizer': 'Organizer $index',
      'date': '2026-03-${10 + index}',
      'description': 'A great event for everyone to join and have fun.',
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF5E60CE),
                      Color(0xFF9370DB),
                    ],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Модерация событий',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF5E60CE)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Event list
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = events[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event Image
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF5E60CE).withOpacity(0.3),
                                  const Color(0xFF9370DB).withOpacity(0.3),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_rounded,
                                size: 64,
                                color: Color(0xFF5E60CE),
                              ),
                            ),
                          ),

                          // Event Info
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A4D6A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F2FB),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: Color(0xFF5E60CE),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            event['date'] as String,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF4A4D6A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F2FB),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.person,
                                            size: 14,
                                            color: Color(0xFF5E60CE),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            event['organizer'] as String,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF4A4D6A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  event['description'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF9E9E9E),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Icons.close,
                                          size: 18,
                                        ),
                                        label: const Text('Отклонить'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFFF6B6B),
                                          side: const BorderSide(
                                            color: Color(0xFFFF6B6B),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Icons.check,
                                          size: 18,
                                        ),
                                        label: const Text('Одобрить'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF5E60CE),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: events.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
