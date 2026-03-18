import 'package:shared_preferences/shared_preferences.dart';

class MatchSeenService {
  static const String _keyPrefix = 'seen_match_user_ids:';

  String _keyFor(String currentUserId) => '$_keyPrefix$currentUserId';

  Future<Set<String>> getSeenUserIds(String currentUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyFor(currentUserId)) ?? const <String>[];
    return list.where((e) => e.trim().isNotEmpty).toSet();
  }

  Future<void> markSeen(String currentUserId, String otherUserId) async {
    final id = otherUserId.trim();
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(currentUserId);
    final current = prefs.getStringList(key) ?? <String>[];

    if (current.contains(id)) return;
    await prefs.setStringList(key, <String>[...current, id]);
  }

  Future<void> markSeenMany(
    String currentUserId,
    Iterable<String> otherUserIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(currentUserId);
    final current = (prefs.getStringList(key) ?? <String>[]).toSet();

    for (final raw in otherUserIds) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      current.add(id);
    }

    await prefs.setStringList(key, current.toList());
  }

  Future<void> clear(String currentUserId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(currentUserId));
  }
}
