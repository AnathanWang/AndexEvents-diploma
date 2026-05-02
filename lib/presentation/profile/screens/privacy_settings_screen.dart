import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({
    required this.showVisitedEvents,
    required this.showInMatches,
    required this.incognitoMode,
    required this.hideOnlineStatus,
    super.key,
  });

  final bool showVisitedEvents;
  final bool showInMatches;
  final bool incognitoMode;
  final bool hideOnlineStatus;

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  late bool _showVisitedEvents;
  late bool _showInMatches;
  late bool _incognitoMode;
  late bool _hideOnlineStatus;

  @override
  void initState() {
    super.initState();
    _showVisitedEvents = widget.showVisitedEvents;
    _showInMatches = widget.showInMatches;
    _incognitoMode = widget.incognitoMode;
    _hideOnlineStatus = widget.hideOnlineStatus;
  }

  void _save() {
    Navigator.of(context).pop(<String, bool>{
      'showVisitedEvents': _showVisitedEvents,
      'showInMatches': _showInMatches,
      'incognitoMode': _incognitoMode,
      'hideOnlineStatus': _hideOnlineStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF273043)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Приватность',
          style: TextStyle(
            color: Color(0xFF1F3552),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: const Text(
              'Готово',
              style: TextStyle(
                color: Color(0xFF5F76FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
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
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -110,
              right: -70,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6D86FF).withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -85,
              child: Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF63C9B6).withValues(alpha: 0.12),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: <Widget>[
                const Text(
                  'Управляйте тем, как вас видят другие и какие данные участвуют в рекомендациях.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF5D668C),
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFDCE4FF)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF5762A8).withValues(alpha: 0.09),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      _PrivacyTile(
                        title: 'Показывать посещенные события',
                        subtitle:
                            'Другие пользователи смогут видеть ваш недавний event-опыт.',
                        value: _showVisitedEvents,
                        icon: Icons.event_available_rounded,
                        onChanged: (bool value) =>
                            setState(() => _showVisitedEvents = value),
                      ),
                      const SizedBox(height: 12),
                      _PrivacyTile(
                        title: 'Показывать профиль в мэтчах',
                        subtitle:
                            'Ваш профиль будет участвовать в рекомендациях и совпадениях.',
                        value: _showInMatches,
                        icon: Icons.people_alt_rounded,
                        onChanged: (bool value) =>
                            setState(() => _showInMatches = value),
                      ),
                      const SizedBox(height: 12),
                      _PrivacyTile(
                        title: 'Инкогнито режим',
                        subtitle:
                            'Профиль увидят только пользователи, с которыми возникнет взаимный интерес.',
                        value: _incognitoMode,
                        icon: Icons.visibility_off_rounded,
                        onChanged: (bool value) =>
                            setState(() => _incognitoMode = value),
                      ),
                      const SizedBox(height: 12),
                      _PrivacyTile(
                        title: 'Скрывать статус "в сети"',
                        subtitle:
                            'Онлайн-активность не будет отображаться в профиле.',
                        value: _hideOnlineStatus,
                        icon: Icons.circle_notifications_rounded,
                        onChanged: (bool value) =>
                            setState(() => _hideOnlineStatus = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDCE4FF)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF5F76FF),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Изменения применяются сразу после сохранения и влияют на рекомендации, видимость профиля и доступность части данных.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF66739B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: value
              ? <Color>[
                  const Color(0xFFE7EEFF),
                  const Color(0xFFE8F8F3),
                ]
              : <Color>[
                  Colors.white,
                  const Color(0xFFF5F8FF),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? const Color(0xFFB9D7FF) : const Color(0xFFE2E9FB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF5F76FF), Color(0xFF62A9FF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF243252),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.36,
                    color: Color(0xFF66739B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
