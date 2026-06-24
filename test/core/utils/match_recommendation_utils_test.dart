import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/core/utils/match_recommendation_utils.dart';
import 'package:andexevents/data/models/user_model.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  UserModel user({
    required String id,
    List<String> interests = const <String>[],
    double? lat,
    double? lon,
    String? photoUrl,
    String? bio,
    List<String> photos = const <String>[],
  }) {
    return UserModel.fromJson(<String, dynamic>{
      'id': id,
      'supabaseUid': 'sb-$id',
      'email': '$id@example.com',
      'displayName': id,
      'interests': interests,
      'lastLatitude': lat,
      'lastLongitude': lon,
      'photoUrl': photoUrl,
      'photos': photos,
      'bio': bio,
      'isOnboardingCompleted': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
  }

  test('sortUsers prioritizes incoming likes and common interests', () {
    final current = user(
      id: 'me',
      interests: const <String>['Music', 'Sport'],
      lat: 55.75,
      lon: 37.62,
      photoUrl: 'p',
      bio: 'bio',
    );
    final incoming = user(id: 'incoming', interests: const <String>['IT']);
    final common = user(
      id: 'common',
      interests: const <String>['Music', 'Sport', 'Art'],
    );
    final few = user(id: 'few', interests: const <String>['Music']);

    final sorted = MatchRecommendationUtils.sortUsers(
      users: <UserModel>[few, common, incoming],
      currentUser: current,
      incomingLikeUserIds: <String>{'incoming'},
    );

    expect(sorted.map((u) => u.id).toList(), <String>['incoming', 'common', 'few']);
  });

  test('empty profile gets completeness penalty', () {
    final current = user(id: 'me', interests: const <String>['Music']);
    final empty = user(id: 'empty');
    final rich = user(
      id: 'rich',
      interests: const <String>['Music'],
      photoUrl: 'p',
      bio: 'bio',
    );

    final emptyScore = MatchRecommendationUtils.scoreUser(
      candidate: empty,
      currentUser: current,
    );
    final richScore = MatchRecommendationUtils.scoreUser(
      candidate: rich,
      currentUser: current,
    );

    expect(richScore, greaterThan(emptyScore));
  });

  test('buildSharedGoingEventCounts counts intersection of GOING events', () {
    final counts = MatchRecommendationUtils.buildSharedGoingEventCounts(
      currentUserGoingEventIds: <String>{'e1', 'e2'},
      candidateGoingEventIdsByUser: <String, Set<String>>{
        'a': <String>{'e1'},
        'b': <String>{'e1', 'e2', 'e3'},
      },
    );

    expect(counts['a'], 1);
    expect(counts['b'], 2);
  });

  test('profileCompletenessPenalty mirrors backend partial penalties', () {
    final current = user(id: 'me', interests: const <String>['Music']);
    final partial = user(
      id: 'partial',
      interests: const <String>['Music'],
    );

    final partialScore = MatchRecommendationUtils.scoreUser(
      candidate: partial,
      currentUser: current,
    );
    final richScore = MatchRecommendationUtils.scoreUser(
      candidate: user(
        id: 'rich',
        interests: const <String>['Music'],
        photoUrl: 'p',
        bio: 'bio',
      ),
      currentUser: current,
    );

    expect(richScore, greaterThan(partialScore));
  });

  test('sharedGoingEventCounts boosts users with common events', () {
    final current = user(id: 'me', interests: const <String>['A']);
    final a = user(id: 'a', interests: const <String>['A', 'B', 'C']);
    final b = user(id: 'b', interests: const <String>['A']);

    final sorted = MatchRecommendationUtils.sortUsers(
      users: <UserModel>[a, b],
      currentUser: current,
      sharedGoingEventCounts: const <String, int>{'b': 2},
    );

    expect(sorted.first.id, 'b');
  });

  test('commonInterestLabels preserves spelling and ignores case', () {
    final labels = MatchRecommendationUtils.commonInterestLabels(
      left: const <String>['Музыка', 'Спорт'],
      right: const <String>['музыка', 'Кино', 'СПОРТ'],
    );

    expect(labels, containsAll(<String>['Музыка', 'Спорт']));
    expect(labels.length, 2);
  });
}
