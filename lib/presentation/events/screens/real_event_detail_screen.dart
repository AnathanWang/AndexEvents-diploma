import 'package:flutter/material.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/event_messages.dart';

import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import '../../../data/models/event_model.dart';
import '../../../data/services/external_route_service.dart';
import '../../matches/screens/event_match_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/auth_glass_card.dart';
import '../../auth/widgets/auth_glass_scaffold.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../../data/services/rating_service.dart';
import '../../../data/services/user_service.dart';
import '../../../core/http/api_client.dart';
import '../../widgets/report_dialog.dart';
import '../../../data/services/calendar_service.dart';
import '../../../core/events/event_refresh_bus.dart';
import '../../../data/services/event_participants_manage_service.dart';
import 'real_event_detail/event_manage_participants_sheet.dart';
import 'real_event_detail/real_event_detail_widgets.dart';
import 'real_event_detail/event_detail_route_section.dart';
import 'real_event_detail/event_detail_header_card.dart';
import 'real_event_detail/event_detail_when_where_section.dart';
import 'real_event_detail/event_detail_description_section.dart';
import 'real_event_detail/event_detail_organizer_section.dart';
import 'real_event_detail/event_reviews_bottom_sheet.dart';
import 'real_event_detail/event_detail_bottom_bar.dart';
import 'real_event_detail/event_detail_sliver_app_bar.dart';
import 'real_event_detail/event_detail_participants_bottom_sheet.dart';
import 'real_event_detail/event_detail_rating_dialog.dart';

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
  final ValueNotifier<bool> _isCheckedInNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isCheckInLoadingNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<int> _currentImageIndexNotifier = ValueNotifier<int>(0);
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

  Future<void> _shareEvent(EventModel event) async {
    final text = [
      event.title.trim(),
      if (event.location.trim().isNotEmpty) event.location.trim(),
      '${_formatDate(event.dateTime)} ${_formatTime(event.dateTime)}',
    ].join('\n');

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        'Не удалось поделиться событием',
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
    if (!mounted) return;
    context.read<EventBloc>().add(EventDetailLoadRequested(event.id));
    EventRefreshBus.instance.notify();
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

  Future<void> _toggleCheckIn(EventModel event) async {
    if (_isEventFinished(event)) {
      CustomNotification.show(context, EventMessages.eventFinishedActionBlocked);
      return;
    }

    final participation = (event.userParticipationStatus ?? '').trim();
    if (participation.toUpperCase() != 'GOING') {
      CustomNotification.show(
        context,
        'Сначала подтвердите участие',
        isError: true,
      );
      return;
    }

    final next = !_isCheckedInNotifier.value;
    _isCheckInLoadingNotifier.value = true;
    try {
      await _manageService.setSelfCheckIn(event.id, checkedIn: next);
      if (!mounted) return;
      _isCheckedInNotifier.value = next;
      context.read<EventBloc>().add(EventDetailLoadRequested(event.id));
      CustomNotification.show(
        context,
        next ? 'Присутствие отмечено' : 'Чек-ин отменён',
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      CustomNotification.show(context, msg, isError: true);
    } finally {
      if (mounted) {
        _isCheckInLoadingNotifier.value = false;
      }
    }
  }

  @override
  void dispose() {
    _isFavoriteNotifier.dispose();
    _isGoingNotifier.dispose();
    _isCheckedInNotifier.dispose();
    _isFavoriteLoadingNotifier.dispose();
    _isGoingLoadingNotifier.dispose();
    _isCheckInLoadingNotifier.dispose();
    _myRatingNotifier.dispose();
    _currentImageIndexNotifier.dispose();
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
      listenWhen: (previous, current) =>
          current is EventDetailLoaded ||
          current is EventError ||
          current is EventParticipationUpdating,
      listener: (context, state) {
        if (state is EventDetailLoaded) {
          _isGoingNotifier.value =
              (state.event.userParticipationStatus ?? '').trim().toUpperCase() ==
                  'GOING';
          _isFavoriteNotifier.value =
              state.event.userParticipationStatus == 'INTERESTED';
          _isCheckedInNotifier.value = state.event.isCheckedIn;
          _myRatingNotifier.value = state.event.myRating;
          _isFavoriteLoadingNotifier.value = false;
          _isGoingLoadingNotifier.value = false;
          _isCheckInLoadingNotifier.value = false;
        } else if (state is EventError) {
          _isFavoriteLoadingNotifier.value = false;
          _isGoingLoadingNotifier.value = false;
          final message = state.message.trim();
          final isUnavailable = message.contains('не найден') ||
              message.contains('not found') ||
              message.contains('недоступ');
          if (isUnavailable) {
            EventRefreshBus.instance.notify();
            CustomNotification.show(
              context,
              'Событие недоступно',
              isError: true,
            );
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            return;
          }
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

        if (_cachedEvent != null && current is EventDetailLoading) {
          return false;
        }

        return true;
      },
      builder: (context, state) {
        if (state is EventDetailLoaded) {
          _cachedEvent = state.event;
          return _buildEventDetail(context, state.event);
        }

        if (_cachedEvent != null) {
          return _buildEventDetail(context, _cachedEvent!);
        }

        if (state is EventDetailLoading) {
          return const AuthGlassScaffold(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (state is EventError) {
          return AuthGlassScaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF273043)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Ошибка',
                style: TextStyle(
                  color: Color(0xFF1F3552),
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AuthGlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 52,
                        color: AppColors.dark.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.dark.withValues(alpha: 0.78),
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<EventBloc>().add(
                                  EventDetailLoadRequested(widget.eventId),
                                );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Попробовать снова',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const AuthGlassScaffold(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
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
      body: CustomScrollView(
        cacheExtent: 400,
        slivers: [
          // App Bar с изображением
          EventDetailSliverAppBar(
            event: event,
            categoryColor: categoryColor,
            imageGallery: imageGallery,
            currentImageIndexListenable: _currentImageIndexNotifier,
            onImageIndexChanged: (index) {
              _currentImageIndexNotifier.value = index;
            },
            favoriteAction: _buildFavoriteAction(event),
            onBack: () => Navigator.of(context).pop(),
            onReport: () => _openReportDialog(event),
            onAddToCalendar: () => _addToCalendar(event),
            onShare: () => _shareEvent(event),
          ),

          // Контент
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                EventDetailHeaderCard(
                  event: event,
                  categoryName: categoryName,
                  categoryColor: categoryColor,
                  showReviewsButton: _isEventFinished(event),
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
          ),
        ],
      ),

      bottomNavigationBar: EventDetailBottomBar(
        event: event,
        isEventFinished: _isEventFinished(event),
        categoryColor: categoryColor,
        isGoing: _isGoingNotifier,
        isGoingLoading: _isGoingLoadingNotifier,
        myRating: _myRatingNotifier,
        onToggleGoing: () => _toggleGoing(event),
        onRate: () => _showRatingDialog(event),
        showCheckInButton: !_isCreator(event) &&
            !_isEventFinished(event) &&
            _canShowCheckInButton(event) &&
            (event.userParticipationStatus ?? '').trim().toUpperCase() == 'GOING',
        isCheckedIn: _isCheckedInNotifier,
        isCheckInLoading: _isCheckInLoadingNotifier,
        onToggleCheckIn: () => _toggleCheckIn(event),
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

  bool _isEventFinished(EventModel event) {
    return !event.actualEndDateTime.toUtc().isAfter(DateTime.now().toUtc());
  }

  bool _canShowCheckInButton(EventModel event) {
    // Rule: show check-in only once the event starts.
    final startsAt = event.dateTime.toUtc();
    final now = DateTime.now().toUtc();
    if (now.isBefore(startsAt)) return false;
    return true;
  }

  bool _isCreator(EventModel event) {
    final creatorId = event.createdById?.trim();
    if (creatorId == null || creatorId.isEmpty) return false;
    return _currentUserId != null && _currentUserId == creatorId;
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
      builder: (context) => EventDetailParticipantsBottomSheet(
        event: event,
        eventBloc: eventBloc,
      ),
    );
  }

  void _showRatingDialog(EventModel event) {
    final eventBloc = context.read<EventBloc>();
    showDialog(
      context: context,
      builder: (_) => EventDetailRatingDialog(
        event: event,
        ratingService: _ratingService,
        onRated: (rating) {
          _myRatingNotifier.value = rating;
          if (!mounted) return;
          eventBloc.add(EventDetailLoadRequested(event.id, silent: true));
          EventRefreshBus.instance.notify();
        },
      ),
    );
  }
}

// Participant management sheet moved to `real_event_detail/event_manage_participants_sheet.dart`.

// (removed) Participant management bottom sheet implementation.
