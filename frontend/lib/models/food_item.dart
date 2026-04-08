class FoodItem {
  final String id;
  final String name;
  final String category;
  final String role;
  final String emoji;
  final double carbonPerKg;
  final double waterPerKg;
  final double landPerKg;
  final double pricePerKg;
  final double proteinPerKg;
  final double caloriesPerKg;
  final double carbsPerKg;
  final double fatPerKg;
  final double fibrePerKg;
  final bool isSeasonal;
  final bool isLocal;
  final String? seasonalNote;
  double quantity;

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

  // ---------------------------------------------------------------------------
  // Computed totals
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // API factories — used when data comes from FastAPI backend
  // ---------------------------------------------------------------------------

  /// From /foods list endpoint: {food_id, food_name, category, role}
  /// Minimal data — no env/price/nutrition detail at list level.
  factory FoodItem.fromApiJson(Map<String, dynamic> j) {
    final name = (j['food_name'] ?? '') as String;
    final category = _normaliseCategory((j['category'] ?? '') as String);
    final role = (j['role'] ?? '') as String;
    return FoodItem(
      id: (j['food_id'] ?? '') as String,
      name: name,
      category: category,
      role: role,
      emoji: _emojiForCategory(category, name),
      carbonPerKg: 0,
      waterPerKg: 0,
      landPerKg: 0,
      pricePerKg: 0,
      proteinPerKg: 0,
      caloriesPerKg: 0,
      carbsPerKg: 0,
      fatPerKg: 0,
      fibrePerKg: 0,
    );
  }

  /// From /foods/{id} detail endpoint — full nutrition, env, price data.
  factory FoodItem.fromApiDetailJson(Map<String, dynamic> j) {
    final name = (j['food_name'] ?? '') as String;
    final category = _normaliseCategory(
      (j['category'] ?? j['role'] ?? '') as String,
    );
    final role = (j['role'] ?? '') as String;
    final nutrition = j['nutrition'] as Map<String, dynamic>? ?? {};
    final environmental = j['environmental'] as Map<String, dynamic>? ?? {};

    return FoodItem(
      id: (j['food_id'] ?? '') as String,
      name: name,
      category: category,
      role: role,
      emoji: _emojiForCategory(category, name),
      carbonPerKg: _d(environmental['carbon_kg_co2e']),
      waterPerKg: _d(environmental['water_litres']),
      landPerKg: _d(environmental['land_m2']),
      pricePerKg: _d(j['price_per_kg_gbp']),
      proteinPerKg: _d(nutrition['protein_g']),
      caloriesPerKg: _d(nutrition['calories']),
      carbsPerKg: 0, // not returned at detail level — extend API if needed
      fatPerKg: 0,
      fibrePerKg: _d(nutrition['fibre_g']),
      seasonalNote: j['seasonal_note'] as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // CSV factory — kept for any offline/fallback use
  // ---------------------------------------------------------------------------

  factory FoodItem.fromCsvRow(Map<String, String> row) {
    final name = row['Food_name'] ?? '';
    final category = _normaliseCategory((row['Category'] ?? '').trim());
    final role = (row['Role'] ?? '').trim();

    return FoodItem(
      id: _generateId(name),
      name: name,
      category: category,
      role: role,
      emoji: _emojiForCategory(category, name),
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static double _d(dynamic v) => v == null ? 0.0 : (v as num).toDouble();

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
      case 'dairy_alt':
      case 'dairy alternative':
        return 'Dairy';
      case 'staples':
      case 'carb':
        return 'Staples';
      case 'vegetables':
      case 'vegetable':
        return 'Vegetables';
      case 'fruits':
      case 'fruit':
        return 'Fruits';
      case 'snack':
        return 'Snacks';
      default:
        if (lower.isEmpty) return 'Other';
        return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
    }
  }

  static String _emojiForCategory(String category, String name) {
    final lower = name.toLowerCase();
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
    switch (category) {
      case 'Protein': return '🥩';
      case 'Dairy': return '🥛';
      case 'Staples': return '🌾';
      case 'Vegetables': return '🥬';
      case 'Fruits': return '🍎';
      case 'Snacks': return '🥜';
      default: return '🍽️';
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
