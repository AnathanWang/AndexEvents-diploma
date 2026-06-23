import 'package:flutter/material.dart';

import '../../auth/widgets/auth_glass_card.dart';
import '../../auth/widgets/auth_glass_scaffold.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({
    required this.showVisitedEvents,
    required this.showInMatches,
    required this.incognitoMode,
    required this.hideOnlineStatus,
    this.minAge,
    this.maxAge,
    this.matchGenderPreference,
    super.key,
  });

  final bool showVisitedEvents;
  final bool showInMatches;
  final bool incognitoMode;
  final bool hideOnlineStatus;
  final int? minAge;
  final int? maxAge;
  final String? matchGenderPreference;

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  late bool _showVisitedEvents;
  late bool _showInMatches;
  late bool _incognitoMode;
  late bool _hideOnlineStatus;
  int? _minAge;
  int? _maxAge;
  String? _matchGenderPreference;

  static const List<int> _ageOptions = <int>[
    18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 45, 50, 55, 60, 65, 70,
  ];

  @override
  void initState() {
    super.initState();
    _showVisitedEvents = widget.showVisitedEvents;
    _showInMatches = widget.showInMatches;
    _incognitoMode = widget.incognitoMode;
    _hideOnlineStatus = widget.hideOnlineStatus;
    _minAge = widget.minAge;
    _maxAge = widget.maxAge;
    _matchGenderPreference = widget.matchGenderPreference ?? 'all';
  }

  void _save() {
    if (_minAge != null && _maxAge != null && _minAge! > _maxAge!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Минимальный возраст не может быть больше максимального')),
      );
      return;
    }

    Navigator.of(context).pop(<String, Object?>{
      'showVisitedEvents': _showVisitedEvents,
      'showInMatches': _showInMatches,
      'incognitoMode': _incognitoMode,
      'hideOnlineStatus': _hideOnlineStatus,
      'minAge': _minAge,
      'maxAge': _maxAge,
      'matchGenderPreference': _matchGenderPreference,
    });
  }

  @override
  Widget build(BuildContext context) {
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
      child: ListView(
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
          AuthGlassCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
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
                  onChanged: (bool value) => setState(() => _incognitoMode = value),
                ),
                const SizedBox(height: 12),
                _PrivacyTile(
                  title: 'Скрывать статус "в сети"',
                  subtitle: 'Онлайн-активность не будет отображаться в профиле.',
                  value: _hideOnlineStatus,
                  icon: Icons.circle_notifications_rounded,
                  onChanged: (bool value) =>
                      setState(() => _hideOnlineStatus = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AuthGlassCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Возраст в рекомендациях',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF243252),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Показывать в ленте знакомств только людей из выбранного диапазона. «Любой» — без ограничения.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.36,
                    color: Color(0xFF66739B),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _AgeDropdown(
                        label: 'От',
                        value: _minAge,
                        options: _ageOptions,
                        onChanged: (int? value) => setState(() => _minAge = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AgeDropdown(
                        label: 'До',
                        value: _maxAge,
                        options: _ageOptions,
                        onChanged: (int? value) => setState(() => _maxAge = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AuthGlassCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Кого показывать в мэтчах',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF243252),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Фильтр по полу в ленте знакомств. «Все» — без ограничения.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.36,
                    color: Color(0xFF66739B),
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: 'all',
                      label: Text('Все'),
                    ),
                    ButtonSegment<String>(
                      value: 'male',
                      label: Text('Мужчин'),
                    ),
                    ButtonSegment<String>(
                      value: 'female',
                      label: Text('Женщин'),
                    ),
                  ],
                  selected: <String>{_matchGenderPreference ?? 'all'},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() {
                      _matchGenderPreference = selection.first;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AuthGlassCard(
            padding: EdgeInsets.all(16),
            child: Row(
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
    );
  }
}

class _AgeDropdown extends StatelessWidget {
  const _AgeDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<int> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF66739B),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int?>(
          key: ValueKey<int?>(value),
          initialValue: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E9FB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E9FB)),
            ),
          ),
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Любой'),
            ),
            ...options.map(
              (int age) => DropdownMenuItem<int?>(
                value: age,
                child: Text('$age'),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ],
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
