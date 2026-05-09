import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event_preview.dart';
import '../../../data/models/event_model.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../widgets/common/custom_notification.dart';
import '../../widgets/common/star_rating_widget.dart';
import '../../widgets/event_countdown_timer.dart';
import '../../../data/services/rating_service.dart';
import '../../../core/http/api_client.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    required this.eventPreview,
    this.fullEvent,
    super.key,
  });

  final EventPreview eventPreview;
  final EventModel? fullEvent; // we might have fullEvent from a provider/API

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isFavorite = false;
  bool _isGoing = false;

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

  void _toggleGoing() {
    setState(() {
      _isGoing = !_isGoing;
    });
    CustomNotification.show(
      context,
      _isGoing ? 'Вы идете на событие!' : 'Отменено участие',
      duration: const Duration(seconds: 1),
    );
  }

  void _shareEvent() {
    final eventTitle = widget.eventPreview.title;
    final eventDate = widget.eventPreview.date.toString().substring(0, 16);
    SharePlus.instance.share(
      ShareParams(
        text:
            'Пошли вместе на "$eventTitle"!\n🕒 $eventDate\n📍 ${widget.eventPreview.location}\n\nУзнай подробности в приложении Andex Events.',
        subject: eventTitle,
      ),
    );
  }

  Future<void> _openMap() async {
    final address = Uri.encodeComponent(widget.eventPreview.location);
    final url = Uri.parse('https://yandex.ru/maps/?text=$address');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        CustomNotification.show(context, 'Не удалось открыть карту', isError: true);
      }
    }
  }

  void _showRatingDialog() {
    int currentDialogRating = widget.fullEvent?.myRating ?? 0;
    final textController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Оцените событие'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StarRatingWidget(
                    rating: currentDialogRating.toDouble(),
                    isInteractive: true,
                    onRatingChanged: (val) {
                      setState(() {
                        currentDialogRating = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      hintText: 'Оставьте комментарий (необязательно)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                 ElevatedButton(
                  onPressed: currentDialogRating == 0
                      ? null
                      : () async {
                          try {
                            final ratingService = RatingService(ApiClient());
                            await ratingService.rateEvent(
                              widget.eventPreview.id,
                              currentDialogRating,
                              comment: textController.text.isNotEmpty ? textController.text : null,
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            CustomNotification.show(dialogContext, 'Оценка сохранена!');
                            // In a real app, we would also trigger a refresh of the event details
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            CustomNotification.show(
                              dialogContext,
                              'Ошибка: $e',
                              isError: true,
                            );
                          }
                        },
                  child: const Text('Отправить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          // App Bar с изображением
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF161823)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: <Widget>[
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_outline,
                    color: _isFavorite ? Colors.red : const Color(0xFF161823),
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Color(0xFF161823)),
                  onPressed: _shareEvent,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          const Color(0xFF75878A).withValues(alpha: 0.7),
                          const Color(0xFF81D8D0).withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.celebration,
                      size: 120,
                      color: Colors.white38,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
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
              children: <Widget>[
                // Категория и цена
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF75878A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.eventPreview.category,
                          style: const TextStyle(
                            color: Color(0xFF75878A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.eventPreview.isFree
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.eventPreview.isFree ? 'Бесплатно' : '${widget.eventPreview.price} ₽',
                          style: TextStyle(
                            color: widget.eventPreview.isFree ? Colors.green : Colors.orange,
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
                    widget.eventPreview.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF161823),
                    ),
                  ),
                ),
                
                // Рейтинг события
                if (widget.fullEvent != null && widget.fullEvent!.ratingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
                    child: Row(
                      children: [
                        StarRatingWidget(
                          rating: widget.fullEvent!.averageRating,
                          starSize: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.fullEvent!.averageRating.toStringAsFixed(1)} (${widget.fullEvent!.ratingCount})',
                          style: const TextStyle(
                            color: Color(0xFF75878A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Дата и время
                _buildInfoRow(
                  Icons.calendar_today,
                  _formatDate(widget.eventPreview.date),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.access_time,
                  _formatTime(widget.eventPreview.date),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          color: Color(0xFF75878A),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'До окончания',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8D8D8D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            EventCountdownTimer(
                              expirationTime: widget.eventPreview.actualExpirationTime,
                              isMinimal: true,
                              textStyle: const TextStyle(
                                color: Color(0xFF161823),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.location_on,
                  widget.eventPreview.location,
                  onTap: _openMap,
                ),
                const SizedBox(height: 24),
                
                // Участники
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Участники',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF161823),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: 120,
                            height: 40,
                            child: Stack(
                              children: <Widget>[
                                ...List<Widget>.generate(
                                  widget.eventPreview.attendeeNames.length > 4 ? 4 : widget.eventPreview.attendeeNames.length,
                                  (int index) => Positioned(
                                    left: index * 25.0,
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: _getAvatarColor(index),
                                        child: Text(
                                          widget.eventPreview.attendeeNames[index][0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${widget.eventPreview.attendees} участников',
                            style: const TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              CustomNotification.show(context, 'Полный список участников в разработке');
                            },
                            child: const Text('Все'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Описание
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Описание',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF161823),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Присоединяйтесь к нам на ${widget.eventPreview.title}! '
                        'Это будет незабываемое событие, где вы сможете встретить '
                        'единомышленников, получить новый опыт и отлично провести время. '
                        'Мероприятие подходит как для новичков, так и для опытных участников. '
                        'Не упустите возможность стать частью нашего сообщества!',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF161823),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Организатор
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Организатор',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF161823),
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
                          children: <Widget>[
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF75878A),
                              child: Text(
                                widget.eventPreview.attendeeNames.isNotEmpty
                                    ? widget.eventPreview.attendeeNames[0][0].toUpperCase()
                                    : 'О',
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
                                children: <Widget>[
                                  Text(
                                    widget.eventPreview.attendeeNames.isNotEmpty
                                        ? widget.eventPreview.attendeeNames[0]
                                        : 'Организатор',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF161823),
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
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) => UserProfileScreen(
                                      userName: widget.eventPreview.attendeeNames.isNotEmpty
                                          ? widget.eventPreview.attendeeNames[0]
                                          : 'Организатор',
                                      userInitials: widget.eventPreview.attendeeNames.isNotEmpty
                                          ? widget.eventPreview.attendeeNames[0]
                                              .split(' ')
                                              .map((String word) => word[0])
                                              .take(2)
                                              .join()
                                              .toUpperCase()
                                          : 'О',
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF75878A),
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
                
                // Карта
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Местоположение',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF161823),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: <Widget>[
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      Colors.blue.withValues(alpha: 0.3),
                                      Colors.purple.withValues(alpha: 0.3),
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.map,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: ElevatedButton.icon(
                                  onPressed: _openMap,
                                  icon: const Icon(Icons.directions),
                                  label: const Text('Маршрут'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF75878A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Builder(
            builder: (context) {
              final isEnded = widget.eventPreview.actualExpirationTime.isBefore(DateTime.now());
              final isParticipating = widget.fullEvent?.isParticipating ?? _isGoing;

              if (isEnded && isParticipating) {
                return ElevatedButton(
                  onPressed: _showRatingDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFACC15),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star),
                      const SizedBox(width: 8),
                      Text(
                        widget.fullEvent?.myRating != null ? 'Изменить оценку' : 'Оценить событие',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ElevatedButton(
                onPressed: isEnded ? null : _toggleGoing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isGoing ? Colors.grey : const Color(0xFF75878A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: Text(
                  isEnded ? 'Событие завершено' : (_isGoing ? 'Отменить участие' : 'Участвовать'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
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
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF75878A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF75878A),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF161823),
                ),
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

  Color _getAvatarColor(int index) {
    final List<Color> colors = <Color>[
      const Color(0xFF75878A),
      const Color(0xFF81D8D0),
      const Color(0xFF81D8D0),
      const Color(0xFFBA55D3),
    ];
    return colors[index % colors.length];
  }

  String _formatDate(DateTime date) {
    final List<String> months = <String>[
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final List<String> weekdays = <String>[
      'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${weekdays[date.weekday - 1]}';
  }

  String _formatTime(DateTime date) {
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
