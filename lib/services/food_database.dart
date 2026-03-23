import 'package:flutter/services.dart' show rootBundle;
import '../models/food_item.dart';

class FoodDatabase {
  static List<FoodItem> _allFoods = [];
  static bool _isLoaded = false;

  /// Load the food database from the CSV asset.
  /// Must be called once at app startup (e.g. in main() or a splash screen).
  static Future<void> load() async {
    if (_isLoaded) return;

    final csvString = await rootBundle.loadString('assets/data/food_knowledge_dataset.csv');
    final lines = csvString
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return;

    final headers = _parseCsvLine(lines.first);
    final List<FoodItem> items = [];

    for (var i = 1; i < lines.length; i++) {
      final values = _parseCsvLine(lines[i]);
      if (values.length < headers.length) continue;

      final Map<String, String> row = {};
      for (var j = 0; j < headers.length; j++) {
        row[headers[j]] = values[j];
      }

      try {
        items.add(FoodItem.fromCsvRow(row));
      } catch (_) {
        // Skip malformed rows
      }
    }

    _allFoods = items;
    _isLoaded = true;
  }

  /// Parse a CSV line, handling fields that may contain commas inside quotes.
  static List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  static List<FoodItem> get allFoods {
    assert(_isLoaded, 'FoodDatabase.load() must be called before accessing data');
    return List.unmodifiable(_allFoods);
  }

  static List<FoodItem> search(String query) {
    final lower = query.toLowerCase();
    return _allFoods
        .where((f) =>
            f.name.toLowerCase().contains(lower) ||
            f.category.toLowerCase().contains(lower) ||
            f.role.toLowerCase().contains(lower))
        .toList();
  }

  static List<String> get categories =>
      _allFoods.map((f) => f.category).toSet().toList()..sort();

  static List<FoodItem> byCategory(String category) =>
      _allFoods.where((f) => f.category == category).toList();

  static FoodItem? findById(String id) {
    try {
      return _allFoods.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find the best substitutions for a given item based on lower carbon impact
  /// within the same food role or category.
  static List<FoodItem> findAlternatives(FoodItem item, {int limit = 5}) {
    return _allFoods
        .where((f) =>
            f.id != item.id &&
            (f.category == item.category || f.role == item.role) &&
            f.carbonPerKg < item.carbonPerKg)
        .toList()
      ..sort((a, b) => a.carbonPerKg.compareTo(b.carbonPerKg))
      ..take(limit);
  }
}
