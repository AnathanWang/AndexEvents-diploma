import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class IdTokenProvider {
  const IdTokenProvider();

  Future<String?> getIdToken({
    int maxAttempts = 10,
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final token = await user.getIdToken();
          if (token != null && token.isNotEmpty) {
            return token;
          }
        } catch (_) {
          // Ignore and retry.
        }
      }

      if (attempt < maxAttempts - 1) {
        await Future.delayed(delay);
      }
    }

    return FirebaseAuth.instance.currentUser?.getIdToken();
  }
}
