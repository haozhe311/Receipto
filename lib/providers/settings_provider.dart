import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:receipto/services/ai_service.dart';
import 'package:receipto/services/database_helper.dart';
import 'package:receipto/services/secure_storage_service.dart';

/// Manages the Groq API key list and the selected Groq model.
///
/// Groq is the app's only AI provider (chat and receipt-scanning both use
/// it) — there is no provider selection.
///
/// Keys are stored in the SQLite settings table under [_keysKey] as a JSON
/// list of strings. The active key's index is stored under [_activeIndexKey].
/// An index of -1 means no key is active (list is empty).
///
/// On first load, both a legacy single-key format and the older
/// multi-provider map format (from before the app went Groq-only) are
/// migrated automatically — only the Groq key(s) are kept.
class SettingsProvider extends ChangeNotifier {
  static const String _keysKey = 'api_keys_v2';
  static const String _activeIndexKey = 'active_key_index';
  static const String _groqModelKey = 'groq_model';

  /// Selectable Groq model IDs.
  static const String groqGptOss120b = 'openai/gpt-oss-120b';
  static const String groqGptOss20b = 'openai/gpt-oss-20b';

  /// Same model that powers receipt-scanning vision — also selectable for chat.
  static const String groqQwen = AiService.groqVisionModel;

  static const List<String> _validModels = [
    groqGptOss120b,
    groqGptOss20b,
    groqQwen,
  ];

  List<String> _keys = [];
  int _activeIndex = -1;
  String _groqModel = groqGptOss120b;

  // ── Public getters ────────────────────────────────────────────────────────

  /// All saved Groq API keys.
  List<String> get keys => List.unmodifiable(_keys);

  /// Index of the active key. -1 when the list is empty.
  int get activeIndex => _activeIndex;

  /// The Groq model ID used for chat.
  String get groqModel => _groqModel;

  /// The active API key, or null if none is saved.
  String? get apiKey {
    if (_keys.isEmpty || _activeIndex < 0 || _activeIndex >= _keys.length) {
      return null;
    }
    return _keys[_activeIndex];
  }

  /// True when a Groq key is saved and active.
  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Loads all settings from persistent storage. Call once at app startup.
  Future<void> loadSettings() async {
    // 1. Load the Groq model preference, migrating away from any model that
    // no longer exists (e.g. the old Llama default).
    final storedModel =
        await DatabaseHelper.instance.getSetting(_groqModelKey);
    _groqModel =
        _validModels.contains(storedModel) ? storedModel! : groqGptOss120b;

    // 2. Load the key list — accepting the current flat-list shape, or the
    // older per-provider map shape (keeping only its "groq" entry).
    final keysRaw = await DatabaseHelper.instance.getSetting(_keysKey);
    if (keysRaw != null) {
      final decoded = jsonDecode(keysRaw);
      if (decoded is List) {
        _keys = decoded.cast<String>();
      } else if (decoded is Map<String, dynamic>) {
        _keys = (decoded['groq'] as List<dynamic>?)?.cast<String>() ?? [];
      }
    } else {
      // First launch after this version: migrate legacy single key if present.
      final oldKey =
          await SecureStorageService.read(SecureStorageService.keyApiKey);
      if (oldKey != null && oldKey.isNotEmpty) {
        _keys = [oldKey];
        await SecureStorageService.delete(SecureStorageService.keyApiKey);
      }
    }

    // 3. Load the active index — same dual-shape handling as the key list.
    final idxRaw = await DatabaseHelper.instance.getSetting(_activeIndexKey);
    if (idxRaw != null) {
      final decoded = jsonDecode(idxRaw);
      if (decoded is int) {
        _activeIndex = decoded;
      } else if (decoded is Map<String, dynamic>) {
        _activeIndex = (decoded['groq'] as int?) ?? -1;
      }
    }
    // Clamp in case keys were removed, or nothing was ever stored.
    if (_keys.isEmpty) {
      _activeIndex = -1;
    } else if (_activeIndex < 0 || _activeIndex >= _keys.length) {
      _activeIndex = 0;
    }

    // Re-persist in the current flat shape so future loads skip migration.
    await _persistKeys();
    await _persistActiveIndex();

    notifyListeners();
  }

  // ── Model selection ───────────────────────────────────────────────────────

  /// Chooses which Groq model to use for chat.
  Future<void> setGroqModel(String model) async {
    _groqModel = model;
    await DatabaseHelper.instance.setSetting(_groqModelKey, model);
    notifyListeners();
  }

  // ── Key management ────────────────────────────────────────────────────────

  /// Appends [key] to the saved list and sets it as the active key.
  Future<void> addKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    _keys = [..._keys, trimmed];
    _activeIndex = _keys.length - 1;
    await _persistKeys();
    await _persistActiveIndex();
    notifyListeners();
  }

  /// Deletes the key at [index]. Adjusts the active index so it always
  /// points to a valid key (or -1).
  Future<void> deleteKey(int index) async {
    if (index < 0 || index >= _keys.length) return;
    final list = List<String>.from(_keys)..removeAt(index);
    _keys = list;

    if (list.isEmpty) {
      _activeIndex = -1;
    } else if (_activeIndex >= list.length) {
      _activeIndex = list.length - 1;
    } else if (_activeIndex == index) {
      _activeIndex = 0;
    }
    // If _activeIndex < index, the active key is unchanged — no adjustment.

    await _persistKeys();
    await _persistActiveIndex();
    notifyListeners();
  }

  /// Sets the active key to [index].
  Future<void> setActiveKey(int index) async {
    if (index < 0 || index >= _keys.length) return;
    _activeIndex = index;
    await _persistActiveIndex();
    notifyListeners();
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  Future<void> _persistKeys() async {
    await DatabaseHelper.instance.setSetting(_keysKey, jsonEncode(_keys));
  }

  Future<void> _persistActiveIndex() async {
    await DatabaseHelper.instance
        .setSetting(_activeIndexKey, jsonEncode(_activeIndex));
  }
}
