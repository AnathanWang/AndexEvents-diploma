import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/logger_service.dart';
import '../models/event_draft_model.dart';

class EventDraftService {
  static const String _key = 'event_create_draft_v1';

  Future<List<EventDraftModel>> listDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) return <EventDraftModel>[];
      final decoded = jsonDecode(raw);

      // Backward compatibility: previously stored a single draft object.
      if (decoded is Map<String, dynamic>) {
        return <EventDraftModel>[EventDraftModel.fromJson(decoded)];
      }

      if (decoded is List) {
        return decoded
            .whereType<dynamic>()
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .map(EventDraftModel.fromJson)
            .toList();
      }

      return <EventDraftModel>[];
    } catch (e, st) {
      LoggerService.error('[EventDraftService] listDrafts failed', e, st);
      return <EventDraftModel>[];
    }
  }

  Future<EventDraftModel?> getDraftById(String id) async {
    final all = await listDrafts();
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> upsertDraft(EventDraftModel draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await listDrafts();
      final idx = drafts.indexWhere((d) => d.id == draft.id);
      if (idx == -1) {
        drafts.insert(0, draft);
      } else {
        drafts[idx] = draft;
      }
      await prefs.setString(
        _key,
        jsonEncode(drafts.map((d) => d.toJson()).toList()),
      );
    } catch (e, st) {
      LoggerService.error('[EventDraftService] upsertDraft failed', e, st);
      rethrow;
    }
  }

  Future<void> deleteDraft(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await listDrafts();
      drafts.removeWhere((d) => d.id == id);
      if (drafts.isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(
          _key,
          jsonEncode(drafts.map((d) => d.toJson()).toList()),
        );
      }
    } catch (e, st) {
      LoggerService.error('[EventDraftService] deleteDraft failed', e, st);
    }
  }

  Future<void> renameDraft(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await listDrafts();
      final idx = drafts.indexWhere((d) => d.id == id);
      if (idx == -1) return;
      drafts[idx] = drafts[idx].copyWith(name: trimmed, savedAt: DateTime.now());
      await prefs.setString(
        _key,
        jsonEncode(drafts.map((d) => d.toJson()).toList()),
      );
    } catch (e, st) {
      LoggerService.error('[EventDraftService] renameDraft failed', e, st);
    }
  }

  Future<void> clearAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e, st) {
      LoggerService.error('[EventDraftService] clearAllDrafts failed', e, st);
    }
  }
}

