import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/data/models/user_model.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  test('fromJson parses minAge and maxAge', () {
    final user = UserModel.fromJson(<String, dynamic>{
      'id': 'u-1',
      'supabaseUid': 'sb-1',
      'email': 'u1@example.com',
      'minAge': 22,
      'maxAge': 35,
      'isOnboardingCompleted': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    expect(user.minAge, 22);
    expect(user.maxAge, 35);
  });

  test('toJson and copyWith keep match age filters', () {
    final user = UserModel.fromJson(<String, dynamic>{
      'id': 'u-1',
      'supabaseUid': 'sb-1',
      'email': 'u1@example.com',
      'minAge': 18,
      'maxAge': 40,
      'isOnboardingCompleted': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    final updated = user.copyWith(minAge: 25, maxAge: 30);
    expect(updated.minAge, 25);
    expect(updated.maxAge, 30);
    expect(updated.toJson()['minAge'], 25);
    expect(updated.toJson()['maxAge'], 30);
  });
}
