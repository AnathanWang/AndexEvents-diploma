import 'package:flutter/material.dart';
import '../../widgets/common/custom_notification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import '../../../data/models/event_model.dart';
import '../widgets/event_participants_dialog.dart';

class RealEventDetailScreen extends StatefulWidget {
  final String eventId;

  const RealEventDetailScreen({super.key, required this.eventId});

  @override
  State<RealEventDetailScreen> createState() => _RealEventDetailScreenState();
}

class _RealEventDetailScreenState extends State<RealEventDetailScreen> {
  bool _isFavorite = false;
  bool _isGoing = false;
  bool _isParticipationLoading = false;

  @override
  void initState() {
    super.initState();
    // Delay the event loading to ensure BlocProvider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventBloc>().add(EventDetailLoadRequested(widget.eventId));
    });
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    CustomNotification.show(
      context,
      _isFavorite ? 'Добавлено в избранное' : 'Удалено из избранного',
      duration: const Duration(seconds: 1),
    );
  }

  void _toggleGoing(EventModel event) {
    setState(() {
      _isParticipationLoading = true;
    });

    if (!_isGoing) {
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
  Widget build(BuildContext context) {
    return BlocConsumer<EventBloc, EventState>(
      listenWhen: (previous, current) {
        // Слушаем все состояния для обновления кнопки участия
        return true;
      },
      listener: (context, state) {
        if (state is EventDetailLoaded) {
          setState(() {
            _isGoing = state.event.isParticipating;
            _isParticipationLoading = false;
          });
        } else if (state is EventParticipationUpdating) {
          setState(() {
            _isParticipationLoading = true;
          });
        } else if (state is EventParticipationUpdated) {
          // Состояние обновлено, ждем новые данные события
          setState(() {
            _isParticipationLoading = true;
          });
        } else if (state is EventError) {
          setState(() {
            _isParticipationLoading = false;
          });
          CustomNotification.show(context, state.message, isError: true);
        }
      },
      buildWhen: (previous, current) {
        // Не перестраиваем основной экран при загрузке участников
        return current is! EventParticipantsLoading &&
            current is! EventParticipantsLoaded;
      },
      builder: (context, state) {
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
          return _buildEventDetail(context, state.event);
        }

        return const Scaffold(body: Center(child: Text('Загрузка...')));
      },
    );
  }

  Widget _buildEventDetail(BuildContext context, EventModel event) {
    final categoryColor = _getCategoryColor(event.category);
    final categoryName = _getCategoryName(event.category);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar с изображением
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF4A4D6A)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_outline,
                    color: _isFavorite ? Colors.red : const Color(0xFF4A4D6A),
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Color(0xFF4A4D6A)),
                  onPressed: () {},
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (event.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: event.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade300,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              categoryColor.withOpacity(0.7),
                              categoryColor.withOpacity(0.5),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.event,
                          size: 120,
                          color: Colors.white38,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            categoryColor.withOpacity(0.7),
                            categoryColor.withOpacity(0.5),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.event,
                        size: 120,
                        color: Colors.white38,
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
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
                // Категория и цена
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
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
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
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
                ),

                // Название
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A4D6A),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Дата и время
                _buildInfoRow(
                  Icons.calendar_today,
                  _formatDate(event.dateTime),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.access_time, _formatTime(event.dateTime)),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.location_on, event.location, onTap: () {}),
                const SizedBox(height: 24),

                // Участники
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Участники',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A4D6A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Avatars
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
                                                  color: Color(0xFF4A4D6A),
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
                                color: const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    event.participantsCount == 0
                                        ? 'Нет участников'
                                        : '${event.participantsCount} участник${event.participantsCount % 10 == 1 && event.participantsCount != 11 ? '' : 'ов'}',
                                    style: const TextStyle(
                                      color: Color(0xFF4A4D6A),
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
                          // Matches Button
                          Container(
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {},
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
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Описание
                if (event.description.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Описание',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A4D6A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          event.description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF4A4D6A),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Организатор
                if (event.creatorName != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Организатор',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A4D6A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              if (event.creatorPhotoUrl != null)
                                CachedNetworkImage(
                                  imageUrl: event.creatorPhotoUrl!,
                                  imageBuilder: (context, imageProvider) =>
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundImage: imageProvider,
                                      ),
                                  placeholder: (context, url) =>
                                      const CircleAvatar(
                                        radius: 30,
                                        child: CircularProgressIndicator(),
                                      ),
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: categoryColor,
                                        child: Text(
                                          event.creatorName![0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                )
                              else
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: categoryColor,
                                  child: Text(
                                    event.creatorName![0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.creatorName!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4A4D6A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Организатор событий',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF9E9E9E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: categoryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Профиль'),
                              ),
                            ],
                          ),
                        ),
                      ],
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

      // Нижняя панель с кнопкой участия
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isParticipationLoading
                ? null
                : () => _toggleGoing(event),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isParticipationLoading
                  ? Colors.grey.shade400
                  : (_isGoing ? Colors.grey : categoryColor),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              minimumSize: const Size(double.infinity, 0),
            ),
            child: _isParticipationLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.7),
                      ),
                    ),
                  )
                : Text(
                    _isGoing ? 'Отменить участие' : 'Участвовать',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF5E60CE).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF5E60CE), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 16, color: Color(0xFF4A4D6A)),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF9E9E9E),
              ),
          ],
        ),
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
        return const Color(0xFF5E60CE);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy, EEEE', 'ru').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'ru').format(date);
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
}
