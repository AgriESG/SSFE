class FoodItem {
  final String id;
  final String name;
  final String category;
  final String role;
  final String emoji;
  final double carbonPerKg; // kg CO2e per kg
  final double waterPerKg; // litres per kg
  final double landPerKg; // m² per kg
  final double pricePerKg; // £ per kg
  final double proteinPerKg; // g per kg
  final double caloriesPerKg; // kcal per kg
  final double carbsPerKg; // g per kg
  final double fatPerKg; // g per kg
  final double fibrePerKg; // g per kg
  final bool isSeasonal;
  final bool isLocal;
  final String? seasonalNote;
  double quantity; // kg

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.role,
    required this.emoji,
    required this.carbonPerKg,
    required this.waterPerKg,
    required this.landPerKg,
    required this.pricePerKg,
    required this.proteinPerKg,
    required this.caloriesPerKg,
    required this.carbsPerKg,
    required this.fatPerKg,
    required this.fibrePerKg,
    this.isSeasonal = false,
    this.isLocal = false,
    this.seasonalNote,
    this.quantity = 1.0,
  });

  double get totalCarbon => carbonPerKg * quantity;
  double get totalWater => waterPerKg * quantity;
  double get totalLand => landPerKg * quantity;
  double get totalPrice => pricePerKg * quantity;
  double get totalProtein => proteinPerKg * quantity;
  double get totalCalories => caloriesPerKg * quantity;
  double get totalCarbs => carbsPerKg * quantity;
  double get totalFat => fatPerKg * quantity;
  double get totalFibre => fibrePerKg * quantity;

  FoodItem copyWith({double? quantity}) {
    return FoodItem(
      id: id,
      name: name,
      category: category,
      role: role,
      emoji: emoji,
      carbonPerKg: carbonPerKg,
      waterPerKg: waterPerKg,
      landPerKg: landPerKg,
      pricePerKg: pricePerKg,
      proteinPerKg: proteinPerKg,
      caloriesPerKg: caloriesPerKg,
      carbsPerKg: carbsPerKg,
      fatPerKg: fatPerKg,
      fibrePerKg: fibrePerKg,
      isSeasonal: isSeasonal,
      isLocal: isLocal,
      seasonalNote: seasonalNote,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Create a FoodItem from a CSV row map
  factory FoodItem.fromCsvRow(Map<String, String> row) {
    final name = row['Food_name'] ?? '';
    final category = (row['Category'] ?? '').trim();
    final role = (row['Role'] ?? '').trim();

    return FoodItem(
      id: _generateId(name),
      name: name,
      category: _normaliseCategory(category),
      role: role,
      emoji: _emojiForCategory(_normaliseCategory(category), name),
      carbonPerKg: _parseDouble(row['Carbon (kg CO2e/kg)']),
      waterPerKg: _parseDouble(row['Water (L/kg)']),
      landPerKg: _parseDouble(row['Land (m2/kg)']),
      pricePerKg: _parseDouble(row['Price_estimate (£/kg)']),
      proteinPerKg: _parseDouble(row['Protein (g)']),
      caloriesPerKg: _parseDouble(row['Calories (kcal)']),
      carbsPerKg: _parseDouble(row['Carbs (g)']),
      fatPerKg: _parseDouble(row['Fat (g)']),
      fibrePerKg: _parseDouble(row['Fibre (g)']),
    );
  }

  static double _parseDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 0.0;
    return double.tryParse(value.trim()) ?? 0.0;
  }

  static String _generateId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _normaliseCategory(String raw) {
    final lower = raw.toLowerCase().trim();
    switch (lower) {
      case 'protein':
        return 'Protein';
      case 'dairy':
        return 'Dairy';
      case 'dairy alternative':
        return 'Dairy';
      case 'staples':
        return 'Staples';
      case 'vegetables':
        return 'Vegetables';
      case 'fruits':
      case 'fruit':
        return 'Fruits';
      default:
        if (lower.isEmpty) return 'Other';
        return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
    }
  }

  static String _emojiForCategory(String category, String name) {
    final lower = name.toLowerCase();

    // Specific name-based emojis
    if (lower.contains('chicken')) return '🍗';
    if (lower.contains('pork')) return '🥓';
    if (lower.contains('beef')) return '🥩';
    if (lower.contains('lamb')) return '🍖';
    if (lower.contains('salmon') || lower.contains('tuna') || lower.contains('prawn')) return '🐟';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('yogurt') || lower.contains('yoghurt')) return '🥄';
    if (lower.contains('cheese')) return '🧀';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('rice')) return '🍚';
    if (lower.contains('pasta')) return '🍝';
    if (lower.contains('oat')) return '🥣';
    if (lower.contains('potato')) return '🥔';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('carrot')) return '🥕';
    if (lower.contains('broccoli')) return '🥦';
    if (lower.contains('spinach')) return '🥬';
    if (lower.contains('onion') || lower.contains('leek')) return '🧅';
    if (lower.contains('pea')) return '🫛';
    if (lower.contains('apple')) return '🍎';
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('orange')) return '🍊';
    if (lower.contains('berr') || lower.contains('grape')) return '🍇';
    if (lower.contains('lentil') || lower.contains('chickpea') || lower.contains('bean')) return '🫘';
    if (lower.contains('tofu') || lower.contains('soy')) return '🫘';
    if (lower.contains('peanut') || lower.contains('nut')) return '🥜';
    if (lower.contains('chocolate')) return '🍫';
    if (lower.contains('corn') || lower.contains('maize')) return '🌽';
    if (lower.contains('barley')) return '🌾';

    // Category-based fallback
    switch (category) {
      case 'Protein':
        return '🥩';
      case 'Dairy':
        return '🥛';
      case 'Staples':
        return '🌾';
      case 'Vegetables':
        return '🥬';
      case 'Fruits':
        return '🍎';
      default:
        return '🍽️';
    }
  }
}

class Substitution {
  final FoodItem original;
  final FoodItem replacement;
  final String reason;
  final double carbonSaved;
  final double costSaved;

  Substitution({
    required this.original,
    required this.replacement,
    required this.reason,
    required this.carbonSaved,
    required this.costSaved,
  });
}
