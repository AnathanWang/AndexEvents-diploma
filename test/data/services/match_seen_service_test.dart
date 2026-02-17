import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:andexevents/data/services/match_seen_service.dart';

void main() {
  late MatchSeenService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MatchSeenService();
  });

  group('MatchSeenService', () {
    test('getSeenUserIds returns empty set initially', () async {
      final ids = await service.getSeenUserIds('user-1');
      expect(ids, isEmpty);
    });

    test('markSeen adds user id', () async {
      await service.markSeen('user-1', 'other-1');
      final ids = await service.getSeenUserIds('user-1');
      expect(ids, {'other-1'});
    });

    test('markSeen is idempotent', () async {
      await service.markSeen('user-1', 'other-1');
      await service.markSeen('user-1', 'other-1');
      final ids = await service.getSeenUserIds('user-1');
      expect(ids, {'other-1'});
    });

    test('markSeen ignores empty string', () async {
      await service.markSeen('user-1', '');
      await service.markSeen('user-1', '   ');
      final ids = await service.getSeenUserIds('user-1');
      expect(ids, isEmpty);
    });

    test('markSeenMany adds multiple ids', () async {
      await service.markSeenMany('user-1', ['a', 'b', 'c']);
      final ids = await service.getSeenUserIds('user-1');
      expect(ids, {'a', 'b', 'c'});
    });

    test('markSeenMany skips empty strings', () async {
      await service.markSeenMany('user-1', ['a', '', '  ', 'b']);
      final ids = await service.getSeenUserIds('user-1');
      expect(ids, {'a', 'b'});
    });

    test('markSeenMany merges with existing', () async {
      await service.markSeen('user-1', 'existing');
      await service.markSeenMany('user-1', ['new-1', 'new-2']);
      final ids = await service.getSeenUserIds('user-1');
      expect(ids, {'existing', 'new-1', 'new-2'});
    });

    test('clear removes all seen ids', () async {
      await service.markSeenMany('user-1', ['a', 'b', 'c']);
      await service.clear('user-1');
      final ids = await service.getSeenUserIds('user-1');
      expect(ids, isEmpty);
    });

    test('different users have separate seen lists', () async {
      await service.markSeen('user-1', 'target-a');
      await service.markSeen('user-2', 'target-b');

      final ids1 = await service.getSeenUserIds('user-1');
      final ids2 = await service.getSeenUserIds('user-2');

      expect(ids1, {'target-a'});
      expect(ids2, {'target-b'});
    });

    test('clear for one user does not affect another', () async {
      await service.markSeen('user-1', 'target-a');
      await service.markSeen('user-2', 'target-b');
      await service.clear('user-1');

      final ids1 = await service.getSeenUserIds('user-1');
      final ids2 = await service.getSeenUserIds('user-2');

      expect(ids1, isEmpty);
      expect(ids2, {'target-b'});
    });

    test('getSeenUserIds filters out empty strings from storage', () async {
      // Simulate corrupted data in prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'seen_match_user_ids:user-1',
        ['a', '', '  ', 'b'],
      );

      final ids = await service.getSeenUserIds('user-1');
      expect(ids, {'a', 'b'});
    });
  });
}
