import 'package:flutter/material.dart';
import '../../models/event_preview.dart';
import '../../profile/screens/user_profile_screen.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    required this.event,
    super.key,
  });

  final EventPreview event;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? 'Добавлено в избранное' : 'Удалено из избранного'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleGoing() {
    setState(() {
      _isGoing = !_isGoing;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isGoing ? 'Вы идете на событие!' : 'Отменено участие'),
        duration: const Duration(seconds: 1),
        backgroundColor: _isGoing ? Colors.green : null,
      ),
    );
  }

  void _shareEvent() {
    // TODO: Реализовать шаринг
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Поделиться событием'),
        duration: Duration(seconds: 1),
      ),
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
            actions: <Widget>[
              Container(
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
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Color(0xFF4A4D6A)),
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
                          const Color(0xFF5E60CE).withOpacity(0.7),
                          const Color(0xFF9370DB).withOpacity(0.7),
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
              children: <Widget>[
                // Категория и цена
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E60CE).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.event.category,
                          style: const TextStyle(
                            color: Color(0xFF5E60CE),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.event.isFree
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.event.isFree ? 'Бесплатно' : '${widget.event.price} ₽',
                          style: TextStyle(
                            color: widget.event.isFree ? Colors.green : Colors.orange,
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
                    widget.event.title,
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
                  _formatDate(widget.event.date),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.access_time,
                  _formatTime(widget.event.date),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.location_on,
                  widget.event.location,
                  onTap: () {
                    // TODO: Открыть карту
                  },
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
                          color: Color(0xFF4A4D6A),
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
                                  widget.event.attendeeNames.length > 4 ? 4 : widget.event.attendeeNames.length,
                                  (int index) => Positioned(
                                    left: index * 25.0,
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: _getAvatarColor(index),
                                        child: Text(
                                          widget.event.attendeeNames[index][0].toUpperCase(),
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
                            '+${widget.event.attendees} участников',
                            style: const TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              // TODO: Показать всех участников
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
                          color: Color(0xFF4A4D6A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Присоединяйтесь к нам на ${widget.event.title}! '
                        'Это будет незабываемое событие, где вы сможете встретить '
                        'единомышленников, получить новый опыт и отлично провести время. '
                        'Мероприятие подходит как для новичков, так и для опытных участников. '
                        'Не упустите возможность стать частью нашего сообщества!',
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
                          children: <Widget>[
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF5E60CE),
                              child: Text(
                                widget.event.attendeeNames.isNotEmpty
                                    ? widget.event.attendeeNames[0][0].toUpperCase()
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
                                    widget.event.attendeeNames.isNotEmpty
                                        ? widget.event.attendeeNames[0]
                                        : 'Организатор',
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
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) => UserProfileScreen(
                                      userName: widget.event.attendeeNames.isNotEmpty
                                          ? widget.event.attendeeNames[0]
                                          : 'Организатор',
                                      userInitials: widget.event.attendeeNames.isNotEmpty
                                          ? widget.event.attendeeNames[0]
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
                                foregroundColor: const Color(0xFF5E60CE),
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
                          color: Color(0xFF4A4D6A),
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
                                      Colors.blue.withOpacity(0.3),
                                      Colors.purple.withOpacity(0.3),
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
                                  onPressed: () {
                                    // TODO: Открыть полноэкранную карту
                                  },
                                  icon: const Icon(Icons.directions),
                                  label: const Text('Маршрут'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF5E60CE),
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
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _toggleGoing,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isGoing ? Colors.grey : const Color(0xFF5E60CE),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              minimumSize: const Size(double.infinity, 0),
            ),
            child: Text(
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
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF5E60CE).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF5E60CE),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF4A4D6A),
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
      const Color(0xFF5E60CE),
      const Color(0xFF7B68EE),
      const Color(0xFF9370DB),
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
