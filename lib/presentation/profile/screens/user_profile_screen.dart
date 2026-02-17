import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/common/custom_notification.dart';
import '../../widgets/report_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/user_model.dart';
// import '../../../data/services/friend_service.dart'; // Removed FriendService

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.userName,
    required this.userInitials,
    super.key,
  })  : user = null,
        matchPercentage = null,
        commonInterests = const <String>[],
        canViewSensitiveInfo = false;

  UserProfileScreen.fromUser({
    required UserModel user,
    int? matchPercentage,
    List<String> commonInterests = const <String>[],
    bool canViewSensitiveInfo = false,
    super.key,
  })  : userName = (user.displayName?.isNotEmpty == true)
            ? user.displayName!
            : user.email.split('@').first,
        userInitials = _initialsFrom(
          (user.displayName?.isNotEmpty == true)
              ? user.displayName!
              : user.email.split('@').first,
        ),
        user = user,
        matchPercentage = matchPercentage,
        commonInterests = commonInterests,
        canViewSensitiveInfo = canViewSensitiveInfo;

  final String userName;
  final String userInitials;
  final UserModel? user;
  final int? matchPercentage;
  final List<String> commonInterests;
  final bool canViewSensitiveInfo;

  static String _initialsFrom(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '??';
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
  }










  Map<String, String> _normalizedSocialLinks() {
    final links = widget.user?.socialLinks ?? <String, dynamic>{};
    final normalized = <String, String>{};

    links.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        normalized[key.toString()] = value.toString();
      }
    });

    return normalized;
  }

  List<MapEntry<String, String>> _sortedSocialLinks(Map<String, String> links) {
    final priority = <String, int>{
      'tg': 1,
      'telegram': 1,
      'instagram': 2,
      'inst': 2,
      'vk': 3,
      'vkontakte': 3,
      'whatsapp': 4,
      'tiktok': 5,
      'website': 9,
      'phone': 10,
    };

    final entries = links.entries.toList();
    entries.sort((a, b) {
      final ap = priority[a.key.toLowerCase()] ?? 999;
      final bp = priority[b.key.toLowerCase()] ?? 999;
      if (ap != bp) return ap.compareTo(bp);
      return a.key.toLowerCase().compareTo(b.key.toLowerCase());
    });
    return entries;
  }

  String _displaySocialName(String key) {
    switch (key.toLowerCase()) {
      case 'tg':
      case 'telegram':
        return 'Телеграм';
      case 'instagram':
      case 'inst':
        return 'Инстаграм';
      case 'vk':
      case 'vkontakte':
        return 'ВКонтакте';
      case 'tiktok':
        return 'ТикТок';
      case 'whatsapp':
        return 'WhatsApp';
      case 'website':
        return 'Сайт';
      case 'phone':
        return 'Телефон';
      default:
        if (key.isEmpty) return 'Ссылка';
        return key[0].toUpperCase() + key.substring(1);
    }
  }

  ({IconData icon, List<Color> gradient}) _socialStyle(String key) {
    switch (key.toLowerCase()) {
      case 'tg':
      case 'telegram':
        return (
          icon: Icons.send,
          gradient: const <Color>[Color(0xFF2AABEE), Color(0xFF229ED9)],
        );
      case 'vk':
      case 'vkontakte':
        return (
          icon: Icons.group,
          gradient: const <Color>[Color(0xFF4C75A3), Color(0xFF3B5F89)],
        );
      case 'instagram':
      case 'inst':
        return (
          icon: Icons.camera_alt,
          gradient: const <Color>[
            Color(0xFFF58529),
            Color(0xFFDD2A7B),
            Color(0xFF8134AF),
          ],
        );
      case 'tiktok':
        return (
          icon: Icons.music_note,
          gradient: const <Color>[Color(0xFF111111), Color(0xFF444444)],
        );
      case 'whatsapp':
        return (
          icon: Icons.chat,
          gradient: const <Color>[Color(0xFF25D366), Color(0xFF128C7E)],
        );
      case 'website':
        return (
          icon: Icons.language,
          gradient: const <Color>[Color(0xFF5E60CE), Color(0xFF9370DB)],
        );
      case 'phone':
        return (
          icon: Icons.phone,
          gradient: const <Color>[Color(0xFF5E60CE), Color(0xFF9370DB)],
        );
      default:
        return (
          icon: Icons.link,
          gradient: const <Color>[Color(0xFF5E60CE), Color(0xFF9370DB)],
        );
    }
  }

  Widget _buildSocialLinksCard() {
    if (!widget.canViewSensitiveInfo) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              color: Color(0xFF9E9E9E),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Соцсети доступны после взаимного лайка',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A4D6A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final links = _normalizedSocialLinks();
    if (links.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: Color(0xFF9E9E9E)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Соцсети не указаны',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A4D6A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final entries = _sortedSocialLinks(links);
    return Column(
      children: entries.map((entry) {
        final style = _socialStyle(entry.key);
        final title = _displaySocialName(entry.key);
        final value = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!mounted) return;
                CustomNotification.success(
                  context,
                  'Скопировано',
                  duration: const Duration(seconds: 1),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: style.gradient),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(style.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A4D6A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.copy,
                      color: Color(0xFF9E9E9E),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
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
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF4A4D6A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (String value) {
                    if (value == 'block') {
                      _showBlockDialog();
                    } else if (value == 'report') {
                      _showReportDialog();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.block, color: Colors.orange),
                          SizedBox(width: 12),
                          Text('Заблокировать'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.flag, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Пожаловаться'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      const Color(0xFF5E60CE).withValues(alpha: 0.7),
                      const Color(0xFF9370DB).withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.userInitials,
                      style: const TextStyle(
                        color: Color(0xFF5E60CE),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Контент
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Имя и статус
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              widget.userName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A4D6A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.circle, color: Colors.green, size: 8),
                                SizedBox(width: 6),
                                Text(
                                  'Онлайн',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Люблю спорт, музыку и путешествия. Ищу новые впечатления и интересные события! '
                        'Регулярно хожу на митапы и концерты. Открыт к новым знакомствам.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4A4D6A),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Статистика
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildStatCard('24', 'Событий', Icons.event),
                      ),
                      const SizedBox(width: 12),
                      // Removed Friends stat card
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('4.8', 'Рейтинг', Icons.star),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Интересы
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Интересы',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A4D6A),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <String>[
                      'Спорт',
                      'Музыка',
                      'Путешествия',
                      'Технологии',
                      'Фотография',
                    ].map((String interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E60CE).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF5E60CE).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          interest,
                          style: const TextStyle(
                            color: Color(0xFF5E60CE),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Общие интересы
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E60CE).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF5E60CE).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E60CE).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFF5E60CE),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'У вас 3 общих интереса',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A4D6A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Спорт, Музыка, Технологии',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Недавние события
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Недавние события',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A4D6A),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 5,
                    itemBuilder: (BuildContext context, int index) {
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              const Color(0xFF5E60CE).withValues(alpha: 0.7),
                              const Color(0xFF9370DB).withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.celebration,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                
                // Соцсети (доступны только после взаимного лайка)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSocialLinksCard(),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: const Color(0xFF5E60CE), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A4D6A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Заблокировать пользователя?'),
          content: Text(
            'Вы больше не будете видеть ${widget.userName} в рекомендациях и не сможете общаться.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                CustomNotification.show(
                  context,
                  '${widget.userName} заблокирован',
                  duration: const Duration(seconds: 2),
                );
              },
              child: const Text(
                'Заблокировать',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showReportDialog() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      CustomNotification.show(context, 'Ошибка авторизации', isError: true);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return ReportDialog(
          reporterId: currentUserId,
          targetUserId: widget.user?.id,
        );
      },
    );
  }
}
