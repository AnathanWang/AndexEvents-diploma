import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../events/bloc/event_bloc.dart';
import '../../../events/screens/real_event_detail_screen.dart';
import '../../../../data/models/event_model.dart';
import '../../../widgets/event_countdown_timer.dart';

class SearchHeader extends StatelessWidget {
  const SearchHeader({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF5F5F5),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFF161823),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Поиск событий...',
                hintStyle: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 16,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF75878A),
                  size: 22,
                ),
                suffixIcon: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    if (controller.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.clear),
                      color: const Color(0xFF75878A),
                      onPressed: onClear,
                    );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFFE8E8E8),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFFE8E8E8),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFF75878A),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({
    super.key,
    required this.query,
  });

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: const Color(0xFFE0E0E0),
          ),
          const SizedBox(height: 16),
          Text(
            query.isEmpty ? 'Начните поиск' : 'События не найдены',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9699A8),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchEventCard extends StatelessWidget {
  const SearchEventCard({
    super.key,
    required this.event,
  });

  final EventModel event;

  String _participantsWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'участник';
    } else if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'участника';
    } else {
      return 'участников';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM, HH:mm', 'ru_RU');
    final eventDate = event.dateTime;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                BlocProvider(
              create: (context) => EventBloc(),
              child: RealEventDetailScreen(eventId: event.id),
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              final curve = Curves.easeOutCubic;
              final curvedAnimation = curve.transform(animation.value);
              final tween = Tween(begin: begin, end: end);
              final offsetAnimation = tween.animate(
                AlwaysStoppedAnimation(curvedAnimation),
              );

              return SlideTransition(position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 280),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              child: CachedNetworkImage(
                imageUrl: event.imageUrl ?? '',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFFE8E8E8),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF75878A)),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFFE8E8E8),
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF161823),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Color(0xFF9699A8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(eventDate),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9699A8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: 14,
                          color: Color(0xFF9699A8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${event.participantsCount} ${_participantsWord(event.participantsCount)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9699A8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    EventCountdownTimer(
                      expirationTime: event.actualEndDateTime,
                      isMinimal: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

