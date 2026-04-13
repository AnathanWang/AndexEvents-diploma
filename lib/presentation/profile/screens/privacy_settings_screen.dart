import 'package:flutter/material.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF161823)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Приватность',
          style: TextStyle(
            color: Color(0xFF161823),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: const Text('Готово', style: TextStyle(color: Color(0xFF75878A), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('Показывать посещенные события'),
                  value: _showVisitedEvents,
                  activeThumbColor: const Color(0xFF75878A),
                  onChanged: (bool value) => setState(() => _showVisitedEvents = value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Показывать профиль в мэтчах'),
                  value: _showInMatches,
                  activeThumbColor: const Color(0xFF75878A),
                  onChanged: (bool value) => setState(() => _showInMatches = value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Инкогнито режим (Только взаимные)'),
                  value: _incognitoMode,
                  activeThumbColor: const Color(0xFF75878A),
                  onChanged: (bool value) => setState(() => _incognitoMode = value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Скрывать статус "в сети"'),
                  value: _hideOnlineStatus,
                  activeThumbColor: const Color(0xFF75878A),
                  onChanged: (bool value) => setState(() => _hideOnlineStatus = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
