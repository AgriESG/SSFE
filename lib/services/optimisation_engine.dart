import '../models/food_item.dart';
import '../models/user_preferences.dart';
import '../models/basket_impact.dart';
import 'food_database.dart';

class OptimisationEngine {
  /// Calculate the total impact of a basket of food items
  static BasketImpact calculateImpact(List<FoodItem> basket) {
    double totalCarbon = 0;
    double totalWater = 0;
    double totalLand = 0;
    double totalCost = 0;
    double totalProtein = 0;
    double totalCalories = 0;
    double totalFibre = 0;

    for (final item in basket) {
      totalCarbon += item.totalCarbon;
      totalWater += item.totalWater;
      totalLand += item.totalLand;
      totalCost += item.totalPrice;
      totalProtein += item.totalProtein;
      totalCalories += item.totalCalories;
      totalFibre += item.totalFibre;
    }

    return BasketImpact(
      totalCarbon: totalCarbon,
      totalWater: totalWater,
      totalLand: totalLand,
      totalCost: totalCost,
      totalProtein: totalProtein,
      totalCalories: totalCalories,
      totalFibre: totalFibre,
    );
  }

  /// Optimise the basket based on user preferences
  static OptimisationResult optimise(
    List<FoodItem> originalBasket,
    UserPreferences preferences,
  ) {
    final List<FoodItem> optimisedBasket = [];
    final List<Substitution> substitutions = [];

    for (final item in originalBasket) {
      final substitution = _findBestSubstitution(item, preferences);
      if (substitution != null && substitution.replacement != null) {
        final rep = substitution.replacement!;
        optimisedBasket.add(rep.copyWith(quantity: item.quantity));
        substitutions.add(
          Substitution(
            original: item,
            replacement: rep.copyWith(quantity: item.quantity),
            reason: substitution.reason,
            carbonSaved: (item.carbonPerKg - rep.carbonPerKg) * item.quantity,
            costSaved: (item.pricePerKg - rep.pricePerKg) * item.quantity,
          ),
        );
      } else {
        optimisedBasket.add(item);
      }
    }

    final originalImpact = calculateImpact(originalBasket);
    final optimisedImpact = calculateImpact(optimisedBasket);
    final comparison = ImpactComparison(
      original: originalImpact,
      optimised: optimisedImpact,
    );

    return OptimisationResult(
      optimisedBasket: optimisedBasket,
      substitutions: substitutions,
      comparison: comparison,
      insights: _generateInsights(comparison, substitutions, preferences),
    );
  }

  static _SubstitutionCandidate? _findBestSubstitution(
    FoodItem item,
    UserPreferences preferences,
  ) {
    // Define substitution rules using the CSV-based IDs
    final Map<String, _SubstitutionCandidate> rules = {
      'beef_ground_': _SubstitutionCandidate(
        replacementId: preferences.dietType == DietType.vegan
            ? 'lentils'
            : preferences.dietType == DietType.vegetarian
            ? 'chickpeas'
            : 'chicken_breast',
        reason: preferences.dietType == DietType.omnivore
            ? 'Chicken has 90% lower carbon footprint than beef'
            : 'Plant-based protein with 98% lower carbon footprint',
      ),
      'chicken_breast': _SubstitutionCandidate(
        replacementId:
            preferences.sustainabilityPriority == SustainabilityPriority.high
            ? 'lentils'
            : preferences.dietType == DietType.vegan
            ? 'tofu'
            : 'chicken_breast',
        reason:
            'Seasonal legumes are high in protein with minimal carbon footprint',
      ),
      'pork_ground_': _SubstitutionCandidate(
        replacementId: preferences.dietType == DietType.vegan
            ? 'chickpeas'
            : 'chicken_ground_',
        reason: 'Lower-carbon protein alternative with similar versatility',
      ),
      'lamb': _SubstitutionCandidate(
        replacementId: preferences.dietType == DietType.vegan
            ? 'lentils'
            : 'chicken_breast',
        reason:
            'Lamb has a very high carbon footprint; switching saves significant CO₂',
      ),
      'rice_white_': _SubstitutionCandidate(
        replacementId: 'rice_brown_',
        reason:
            'Brown rice provides 3x more fibre with the same carbon footprint',
      ),
      'bread_white_': _SubstitutionCandidate(
        replacementId: 'bread_wholemeal_',
        reason:
            'Wholemeal bread offers more fibre and nutrients for the same impact',
      ),
      'milk': _SubstitutionCandidate(
        replacementId: preferences.dietType == DietType.vegan
            ? 'soy_milk'
            : 'milk',
        reason: 'Soy milk produces 69% less CO₂ than dairy milk',
      ),
      'cheddar_cheese': _SubstitutionCandidate(
        replacementId:
            preferences.sustainabilityPriority == SustainabilityPriority.high
            ? 'tofu'
            : 'cheddar_cheese',
        reason:
            'Cheese has a very high carbon footprint; tofu is a versatile alternative',
      ),
      'salmon': _SubstitutionCandidate(
        replacementId: preferences.budgetPreference == BudgetPreference.low
            ? 'lentils'
            : 'tuna',
        reason:
            'Tuna has a much lower calorie-to-carbon ratio at a fraction of the price',
      ),
      'dark_chocolate': _SubstitutionCandidate(
        replacementId: 'nuts',
        reason:
            'Dark chocolate has an extremely high carbon footprint; nuts are a healthier snack',
      ),
      'prawns': _SubstitutionCandidate(
        replacementId: 'tuna',
        reason:
            'Tuna has half the carbon footprint of prawns with more protein',
      ),
    };

    // Apply high sustainability overrides
    if (preferences.sustainabilityPriority == SustainabilityPriority.high) {
      if (item.id == 'milk') {
        rules['milk'] = _SubstitutionCandidate(
          replacementId: 'soy_milk',
          reason: 'Soy milk produces 69% less CO₂ than dairy milk',
        );
      }
      if (item.id == 'chicken_breast') {
        rules['chicken_breast'] = _SubstitutionCandidate(
          replacementId: 'lentils',
          reason: 'Lentils provide equivalent protein with 82% lower carbon',
        );
      }
    }

    final candidate = rules[item.id];
    if (candidate == null || candidate.replacementId == item.id) return null;

    final replacement = FoodDatabase.findById(candidate.replacementId);
    if (replacement == null) return null;

    // Check dietary constraints
    if (preferences.dietType == DietType.vegan &&
        (replacement.category == 'Dairy' ||
            replacement.category == 'Protein' && !_isPlantBased(replacement))) {
      return null;
    }

    // Check allergies
    for (final allergy in preferences.allergies) {
      if (replacement.name.toLowerCase().contains(allergy.toLowerCase())) {
        return null;
      }
    }

    // Check dislikes
    for (final dislike in preferences.dislikes) {
      if (replacement.name.toLowerCase().contains(dislike.toLowerCase())) {
        return null;
      }
    }

    return _SubstitutionCandidate(
      replacementId: candidate.replacementId,
      reason: candidate.reason,
      replacement: replacement,
    );
  }

  static bool _isPlantBased(FoodItem item) {
    final lower = item.name.toLowerCase();
    return lower.contains('lentil') ||
        lower.contains('chickpea') ||
        lower.contains('bean') ||
        lower.contains('tofu') ||
        lower.contains('soy') ||
        lower.contains('peanut') ||
        lower.contains('nut');
  }

  static List<String> _generateInsights(
    ImpactComparison comparison,
    List<Substitution> substitutions,
    UserPreferences preferences,
  ) {
    final List<String> insights = [];

    if (comparison.carbonSaved > 0) {
      insights.add(
        '🌱 You could save ${comparison.carbonSaved.toStringAsFixed(1)} kg CO₂ per week — '
        'that\'s equivalent to ${(comparison.carbonSaved * 52 / 1000).toStringAsFixed(1)} tonnes per year',
      );
    }

    if (comparison.costSaved > 0) {
      insights.add(
        '💰 Save £${comparison.costSaved.toStringAsFixed(0)} per week — '
        'that\'s £${(comparison.costSaved * 52).toStringAsFixed(0)} per year',
      );
    }

    if (comparison.waterSaved > 0) {
      insights.add(
        '💧 Save ${(comparison.waterSaved / 1000).toStringAsFixed(1)}k litres of water per week',
      );
    }

    final seasonalItems = substitutions
        .where((s) => s.replacement.isSeasonal || s.replacement.isLocal)
        .length;
    if (seasonalItems > 0) {
      insights.add(
        '🌿 $seasonalItems of your swaps are seasonal or locally sourced, '
        'supporting UK farmers and reducing food miles',
      );
    }

    if (preferences.nutritionGoal == NutritionGoal.highProtein) {
      insights.add(
        '💪 Your optimised basket maintains high protein while reducing environmental impact',
      );
    }

    if (comparison.fibreChange > 0) {
      insights.add(
        '🌾 Your fibre intake increases by ${comparison.fibreChange.abs().toStringAsFixed(0)}% '
        'with these swaps — great for gut health',
      );
    }

    if (insights.isEmpty) {
      insights.add(
        '✅ Your current basket is already well-optimised! Consider trying more seasonal produce.',
      );
    }

    return insights;
  }
}

class _SubstitutionCandidate {
  final String replacementId;
  final String reason;
  final FoodItem? replacement;

  _SubstitutionCandidate({
    required this.replacementId,
    required this.reason,
    this.replacement,
  });
}

class OptimisationResult {
  final List<FoodItem> optimisedBasket;
  final List<Substitution> substitutions;
  final ImpactComparison comparison;
  final List<String> insights;

  const OptimisationResult({
    required this.optimisedBasket,
    required this.substitutions,
    required this.comparison,
    required this.insights,
  });
}
