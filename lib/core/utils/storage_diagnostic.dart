import 'package:supabase_flutter/supabase_flutter.dart';

/// Диагностическая утилита для проверки Supabase Storage
class StorageDiagnostic {
  final SupabaseClient supabase;

  StorageDiagnostic(this.supabase);

  /// Проверить статус аватарок bucket
  Future<Map<String, dynamic>> checkAvatarsBucket() async {
    try {
      print('🔍 [StorageDiagnostic] Проверяем bucket "avatars"...');

      // Проверяем, авторизован ли пользователь
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('🔴 [StorageDiagnostic] Пользователь не авторизован');
        return {
          'status': 'error',
          'message': 'Пользователь не авторизован',
        };
      }

      print('✅ [StorageDiagnostic] Пользователь авторизован: ${user.id}');

      // Проверяем доступ к bucket
      try {
        // Пытаемся получить список файлов в папке пользователя
        final files = await supabase.storage
            .from('avatars')
            .list(path: user.id);

        print('✅ [StorageDiagnostic] Доступ к bucket успешен');
        print('📁 [StorageDiagnostic] Файлов в папке ${user.id}: ${files.length}');

        return {
          'status': 'success',
          'message': 'Bucket "avatars" доступен',
          'userId': user.id,
          'filesCount': files.length,
        };
      } catch (e) {
        print('🔴 [StorageDiagnostic] Ошибка доступа к bucket: $e');
        return {
          'status': 'error',
          'message': 'Ошибка доступа к bucket',
          'error': e.toString(),
        };
      }
    } catch (e) {
      print('🔴 [StorageDiagnostic] Критическая ошибка: $e');
      return {
        'status': 'error',
        'message': 'Критическая ошибка',
        'error': e.toString(),
      };
    }
  }

  /// Проверить статус events bucket
  Future<Map<String, dynamic>> checkEventsBucket() async {
    try {
      print('🔍 [StorageDiagnostic] Проверяем bucket "events"...');

      final user = supabase.auth.currentUser;
      if (user == null) {
        return {
          'status': 'error',
          'message': 'Пользователь не авторизован',
        };
      }

      try {
        final files = await supabase.storage
            .from('events')
            .list(path: user.id);

        print('✅ [StorageDiagnostic] Bucket "events" доступен');
        print('📁 [StorageDiagnostic] Файлов в папке ${user.id}: ${files.length}');

        return {
          'status': 'success',
          'message': 'Bucket "events" доступен',
          'userId': user.id,
          'filesCount': files.length,
        };
      } catch (e) {
        print('🔴 [StorageDiagnostic] Ошибка доступа к bucket: $e');
        return {
          'status': 'error',
          'message': 'Ошибка доступа к bucket',
          'error': e.toString(),
        };
      }
    } catch (e) {
      print('🔴 [StorageDiagnostic] Критическая ошибка: $e');
      return {
        'status': 'error',
        'message': 'Критическая ошибка',
        'error': e.toString(),
      };
    }
  }

  /// Запустить полную диагностику
  Future<void> runFullDiagnostics() async {
    print('\n🔍 ════════════════════════════════════════');
    print('🔍 ЗАПУСК ПОЛНОЙ ДИАГНОСТИКИ STORAGE');
    print('🔍 ════════════════════════════════════════\n');

    final avatarResult = await checkAvatarsBucket();
    final eventResult = await checkEventsBucket();

    print('\n🔍 ════════════════════════════════════════');
    print('🔍 РЕЗУЛЬТАТЫ ДИАГНОСТИКИ:');
    print('🔍 ════════════════════════════════════════');
    print('Avatars bucket: ${avatarResult['status']}');
    print('Events bucket: ${eventResult['status']}');
    print('🔍 ════════════════════════════════════════\n');
  }
}
