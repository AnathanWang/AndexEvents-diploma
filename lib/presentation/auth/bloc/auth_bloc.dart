import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/services/logger_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC для управления авторизацией
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _authStateSubscription;

  /// Prevents the authStateChanges listener from re-triggering AuthCheckRequested
  /// while a login/register/logout handler is already running.
  bool _handlingAuthAction = false;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial()) {
    // Регистрируем обработчики событий
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthGoogleSignInRequested>(_onAuthGoogleSignInRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthPasswordResetRequested>(_onAuthPasswordResetRequested);

    _authStateSubscription = _authService.authStateChanges.listen((_) {
      // Skip if a login/register/logout handler triggered this change
      if (!_handlingAuthAction) {
        add(const AuthCheckRequested());
      }
    });
  }

  /// Проверка начального состояния авторизации
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    LoggerService.info('🔵 [AuthBloc] Проверка начального состояния...');
    final User? user = _authService.currentUser;
    if (user != null) {
      LoggerService.info('🔵 [AuthBloc] Пользователь найден в Firebase: ${user.email}');
      
      try {
        await user.reload();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'user-disabled') {
          LoggerService.error('🔴 [AuthBloc] Пользователь удален или заблокирован в Firebase. Выполняю автоматический выход.');
          await _authService.signOut();
          emit(const AuthUnauthenticated());
          return;
        }
      } catch (_) {
        // Игнорируем сетевые ошибки, если нет интернета, чтобы пользователь все равно мог зайти в приложение
        LoggerService.warning('🟡 [AuthBloc] Не удалось выполнить usel.reload(), возможно нет сети.');
      }

      final cachedOnboarding = await _authService.getCachedOnboardingStatus();
      if (cachedOnboarding != null) {
        LoggerService.info('🔵 [AuthBloc] Используем кэш онбординга: $cachedOnboarding');
        emit(AuthAuthenticated(user: user, isOnboardingCompleted: cachedOnboarding));
      }

      try {
        // Загружаем профиль из бэкенда для проверки onboarding
        LoggerService.info('🔵 [AuthBloc] Загрузка профиля из backend...');
        final userProfile = await _authService
            .getCurrentUserProfile()
            .timeout(const Duration(seconds: 6));
        LoggerService.info('🔵 [AuthBloc] Профиль получен: $userProfile');
        final bool isOnboardingCompleted = userProfile['isOnboardingCompleted'] ?? false;
        LoggerService.info('🔵 [AuthBloc] isOnboardingCompleted = $isOnboardingCompleted');
        await _authService.cacheOnboardingStatus(isOnboardingCompleted);
        emit(AuthAuthenticated(user: user, isOnboardingCompleted: isOnboardingCompleted));
      } catch (e) {
        if (cachedOnboarding == null) {
          final isNewUser = (user.metadata.creationTime != null && 
                             DateTime.now().difference(user.metadata.creationTime!) < const Duration(hours: 1));
          final fallbackOnboarding = isNewUser ? false : true;
          
          LoggerService.warning('🟡 [AuthBloc] Профиль не загрузился и кэша нет, fallbackOnboarding=$fallbackOnboarding', e);
          emit(AuthAuthenticated(user: user, isOnboardingCompleted: fallbackOnboarding));
        } else {
          LoggerService.warning('🟡 [AuthBloc] Не удалось загрузить профиль на старте, продолжаем с кэшем', e);
        }
      }
    } else {
      LoggerService.info('🔵 [AuthBloc] Пользователь не найден, показываем Onboarding');
      emit(const AuthUnauthenticated());
    }
  }

  /// Вход через Email и пароль
  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _handlingAuthAction = true;
    emit(const AuthLoading());
    try {
      final userCredential = await _authService.signInWithEmail(
        email: event.email,
        password: event.password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Ошибка входа: пользователь не найден');
      }

      // Загружаем профиль для проверки onboarding
      try {
        LoggerService.info('🔵 [AuthBloc] Загрузка профиля пользователя...');
        final userProfile = await _authService.getCurrentUserProfile();
        LoggerService.info('🔵 [AuthBloc] Профиль получен: $userProfile');
        final bool isOnboardingCompleted = userProfile['isOnboardingCompleted'] ?? false;
        LoggerService.info('🔵 [AuthBloc] isOnboardingCompleted = $isOnboardingCompleted');
        await _authService.cacheOnboardingStatus(isOnboardingCompleted);
        emit(AuthAuthenticated(
          user: user,
          isOnboardingCompleted: isOnboardingCompleted,
        ));
      } catch (e) {
        final cachedOnboarding = await _authService.getCachedOnboardingStatus();
        LoggerService.error('🔴 [AuthBloc] Ошибка загрузки профиля', e);
        
        final isNewUser = (user.metadata.creationTime != null && 
                           DateTime.now().difference(user.metadata.creationTime!) < const Duration(hours: 1));
        
        final fallbackOnboarding = cachedOnboarding ?? (isNewUser ? false : true);
        LoggerService.warning('🟡 [AuthBloc] Используем fallback onboarding=$fallbackOnboarding');
        
        emit(AuthAuthenticated(
          user: user,
          isOnboardingCompleted: fallbackOnboarding,
        ));
      }
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Login error: $e');
      emit(AuthFailure(message: e.toString()));
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Регистрация через Email и пароль
  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    LoggerService.debug('🔵 [AuthBloc] Регистрация началась');
    _handlingAuthAction = true;
    emit(const AuthLoading());
    try {
      final userCredential = await _authService.signUpWithEmail(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Ошибка регистрации: пользователь не создан');
      }

      // После регистрации пользователь должен пройти онбординг (кэшируем это)
      await _authService.cacheOnboardingStatus(false);

      emit(AuthAuthenticated(
        user: user,
        isOnboardingCompleted: false,
      ));
      LoggerService.debug('🔵 [AuthBloc] AuthAuthenticated эмитен');
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Register error: $e');
      // ПРИМЕЧАНИЕ: Если бэкенд упал, Firebase Auth всё равно мог создать пользователя.
      // Поэтому если мы получили ошибку Backend'а после успешного создания в Firebase, 
      // лучше залогинить его и перебросить на верификацию, иначе он зависнет с ошибкой.
      final user = _authService.currentUser;
      if (user != null) {
         // Сохраняем, что он не прошел онбординг
         await _authService.cacheOnboardingStatus(false);
         emit(AuthAuthenticated(
           user: user,
           isOnboardingCompleted: false,
         ));
      } else {
         emit(AuthFailure(message: e.toString()));
      }
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Вход через Google
  Future<void> _onAuthGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    LoggerService.debug('🔵 [AuthBloc] Google Sign-In requested');
    _handlingAuthAction = true;
    emit(const AuthLoading());
    try {
      LoggerService.debug('🔵 [AuthBloc] Вызываем authService.signInWithGoogleAndGetStatus()');
      final result = await _authService.signInWithGoogleAndGetStatus();
      
      final UserCredential response = result['userCredential'] as UserCredential;
      final bool isOnboardingCompleted = result['isOnboardingCompleted'] as bool;
      
      final user = response.user;
      if (user == null) throw Exception('Ошибка Google Sign-In: пользователь не найден');

      LoggerService.debug('🔵 [AuthBloc] Google Sign-In успешен, isOnboardingCompleted: $isOnboardingCompleted');
      
      emit(AuthAuthenticated(
        user: user,
        isOnboardingCompleted: isOnboardingCompleted,
      ));
      await _authService.cacheOnboardingStatus(isOnboardingCompleted);
    } catch (e) {
      LoggerService.error('🔴 [AuthBloc] Google Sign-In ошибка: $e');
      emit(AuthFailure(message: e.toString()));
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Выход из системы
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _handlingAuthAction = true;
    emit(const AuthLoading());
    try {
      await _authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    } finally {
      _handlingAuthAction = false;
    }
  }

  /// Сброс пароля
  Future<void> _onAuthPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.resetPassword(event.email);
      emit(const AuthPasswordResetSuccess());
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
      // emit(const AuthUnauthenticated());
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
