import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/presentation/auth/bloc/auth_event.dart';
import 'package:andexevents/presentation/auth/bloc/auth_state.dart';

void main() {
  group('AuthEvent equality', () {
    test('AuthCheckRequested instances are equal', () {
      expect(
        const AuthCheckRequested(),
        equals(const AuthCheckRequested()),
      );
    });

    test('AuthLoginRequested with same data are equal', () {
      expect(
        const AuthLoginRequested(email: 'a@b.com', password: '123'),
        equals(const AuthLoginRequested(email: 'a@b.com', password: '123')),
      );
    });

    test('AuthLoginRequested with different data are not equal', () {
      expect(
        const AuthLoginRequested(email: 'a@b.com', password: '123'),
        isNot(equals(const AuthLoginRequested(email: 'x@y.com', password: '123'))),
      );
    });

    test('AuthRegisterRequested props include all fields', () {
      const event = AuthRegisterRequested(
        email: 'a@b.com',
        password: '123',
        displayName: 'Test',
      );
      expect(event.props, ['a@b.com', '123', 'Test']);
    });

    test('AuthGoogleSignInRequested instances are equal', () {
      expect(
        const AuthGoogleSignInRequested(),
        equals(const AuthGoogleSignInRequested()),
      );
    });

    test('AuthLogoutRequested instances are equal', () {
      expect(
        const AuthLogoutRequested(),
        equals(const AuthLogoutRequested()),
      );
    });

    test('AuthPasswordResetRequested equality by email', () {
      expect(
        const AuthPasswordResetRequested(email: 'a@b.com'),
        equals(const AuthPasswordResetRequested(email: 'a@b.com')),
      );
      expect(
        const AuthPasswordResetRequested(email: 'a@b.com'),
        isNot(equals(const AuthPasswordResetRequested(email: 'x@y.com'))),
      );
    });
  });

  group('AuthState equality', () {
    test('AuthInitial instances are equal', () {
      expect(const AuthInitial(), equals(const AuthInitial()));
    });

    test('AuthLoading instances are equal', () {
      expect(const AuthLoading(), equals(const AuthLoading()));
    });

    test('AuthUnauthenticated instances are equal', () {
      expect(const AuthUnauthenticated(), equals(const AuthUnauthenticated()));
    });

    test('AuthFailure with same message are equal', () {
      expect(
        const AuthFailure(message: 'error'),
        equals(const AuthFailure(message: 'error')),
      );
    });

    test('AuthFailure with different messages are not equal', () {
      expect(
        const AuthFailure(message: 'error1'),
        isNot(equals(const AuthFailure(message: 'error2'))),
      );
    });

    test('AuthPasswordResetSuccess instances are equal', () {
      expect(
        const AuthPasswordResetSuccess(),
        equals(const AuthPasswordResetSuccess()),
      );
    });

    test('different state types are not equal', () {
      expect(const AuthInitial(), isNot(equals(const AuthLoading())));
      expect(const AuthLoading(), isNot(equals(const AuthUnauthenticated())));
    });
  });
}
