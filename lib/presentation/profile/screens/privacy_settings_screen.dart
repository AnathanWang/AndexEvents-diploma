import 'package:flutter/material.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({
    required this.showInSearch,
    required this.showVisitedEvents,
    required this.matchNotifications,
    super.key,
  });

  final bool showInSearch;
  final bool showVisitedEvents;
  final bool matchNotifications;

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  late bool _showInSearch;
  late bool _showVisitedEvents;
  late bool _matchNotifications;

  @override
  void initState() {
    super.initState();
    _showInSearch = widget.showInSearch;
    _showVisitedEvents = widget.showVisitedEvents;
    _matchNotifications = widget.matchNotifications;
  }

  void _save() {
    Navigator.of(context).pop(<String, bool>{
      'showInSearch': _showInSearch,
      'showVisitedEvents': _showVisitedEvents,
      'matchNotifications': _matchNotifications,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A4D6A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Приватность',
          style: TextStyle(
            color: Color(0xFF4A4D6A),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: const Text(
              'Готово',
              style: TextStyle(
                color: Color(0xFF5E60CE),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('Показывать в поиске'),
                  subtitle: const Text('Другие пользователи смогут найти вас'),
                  value: _showInSearch,
                  activeThumbColor: const Color(0xFF5E60CE),
                  onChanged: (bool value) {
                    setState(() {
                      _showInSearch = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Показывать посещенные события'),
                  subtitle: const Text('В вашем профиле'),
                  value: _showVisitedEvents,
                  activeThumbColor: const Color(0xFF5E60CE),
                  onChanged: (bool value) {
                    setState(() {
                      _showVisitedEvents = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Получать уведомления о матчах'),
                  subtitle: const Text('Когда появляется новое совпадение'),
                  value: _matchNotifications,
                  activeThumbColor: const Color(0xFF5E60CE),
                  onChanged: (bool value) {
                    setState(() {
                      _matchNotifications = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
