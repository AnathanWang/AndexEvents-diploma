import 'package:flutter/material.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
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
import '../../../core/theme/app_colors.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../../data/services/rating_service.dart';
import '../../../data/services/user_service.dart';
import '../../../core/http/api_client.dart';
import '../../widgets/report_dialog.dart';
import '../../../data/services/calendar_service.dart';
import '../../../data/services/event_participants_manage_service.dart';
import '../../../data/models/managed_participant_model.dart';
import '../../../data/models/waitlist_entry_model.dart';
import '../../../data/models/user_preview_model.dart';
import 'real_event_detail/event_manage_participants_sheet.dart';
import 'real_event_detail/real_event_detail_widgets.dart';
import 'real_event_detail/event_detail_route_section.dart';
import 'real_event_detail/event_detail_header_card.dart';
import 'real_event_detail/event_detail_when_where_section.dart';
import 'real_event_detail/event_detail_description_section.dart';
import 'real_event_detail/event_detail_organizer_section.dart';
import 'real_event_detail/event_reviews_bottom_sheet.dart';

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
  final CalendarService _calendarService = CalendarService();
  final EventParticipantsManageService _manageService =
      EventParticipantsManageService();
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

  void _openReportDialog(EventModel event) {
    final reporterId = _currentUserId?.trim();
    if (reporterId == null || reporterId.isEmpty) {
      CustomNotification.show(
        context,
        'Чтобы отправить жалобу, нужно войти в аккаунт.',
        isError: true,
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => ReportDialog(
        reporterId: reporterId,
        targetEventId: event.id,
      ),
    );
  }

  Future<void> _addToCalendar(EventModel event) async {
    try {
      await _calendarService.addEventToCalendar(event);
      if (!mounted) return;
      CustomNotification.show(
        context,
        'Событие добавлено в календарь',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      CustomNotification.show(
        context,
        msg.isEmpty ? 'Не удалось добавить событие в календарь' : msg,
        isError: true,
      );
    }
  }

  Future<void> _showManageParticipantsSheet(EventModel event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventManageParticipantsSheet(
        eventId: event.id,
        service: _manageService,
      ),
    );
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

  // moved to `real_event_detail/real_event_detail_widgets.dart`

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EventBloc, EventState>(
      listenWhen: (previous, current) {
        // Слушаем все состояния для обновления кнопки участия
        return true;
      },
      listener: (context, state) {
        if (state is EventDetailLoaded) {
          if (mounted) {
            setState(() {
              _cachedEvent = state.event;
            });
          } else {
            _cachedEvent = state.event;
          }
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
                  icon: const Icon(Icons.flag_rounded, color: Color(0xFF243252)),
                  onPressed: () => _openReportDialog(event),
                ),
              ),
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
                  icon: const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFF243252),
                  ),
                  onPressed: () => _addToCalendar(event),
                ),
              ),
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
                EventDetailHeaderCard(
                  event: event,
                  categoryName: categoryName,
                  categoryColor: categoryColor,
                  showCreatorReviewButton:
                      _isEventFinished(event) && _isCreator(event),
                  showManageButton: _isCreator(event),
                  onOpenReviews: () => _showReviewsBottomSheet(event),
                  onOpenMatches: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventMatchScreen(
                          eventId: event.id,
                        ),
                      ),
                    );
                  },
                  onOpenManage: () => _showManageParticipantsSheet(event),
                ),
                const SizedBox(height: 20),

                EventDetailWhenWhereSection(
                  event: event,
                  dateText: event.endDateTime != null &&
                          !_isSameCalendarDate(
                            event.dateTime,
                            event.endDateTime!,
                          )
                      ? '${_formatDate(event.dateTime)} - ${_formatDate(event.endDateTime!)}'
                      : _formatDate(event.dateTime),
                  timeText: event.endDateTime != null
                      ? '${_formatTime(event.dateTime)} - ${_formatTime(event.endDateTime!)}'
                      : _formatTime(event.dateTime),
                  onOpenRoute:
                      event.isOnline ? null : () => _openRoute(event),
                  onOpenParticipants: () {
                    context.read<EventBloc>().add(
                          EventParticipantsLoadRequested(event.id),
                        );
                    _showParticipantsDialog(context, event);
                  },
                ),
                const SizedBox(height: 20),

                EventDetailDescriptionSection(event: event),
                if (event.description.trim().isNotEmpty)
                  const SizedBox(height: 20),

                EventDetailOrganizerSection(
                  event: event,
                  categoryColor: categoryColor,
                  onOpenProfile: () => _openOrganizerProfile(event),
                ),
                if ((event.creatorName ?? '').trim().isNotEmpty)
                  const SizedBox(height: 20),

                if (!event.isOnline) ...[
                  EventDetailRouteSection(
                    event: event,
                    onOpenRoute: () => _openRoute(event),
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
        child: EventDetailFloatingActionPanel(
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

  Widget _buildFavoriteAction(EventModel event) {
    return EventDetailFavoriteAction(
      isFavorite: _isFavoriteNotifier,
      isLoading: _isFavoriteLoadingNotifier,
      isDisabled: _isEventFinished(event),
      onToggle: () => _toggleFavorite(event),
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventReviewsBottomSheet(
        event: event,
        ratingService: _ratingService,
      ),
    );
  }

  // moved to `real_event_detail/real_event_detail_widgets.dart`

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

// Participant management sheet moved to `real_event_detail/event_manage_participants_sheet.dart`.

class _EventManageParticipantsSheet extends StatefulWidget {
  const _EventManageParticipantsSheet({
    required this.eventId,
    required this.service,
  });

  final String eventId;
  final EventParticipantsManageService service;

  @override
  State<_EventManageParticipantsSheet> createState() =>
      _EventManageParticipantsSheetState();
}

class _EventManageParticipantsSheetState
    extends State<_EventManageParticipantsSheet> {
  int _tab = 0;
  bool _loading = true;
  bool _actionInProgress = false;
  String? _error;

  List<ManagedParticipantModel> _participants = const [];
  List<WaitlistEntryModel> _waitlist = const [];
  List<UserPreviewModel> _blocked = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.service.listManageParticipants(widget.eventId),
        widget.service.listWaitlist(widget.eventId),
        widget.service.listGlobalBlocked(),
      ]);
      if (!mounted) return;
      setState(() {
        _participants = results[0] as List<ManagedParticipantModel>;
        _waitlist = results[1] as List<WaitlistEntryModel>;
        _blocked = results[2] as List<UserPreviewModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _actionInProgress = true);
    try {
      await fn();
      await _load();
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        e.toString().replaceFirst('Exception: ', '').trim(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Widget _pill(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.86;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Управление участниками',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark.withValues(alpha: 0.88),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _actionInProgress ? null : () => _load(),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Segmented(
                            index: _tab,
                            labels: const ['Участники', 'Ожидание', 'Блоклист'],
                            onChanged: (v) => setState(() => _tab = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 44,
                                        color: Colors.redAccent,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        onPressed: _load,
                                        child: const Text('Повторить'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : _tab == 0
                                ? _buildParticipants()
                                : _tab == 1
                                    ? _buildWaitlist()
                                    : _buildBlocked(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipants() {
    if (_participants.isEmpty) {
      return Center(
        child: Text(
          'Пока нет участников',
          style: TextStyle(
            color: AppColors.dark.withValues(alpha: 0.62),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _participants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _participants[index];
        final user = item.participant.user;
        final checkedIn = item.checkedIn;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage:
                        user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
                    child: user.photoUrl == null
                        ? Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark.withValues(alpha: 0.86),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _pill(
                              item.participant.status.toUpperCase(),
                              bg: AppColors.primary.withValues(alpha: 0.10),
                              fg: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            _pill(
                              checkedIn ? 'CHECK-IN' : 'NO CHECK-IN',
                              bg: checkedIn
                                  ? const Color(0xFF00C853).withValues(alpha: 0.12)
                                  : AppColors.dark.withValues(alpha: 0.08),
                              fg: checkedIn
                                  ? const Color(0xFF00A34A)
                                  : AppColors.dark.withValues(alpha: 0.70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _actionInProgress
                          ? null
                          : () => _run(() => widget.service.kick(
                                widget.eventId,
                                item.participant.userId,
                              )),
                      child: const Text('Кик'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _actionInProgress
                          ? null
                          : () => _run(() => widget.service.banForEvent(
                                widget.eventId,
                                item.participant.userId,
                              )),
                      child: const Text('Бан на ивент'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _actionInProgress
                          ? null
                          : () => _run(() => widget.service.blockGlobally(
                                item.participant.userId,
                              )),
                      child: const Text('Блок глобально'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _actionInProgress
                          ? null
                          : () => _run(() => widget.service.setCheckIn(
                                widget.eventId,
                                item.participant.userId,
                                checkedIn: !checkedIn,
                              )),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.92),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: Text(checkedIn ? 'Снять чек-ин' : 'Чек-ин'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaitlist() {
    if (_waitlist.isEmpty) {
      return Center(
        child: Text(
          'Лист ожидания пуст',
          style: TextStyle(
            color: AppColors.dark.withValues(alpha: 0.62),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _waitlist.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _waitlist[index];
        final isPending = item.status.toUpperCase() == 'PENDING';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage: item.user.photoUrl == null
                        ? null
                        : NetworkImage(item.user.photoUrl!),
                    child: item.user.photoUrl == null
                        ? Text(
                            item.user.displayName.isNotEmpty
                                ? item.user.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.user.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark.withValues(alpha: 0.86),
                      ),
                    ),
                  ),
                  _pill(
                    item.status,
                    bg: isPending
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : AppColors.dark.withValues(alpha: 0.08),
                    fg: isPending
                        ? AppColors.primary
                        : AppColors.dark.withValues(alpha: 0.70),
                  ),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _actionInProgress
                            ? null
                            : () => _run(() => widget.service.rejectWaitlist(
                                  widget.eventId,
                                  item.userId,
                                )),
                        child: const Text('Отклонить'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _actionInProgress
                            ? null
                            : () => _run(() => widget.service.approveWaitlist(
                                  widget.eventId,
                                  item.userId,
                                )),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.92),
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: const Text('Принять'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlocked() {
    if (_blocked.isEmpty) {
      return Center(
        child: Text(
          'Глобальный блоклист пуст',
          style: TextStyle(
            color: AppColors.dark.withValues(alpha: 0.62),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _blocked.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final u = _blocked[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: u.photoUrl == null ? null : NetworkImage(u.photoUrl!),
                child: u.photoUrl == null
                    ? Text(
                        u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  u.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark.withValues(alpha: 0.86),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: _actionInProgress
                    ? null
                    : () => _run(() => widget.service.unblockGlobally(u.id)),
                child: const Text('Разблок'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? AppColors.primary
                        : AppColors.dark.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

