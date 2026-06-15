import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/core/utils/match_feed_utils.dart';
import 'package:andexevents/data/models/user_model.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  UserModel makeUser(String id) {
    return UserModel.fromJson(<String, dynamic>{
      'id': id,
      'supabaseUid': 'sb-$id',
      'email': '$id@example.com',
      'isOnboardingCompleted': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
  }

  test('preserveServerMatchOrder keeps backend order after filtering', () {
    final a = makeUser('a');
    final b = makeUser('b');
    final c = makeUser('c');

    final ordered = preserveServerMatchOrder(
      serverOrder: <UserModel>[b, a, c],
      filteredById: <String, UserModel>{
        'a': a,
        'c': c,
      },
    );

    expect(ordered.map((u) => u.id).toList(), <String>['a', 'c']);
  });
}
