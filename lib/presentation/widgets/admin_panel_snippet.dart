import 'package:flutter/material.dart';

class AdminPanelSnippet extends StatelessWidget {
  const AdminPanelSnippet({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              Icon(Icons.shield_moon_outlined, color: Color(0xFF5E60CE)),
              SizedBox(width: 8),
              Text(
                'Статус модерации',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const <Widget>[
              _StatPill(label: 'На проверке', value: '5'),
              SizedBox(width: 12),
              _StatPill(label: 'Опубликовано', value: '128'),
              SizedBox(width: 12),
              _StatPill(label: 'Жалобы', value: '2'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Админы могут подтверждать события, блокировать спам и смотреть логи.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F2FB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5E60CE),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4A4D6A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
