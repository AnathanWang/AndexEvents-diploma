import 'package:flutter/material.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/event_messages.dart';
import 'dart:ui';

import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import '../../../data/models/event_model.dart';
import '../../../data/services/external_route_service.dart';
import '../widgets/event_participants_dialog.dart';
import '../../matches/screens/event_match_screen.dart';
import '../../widgets/event_countdown_timer.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../widgets/common/star_rating_widget.dart';
import '../../../data/services/rating_service.dart';
import '../../../data/services/user_service.dart';
import '../../../core/http/api_client.dart';
import '../../../data/models/event_review_model.dart';

const Color _secondaryTextColor = Color(0xFF5E6D86);


class RealEventDetailScreen extends StatefulWidget {
  final String eventId;

  const RealEventDetailScreen({super.key, required this.eventId});

  @override
  State<RealEventDetailScreen> createState() => _RealEventDetailScreenState();
}

class _RealEventDetailScreenState extends State<RealEventDetailScreen> {
  final ValueNotifier<bool> _isFavoriteNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isGoingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isFavoriteLoadingNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isGoingLoadingNotifier =
      ValueNotifier<bool>(false);
  int _currentImageIndex = 0;
  EventModel? _cachedEvent;
  final ExternalRouteService _routeService = ExternalRouteService();
  final UserService _userService = UserService();
  final RatingService _ratingService = RatingService(ApiClient());
  final ValueNotifier<int?> _myRatingNotifier = ValueNotifier<int?>(null);
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    // Delay the event loading to ensure BlocProvider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventBloc>().add(EventDetailLoadRequested(widget.eventId));
    });
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final user = await _userService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUserId = user.id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
      });
    }
  }

  void _toggleFavorite(EventModel event) {
    if (_isEventFinished(event)) {
      CustomNotification.show(
        context,
        EventMessages.eventFinishedActionBlocked,
      );
      _isFavoriteLoadingNotifier.value = false;
      return;
    }

    _isFavoriteLoadingNotifier.value = true;

    if (!_isFavoriteNotifier.value) {
      context.read<EventBloc>().add(
        EventParticipateRequested(eventId: event.id, status: 'INTERESTED'),
      );
    } else {
      context.read<EventBloc>().add(
        EventCancelParticipationRequested(event.id),
      );
    }
  }

  void _toggleGoing(EventModel event) {
    if (_isEventFinished(event)) {
      CustomNotification.show(
        context,
        EventMessages.eventFinishedActionBlocked,
      );
      _isGoingLoadingNotifier.value = false;
      return;
    }

    _isGoingLoadingNotifier.value = true;

    if (!_isGoingNotifier.value) {
      context.read<EventBloc>().add(
        EventParticipateRequested(eventId: event.id, status: 'GOING'),
      );
    } else {
      context.read<EventBloc>().add(
        EventCancelParticipationRequested(event.id),
      );
    }
  }

  @override
  void dispose() {
    _isFavoriteNotifier.dispose();
    _isGoingNotifier.dispose();
    _isFavoriteLoadingNotifier.dispose();
    _isGoingLoadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _openRoute(EventModel event) async {
    if (event.isOnline) {
      CustomNotification.show(
        context,
        'Для онлайн-событий маршрут недоступен',
      );
      return;
    }

    final opened = await _routeService.openRouteToDestination(
      latitude: event.latitude,
      longitude: event.longitude,
      label: event.title,
    );

    if (!opened && mounted) {
      CustomNotification.show(
        context,
        'Не удалось открыть приложение навигации',
        isError: true,
      );
    }
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDFE7FF)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2F4E8A).withValues(alpha: 0.1),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF243252),
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF66739B),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EventBloc, EventState>(
      listenWhen: (previous, current) {
        // Слушаем все состояния для обновления кнопки участия
        return true;
      },
      listener: (context, state) {
        if (state is EventDetailLoaded) {
          _isGoingNotifier.value = state.event.isParticipating;
          _isFavoriteNotifier.value =
              state.event.userParticipationStatus == 'INTERESTED';
          _myRatingNotifier.value = state.event.myRating;
          _isFavoriteLoadingNotifier.value = false;
          _isGoingLoadingNotifier.value = false;
        } else if (state is EventParticipationUpdating) {
          // Локальные индикаторы уже включаются при нажатии соответствующей кнопки.
        } else if (state is EventParticipationUpdated) {
          // Ждем EventDetailLoaded, где индикаторы выключаются точечно.
        } else if (state is EventError) {
          _isFavoriteLoadingNotifier.value = false;
          _isGoingLoadingNotifier.value = false;
          CustomNotification.show(context, state.message, isError: true);
        }
      },
      buildWhen: (previous, current) {
        if (current is EventParticipantsLoading ||
            current is EventParticipantsLoaded ||
            current is EventParticipationUpdating ||
            current is EventParticipationUpdated) {
          return false;
        }

        // После первого успешного лоада не перестраиваем весь экран
        // на detail-reload после нажатий лайк/участвовать.
        if (_cachedEvent != null &&
            (current is EventDetailLoading || current is EventDetailLoaded)) {
          return false;
        }

        return true;
      },
      builder: (context, state) {
        if (_cachedEvent != null) {
          return _buildEventDetail(context, _cachedEvent!);
        }

        if (state is EventDetailLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is EventError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ошибка')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<EventBloc>().add(
                        EventDetailLoadRequested(widget.eventId),
                      );
                    },
                    child: const Text('Попробовать снова'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is EventDetailLoaded) {
          _cachedEvent = state.event;
          return _buildEventDetail(context, state.event);
        }

        return const Scaffold(body: Center(child: Text('Загрузка...')));
      },
    );
  }

  Widget _buildEventDetail(BuildContext context, EventModel event) {
    final categoryColor = _getCategoryColor(event.category);
    final categoryName = _getCategoryName(event.category);
    final isEventFinished = _isEventFinished(event);
    final imageGallery = event.imageUrls.isNotEmpty
        ? event.imageUrls
        : <String>[
            if ((event.imageUrl ?? '').trim().isNotEmpty) event.imageUrl!.trim(),
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFFEAF2FF),
                    Color(0xFFD9E8FF),
                    Color(0xFFEFF5FF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F6CF8).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8CB9FF).withValues(alpha: 0.14),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
          // App Bar с изображением
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF365892).withValues(alpha: 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF243252)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              _buildFavoriteAction(event),
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF365892).withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Color(0xFF243252)),
                  onPressed: () {},
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageGallery.isNotEmpty)
                    PageView.builder(
                      itemCount: imageGallery.length,
                      onPageChanged: (index) {
                        if (!mounted) return;
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: imageGallery[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade300,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  categoryColor.withValues(alpha: 0.88),
                                  AppColors.primary.withValues(alpha: 0.64),
                                  AppColors.accent.withValues(alpha: 0.44),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.event,
                              size: 120,
                              color: Colors.white38,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            categoryColor.withValues(alpha: 0.88),
                            AppColors.primary.withValues(alpha: 0.64),
                            AppColors.accent.withValues(alpha: 0.44),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.event,
                        size: 120,
                        color: Colors.white38,
                      ),
                    ),
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.04),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.46),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (imageGallery.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: IgnorePointer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            imageGallery.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == index
                                    ? Colors.white
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Контент
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildSectionContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    categoryColor.withValues(alpha: 0.18),
                                    categoryColor.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: categoryColor.withValues(alpha: 0.26),
                                ),
                              ),
                              child: Text(
                                categoryName,
                                style: TextStyle(
                                  color: categoryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: event.price == 0
                                    ? const Color(0xFFE5F7EF)
                                    : const Color(0xFFFFF0DB),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: event.price == 0
                                      ? const Color(0xFFBEE8D1)
                                      : const Color(0xFFF6D3A3),
                                ),
                              ),
                              child: Text(
                                event.price == 0
                                    ? 'Бесплатно'
                                    : '${event.price.toStringAsFixed(0)} ₽',
                                style: TextStyle(
                                  color: event.price == 0
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F3552),
                          ),
                        ),
                        
                        // Рейтинг + отзывы
                        if (event.ratingCount > 0 || (_isEventFinished(event) && _isCreator(event)))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                if (event.ratingCount > 0) ...[
                                  StarRatingWidget(
                                    rating: event.averageRating,
                                    starSize: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${event.averageRating.toStringAsFixed(1)} (${event.ratingCount})',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F3552).withValues(alpha: 0.6),
                                    ),
                                  ),
                                ] else
                                  Text(
                                    'Пока нет оценок',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F3552).withValues(alpha: 0.5),
                                    ),
                                  ),
                                const Spacer(),
                                if (_isEventFinished(event) && _isCreator(event))
                                  TextButton.icon(
                                    onPressed: () => _showReviewsBottomSheet(event),
                                    icon: const Icon(Icons.rate_review_rounded, size: 16),
                                    label: const Text('Отзывы'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Дата и время (с учетом даты окончания)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          'Когда и где',
                          subtitle: 'Дата, время, таймер и локация события',
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow(
                          Icons.calendar_today,
                          event.endDateTime != null &&
                                  !_isSameCalendarDate(event.dateTime, event.endDateTime!)
                              ? '${_formatDate(event.dateTime)} - ${_formatDate(event.endDateTime!)}'
                              : _formatDate(event.dateTime),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.access_time,
                          event.endDateTime != null
                              ? '${_formatTime(event.dateTime)} - ${_formatTime(event.endDateTime!)}'
                              : _formatTime(event.dateTime),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: <Color>[
                                    Color(0xFFE8EEFF),
                                    Color(0xFFE7F6F2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.timer_outlined,
                                color: Color(0xFF5F76FF),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'До окончания',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF66739B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  EventCountdownTimer(
                                    expirationTime: event.actualEndDateTime,
                                    isMinimal: true,
                                    textStyle: const TextStyle(
                                      color: Color(0xFF243252),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.location_on,
                          event.location,
                          onTap: event.isOnline ? null : () => _openRoute(event),
                        ),
                        const SizedBox(height: 18),
                        _buildSectionTitle('Участники'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (event.previewParticipants.isNotEmpty)
                              SizedBox(
                                width:
                                    25.0 *
                                        (event.previewParticipants.length - 1) +
                                    40,
                                height: 40,
                                child: Stack(
                                  children: List.generate(
                                    event.previewParticipants.length,
                                    (index) => Positioned(
                                      left: index * 25.0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.grey[200],
                                          backgroundImage:
                                              event
                                                      .previewParticipants[index]
                                                      .user
                                                      .photoUrl !=
                                                  null
                                              ? CachedNetworkImageProvider(
                                                  event
                                                      .previewParticipants[index]
                                                      .user
                                                      .photoUrl!,
                                                )
                                              : null,
                                          child:
                                              event
                                                      .previewParticipants[index]
                                                      .user
                                                      .photoUrl ==
                                                  null
                                              ? Text(
                                                  event
                                                          .previewParticipants[index]
                                                          .user
                                                          .displayName
                                                          .isNotEmpty
                                                      ? event
                                                          .previewParticipants[index]
                                                          .user
                                                          .displayName[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    color: Color(0xFF161823),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                context.read<EventBloc>().add(
                                  EventParticipantsLoadRequested(event.id),
                                );
                                _showParticipantsDialog(context, event);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F8FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFE2E9FB),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      event.participantsCount == 0
                                          ? 'Нет участников'
                                          : '${event.participantsCount} участник${event.participantsCount % 10 == 1 && event.participantsCount != 11 ? '' : 'ов'}',
                                      style: const TextStyle(
                                        color: Color(0xFF243252),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (event.participantsCount > 0) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: Color(0xFF9E9E9E),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            ValueListenableBuilder<bool>(
                              valueListenable: _isGoingNotifier,
                              builder: (context, isGoing, _) {
                                if (!isGoing || isEventFinished) {
                                  return const SizedBox.shrink();
                                }

                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        categoryColor.withValues(alpha: 0.16),
                                        categoryColor.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: categoryColor.withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EventMatchScreen(
                                              eventId: event.id,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          'Метчи',
                                          style: TextStyle(
                                            color: categoryColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (event.description.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _buildSectionTitle('Описание'),
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
                        if (event.creatorName != null) ...[
                          const SizedBox(height: 18),
                          _buildSectionTitle('Организатор'),
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
                                  CachedNetworkImage(
                                    imageUrl: event.creatorPhotoUrl!,
                                    imageBuilder: (context, imageProvider) =>
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundImage: imageProvider,
                                        ),
                                    placeholder: (context, url) =>
                                        const CircleAvatar(
                                          radius: 26,
                                          child: CircularProgressIndicator(),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor: categoryColor,
                                          child: Text(
                                            event.creatorName![0].toUpperCase(),
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
                                      event.creatorName![0].toUpperCase(),
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
                                        event.creatorName!,
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
                                  onPressed: () => _openOrganizerProfile(event),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (!event.isOnline) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSectionContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Маршрут',
                            subtitle: 'Карта и быстрый переход в навигацию',
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              height: 180,
                              child: IgnorePointer(
                                child: YandexMap(
                                  onMapCreated: (controller) {
                                    controller.moveCamera(
                                      CameraUpdate.newCameraPosition(
                                        CameraPosition(
                                          target: Point(
                                            latitude: event.latitude,
                                            longitude: event.longitude,
                                          ),
                                          zoom: 13,
                                        ),
                                      ),
                                    );
                                  },
                                  mapObjects: [
                                    PlacemarkMapObject(
                                      mapId: const MapObjectId('event_detail_point'),
                                      point: Point(
                                        latitude: event.latitude,
                                        longitude: event.longitude,
                                      ),
                                      icon: PlacemarkIcon.single(
                                        PlacemarkIconStyle(
                                          image: BitmapDescriptor.fromAssetImage(
                                            'assets/icons/map_arrow.png',
                                          ),
                                          scale: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _openRoute(event),
                              icon: const Icon(Icons.route),
                              label: const Text('Построить маршрут'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5F76FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    ],
  ),

      // Нижняя панель с кнопкой участия
      bottomSheet: SafeArea(
        child: _buildFloatingActionPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildParticipationButton(event, categoryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionPanel({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.dark.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteAction(EventModel event) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF365892).withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: _isFavoriteNotifier,
        builder: (context, isFavorite, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: _isFavoriteLoadingNotifier,
            builder: (context, isLoading, __) {
              final isEventFinished = _isEventFinished(event);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_outline,
                  color: isFavorite ? const Color(0xFFDE5A77) : const Color(0xFF243252),
                ),
                onPressed: (isLoading || isEventFinished)
                    ? null
                    : () => _toggleFavorite(event),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openOrganizerProfile(EventModel event) async {
    final creatorId = event.createdById?.trim();
    if (creatorId != null && creatorId.isNotEmpty) {
      try {
        final user = await _userService.getUserById(creatorId);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => UserProfileScreen.fromUser(user: user),
          ),
        );
        return;
      } catch (_) {
        if (!mounted) return;
        CustomNotification.show(
          context,
          'Не удалось открыть профиль организатора',
        );
      }
    }

    final name = event.creatorName?.trim();
    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UserProfileScreen(
          userName: name,
          userInitials: initials.isEmpty ? '??' : initials,
        ),
      ),
    );
  }

  Widget _buildParticipationButton(EventModel event, Color categoryColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isGoingLoadingNotifier,
      builder: (context, isLoading, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _isGoingNotifier,
          builder: (context, isGoing, __) {
            final isEventFinished = _isEventFinished(event);
            final myRating = _myRatingNotifier.value;
            final canRate = isEventFinished && event.isParticipating && myRating == null;
            
            String label;
            if (isEventFinished) {
              if (event.isParticipating) {
                if (myRating == null) {
                  label = 'Оценить событие';
                } else {
                  label = 'Ваша оценка: $myRating ★';
                }
              } else {
                label = EventMessages.eventFinishedButtonTitle;
              }
            } else {
              label = isGoing ? 'Отменить участие' : 'Участвовать';
            }
            
            final bool isActionDisabled = isEventFinished && (!event.isParticipating || myRating != null);
            final bool disabled = isLoading || isActionDisabled;

            Color foreground;
            Color background;
            Color border;

            if (disabled) {
              foreground = Colors.white.withValues(alpha: 0.86);
              background = AppColors.dark.withValues(alpha: 0.35);
              border = Colors.white.withValues(alpha: 0.12);
            } else if (canRate) {
              foreground = Colors.white;
              background = const Color(0xFF00C853).withValues(alpha: 0.92); // Nice green for rating
              border = const Color(0xFF00E676).withValues(alpha: 0.6);
            } else if (isGoing) {
              foreground = AppColors.dark;
              background = AppColors.surface.withValues(alpha: 0.9);
              border = AppColors.primary.withValues(alpha: 0.18);
            } else {
              foreground = Colors.white;
              background = AppColors.primary.withValues(alpha: 0.92);
              border = AppColors.accent.withValues(alpha: 0.6);
            }

            return Container(
              height: 50,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.dark.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading 
                    ? null 
                    : (isEventFinished 
                        ? (canRate ? () => _showRatingDialog(event) : null)
                        : () => _toggleGoing(event)),
                  borderRadius: BorderRadius.circular(18),
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                foreground.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        : Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isEventFinished(EventModel event) {
    return !event.actualEndDateTime.toUtc().isAfter(DateTime.now().toUtc());
  }

  bool _isCreator(EventModel event) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final creatorId = event.createdById?.trim();
    if (currentUserId == null || creatorId == null || creatorId.isEmpty) {
      return _currentUserId != null && _currentUserId == creatorId;
    }
    return currentUserId == creatorId || _currentUserId == creatorId;
  }

  void _showReviewsBottomSheet(EventModel event) {
    Future<List<EventReviewModel>> reviewsFuture =
        _ratingService.getEventReviews(event.id);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void reload() {
            setSheetState(() {
              reviewsFuture = _ratingService.getEventReviews(event.id);
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, controller) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCED8F5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Отзывы и оценки',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF243252),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: _secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildReviewsSummaryCard(event),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<List<EventReviewModel>>(
                      future: reviewsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 48,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Не удалось загрузить отзывы',
                                    style: TextStyle(
                                      color: AppColors.dark.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: reload,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: BorderSide(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text('Повторить'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final reviews = snapshot.data ?? <EventReviewModel>[];
                        if (reviews.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 52,
                                  color: _secondaryTextColor.withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Пока нет отзывов',
                                  style: TextStyle(
                                    color: _secondaryTextColor.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: reviews.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildReviewTile(reviews[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewsSummaryCard(EventModel event) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E9FF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF243252),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.ratingCount} оценок',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarRatingWidget(
                  rating: event.averageRating,
                  starSize: 18,
                ),
                const SizedBox(height: 6),
                Text(
                  event.ratingCount == 0
                      ? 'Событие без оценок'
                      : 'Средняя оценка участников',
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondaryTextColor.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTile(EventReviewModel review) {
    final initials = _reviewInitials(review.userName);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage:
                    review.userPhotoUrl != null ? NetworkImage(review.userPhotoUrl!) : null,
                child: review.userPhotoUrl == null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF243252),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatReviewDate(review.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: _secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StarRatingWidget(
                    rating: review.rating.toDouble(),
                    starSize: 14,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    review.rating.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: _secondaryTextColor.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment!.trim(),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.dark.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _reviewInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();
    return initials.isEmpty ? '??' : initials.toUpperCase();
  }

  String _formatReviewDate(DateTime date) {
    final local = date.toLocal();
    return DateFormat('dd.MM.yyyy HH:mm', 'ru').format(local);
  }

  Widget _buildInfoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFE8EEFF), Color(0xFFE7F6F2)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF5F76FF), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF243252),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.arrow_forward_ios,
              size: 15,
              color: Color(0xFF8EA0C5),
            ),
        ],
      ),
    );
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'concert':
        return 'Концерт';
      case 'sport':
        return 'Спорт';
      case 'exhibition':
        return 'Выставка';
      case 'conference':
        return 'Конференция';
      case 'party':
        return 'Вечеринка';
      case 'theater':
        return 'Театр';
      case 'cinema':
        return 'Кино';
      case 'other':
        return 'Другое';
      default:
        return category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'concert':
        return Colors.purple;
      case 'sport':
        return Colors.orange;
      case 'exhibition':
        return Colors.teal;
      case 'conference':
        return Colors.blue;
      case 'party':
        return Colors.pink;
      case 'theater':
        return Colors.red;
      case 'cinema':
        return Colors.indigo;
      case 'other':
        return Colors.grey;
      default:
        return const Color(0xFF75878A);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy', 'ru').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'ru').format(date);
  }

  bool _isSameCalendarDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showParticipantsDialog(BuildContext context, EventModel event) {
    final eventBloc = context.read<EventBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: eventBloc,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: BlocBuilder<EventBloc, EventState>(
              builder: (context, state) {
                if (state is EventParticipantsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is EventParticipantsLoaded) {
                  return EventParticipantsDialog(
                    participants: state.participants,
                    eventTitle: event.title,
                    scrollController: controller,
                  );
                }

                if (state is EventError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(state.message),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Закрыть'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showRatingDialog(EventModel event) {
    int selectedRating = 5;
    final TextEditingController commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Оцените событие'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Как вам мероприятие?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: isSubmitting ? null : () {
                      setDialogState(() {
                        selectedRating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ваш комментарий (необязательно)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                enabled: !isSubmitting,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                setDialogState(() => isSubmitting = true);
                try {
                  await _ratingService.rateEvent(
                    event.id,
                    selectedRating,
                    comment: commentController.text.trim().isEmpty ? null : commentController.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    
                    // Обновляем состояние оценки сразу для моментального фидбека
                    _myRatingNotifier.value = selectedRating;
                    
                    if (mounted) {
                      CustomNotification.show(context, 'Спасибо за оценку!', isError: false);
                      context.read<EventBloc>().add(EventDetailLoadRequested(event.id));
                    }
                  }
                } catch (e) {
                  if (mounted && context.mounted) {
                    setDialogState(() => isSubmitting = false);
                    CustomNotification.show(context, e.toString(), isError: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
  }
}
