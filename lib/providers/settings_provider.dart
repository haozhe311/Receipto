import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:receipto/services/database_helper.dart';
import 'package:receipto/services/secure_storage_service.dart';

/// Manages AI provider selection and per-provider API key lists.
///
/// Keys are stored in the SQLite settings table under [_keysKey] as a JSON map:
///   { "gemini": ["key1", "key2"], "openai": ["key1"], "groq": [] }
///
/// The active key index per provider is stored under [_activeIndexKey]:
///   { "gemini": 0, "openai": 0, "groq": -1 }
///
/// An index of -1 means no key is active (list is empty).
///
/// On first load, any legacy single key stored via [SecureStorageService] is
/// migrated into the new structure under the previously selected provider.
class SettingsProvider extends ChangeNotifier {
  static const String _keysKey = 'api_keys_v2';
  static const String _activeIndexKey = 'active_key_index';
  static const String _groqModelKey = 'groq_model';

  static const List<String> _providers = ['gemini', 'openai', 'groq'];

  /// Selectable Groq model IDs.
  static const String groqLlama = 'llama-3.1-8b-instant';
  static const String groqGptOss = 'openai/gpt-oss-120b';

  final Map<String, List<String>> _keys = {
    'gemini': [],
    'openai': [],
    'groq': [],
  };
  final Map<String, int> _activeIndex = {
    'gemini': -1,
    'openai': -1,
    'groq': -1,
  };
  String _aiProvider = 'gemini';
  String _groqModel = groqLlama;

  // ── Public getters ────────────────────────────────────────────────────────

  String get aiProvider => _aiProvider;

  /// The Groq model ID used for chat and receipt parsing.
  String get groqModel => _groqModel;

  /// All keys saved for [provider].
  List<String> keysFor(String provider) =>
      List.unmodifiable(_keys[provider] ?? []);

  /// Index of the active key for [provider]. -1 when the list is empty.
  int activeIndexFor(String provider) => _activeIndex[provider] ?? -1;

  /// The active key for [provider], or null if none is saved.
  String? activeKeyFor(String provider) {
    final list = _keys[provider] ?? [];
    final idx = _activeIndex[provider] ?? -1;
    if (list.isEmpty || idx < 0 || idx >= list.length) { return null; }
    return list[idx];
  }

  /// Active key for the currently selected provider (used by AiService).
  String? get apiKey => activeKeyFor(_aiProvider);

  /// True when the current provider has at least one active key.
  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Loads all settings from persistent storage. Call once at app startup.
  Future<void> loadSettings() async {
    // 1. Load provider preference (still in SecureStorage).
    _aiProvider =
        await SecureStorageService.read(SecureStorageService.keyAiProvider) ??
            'gemini';

    // 1b. Load Groq model preference.
    _groqModel =
        await DatabaseHelper.instance.getSetting(_groqModelKey) ?? groqLlama;

    // 2. Load key lists.
    final keysRaw = await DatabaseHelper.instance.getSetting(_keysKey);
    if (keysRaw != null) {
      final decoded = jsonDecode(keysRaw) as Map<String, dynamic>;
      for (final p in _providers) {
        _keys[p] = (decoded[p] as List<dynamic>?)?.cast<String>() ?? [];
      }
    } else {
      // First launch after this version: migrate legacy single key if present.
      final oldKey =
          await SecureStorageService.read(SecureStorageService.keyApiKey);
      if (oldKey != null && oldKey.isNotEmpty) {
        _keys[_aiProvider] = [oldKey];
        await SecureStorageService.delete(SecureStorageService.keyApiKey);
      }
      await _persistKeys();
    }

    // 3. Load active indices.
    final idxRaw = await DatabaseHelper.instance.getSetting(_activeIndexKey);
    if (idxRaw != null) {
      final decoded = jsonDecode(idxRaw) as Map<String, dynamic>;
      for (final p in _providers) {
        _activeIndex[p] = (decoded[p] as int?) ?? -1;
      }
      // Clamp in case keys were removed outside normal flow.
      for (final p in _providers) {
        final list = _keys[p]!;
        if (list.isEmpty) {
          _activeIndex[p] = -1;
        } else if (_activeIndex[p]! >= list.length) {
          _activeIndex[p] = list.length - 1;
        }
      }
    } else {
      // Default: first key in each list is active.
      for (final p in _providers) {
        _activeIndex[p] = _keys[p]!.isNotEmpty ? 0 : -1;
      }
      await _persistActiveIndex();
    }

    notifyListeners();
  }

  // ── Provider selection ────────────────────────────────────────────────────

  Future<void> setAiProvider(String provider) async {
    _aiProvider = provider;
    await SecureStorageService.write(
      SecureStorageService.keyAiProvider,
      provider,
    );
    notifyListeners();
  }

  /// Chooses which Groq model to use ([groqLlama] or [groqGptOss]).
  Future<void> setGroqModel(String model) async {
    _groqModel = model;
    await DatabaseHelper.instance.setSetting(_groqModelKey, model);
    notifyListeners();
  }

  // ── Key management ────────────────────────────────────────────────────────

  /// Appends [key] to [provider]'s list and sets it as the active key.
  Future<void> addKey(String provider, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) { return; }
    _keys[provider] = [...(_keys[provider] ?? []), trimmed];
    _activeIndex[provider] = _keys[provider]!.length - 1;
    await _persistKeys();
    await _persistActiveIndex();
    notifyListeners();
  }

  /// Deletes the key at [index] from [provider]'s list.
  /// Adjusts the active index so it always points to a valid key (or -1).
  Future<void> deleteKey(String provider, int index) async {
    final list = List<String>.from(_keys[provider] ?? []);
    if (index < 0 || index >= list.length) { return; }
    list.removeAt(index);
    _keys[provider] = list;

    if (list.isEmpty) {
      _activeIndex[provider] = -1;
    } else {
      final current = _activeIndex[provider] ?? 0;
      if (current >= list.length) {
        _activeIndex[provider] = list.length - 1;
      } else if (current == index) {
        _activeIndex[provider] = 0;
      }
      // If current < index, the active key is unchanged — no adjustment needed.
    }

    await _persistKeys();
    await _persistActiveIndex();
    notifyListeners();
  }

  /// Sets the active key for [provider] to [index].
  Future<void> setActiveKey(String provider, int index) async {
    final list = _keys[provider] ?? [];
    if (index < 0 || index >= list.length) { return; }
    _activeIndex[provider] = index;
    await _persistActiveIndex();
    notifyListeners();
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  Future<void> _persistKeys() async {
    await DatabaseHelper.instance.setSetting(
      _keysKey,
      jsonEncode({for (final p in _providers) p: _keys[p]}),
    );
  }

  Future<void> _persistActiveIndex() async {
    await DatabaseHelper.instance.setSetting(
      _activeIndexKey,
      jsonEncode(_activeIndex),
    );
  }
}
