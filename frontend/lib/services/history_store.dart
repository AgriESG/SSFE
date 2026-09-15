import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';

/// On-device history of basket analyses. Newest first, capped so the stored
/// blob can't grow without bound on a phone that's had the app a long time.
class HistoryStore {
  static const _key = 'basket_history_v1';
  static const _maxEntries = 200;

  static Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  /// Insert-or-replace by id, then persist. Used both to create an entry
  /// (Impact Dashboard) and to update the same entry as swaps are accepted
  /// or undone (Optimised Basket).
  static Future<void> upsert(HistoryEntry entry) async {
    final entries = await load();
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.insert(0, entry);
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    await _save(entries);
  }

  static Future<void> remove(String id) async {
    final entries = await load();
    entries.removeWhere((e) => e.id == id);
    await _save(entries);
  }

  static Future<void> _save(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
