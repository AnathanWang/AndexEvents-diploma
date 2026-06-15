import '../../data/models/user_model.dart';

/// Preserves backend ranking order after client-side filtering.
List<UserModel> preserveServerMatchOrder({
  required List<UserModel> serverOrder,
  required Map<String, UserModel> filteredById,
}) {
  final ordered = <UserModel>[];
  for (final UserModel user in serverOrder) {
    final kept = filteredById[user.id];
    if (kept != null) {
      ordered.add(kept);
    }
  }
  return ordered;
}
