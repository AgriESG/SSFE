enum DietType {
  omnivore,
  pescatarian,
  vegetarian,
  vegan,
}

enum BudgetPreference { low, medium, high }

enum SustainabilityPriority { low, medium, high }

enum NutritionGoal { balanced, highProtein, lowCarb, highFibre }

/// How much depth the app surfaces for agricultural/optimiser data —
/// UK supply pressure, crop provenance, Pareto ranking, and weighting.
/// Simple shows a headline reading; detailed shows the full breakdown.
enum DetailLevel { simple, detailed }

class UserPreferences {
  DietType dietType;
  List<String> allergies;
  List<String> dislikes;
  BudgetPreference budgetPreference;
  SustainabilityPriority sustainabilityPriority;
  NutritionGoal nutritionGoal;
  int householdSize;
  DetailLevel detailLevel;

  UserPreferences({
    this.dietType = DietType.omnivore,
    List<String>? allergies,
    List<String>? dislikes,
    this.budgetPreference = BudgetPreference.medium,
    this.sustainabilityPriority = SustainabilityPriority.medium,
    this.nutritionGoal = NutritionGoal.balanced,
    this.householdSize = 2,
    this.detailLevel = DetailLevel.simple,
  })  : allergies = allergies ?? [],
        dislikes = dislikes ?? [];

  String get dietTypeLabel {
    switch (dietType) {
      case DietType.omnivore:
        return 'Omnivore';
      case DietType.pescatarian:
        return 'Pescatarian';
      case DietType.vegetarian:
        return 'Vegetarian';
      case DietType.vegan:
        return 'Vegan';
    }
  }

  /// ✅ UPDATED — Intent-based labels
  String get budgetLabel {
    switch (budgetPreference) {
      case BudgetPreference.low:
        return 'Save Money';
      case BudgetPreference.medium:
        return 'Balanced Spend';
      case BudgetPreference.high:
        return 'Premium Quality';
    }
  }

  /// ✅ UPDATED — Clear priority meaning
  String get sustainabilityLabel {
    switch (sustainabilityPriority) {
      case SustainabilityPriority.low:
        return 'Not Important';
      case SustainabilityPriority.medium:
        return 'Balanced';
      case SustainabilityPriority.high:
        return 'Highly Important';
    }
  }

  /// ✅ UPDATED — Cleaner wording
  String get nutritionGoalLabel {
    switch (nutritionGoal) {
      case NutritionGoal.balanced:
        return 'Balanced';
      case NutritionGoal.highProtein:
        return 'High Protein';
      case NutritionGoal.lowCarb:
        return 'Low Carb';
      case NutritionGoal.highFibre:
        return 'High Fibre';
    }
  }

  String get detailLevelLabel {
    switch (detailLevel) {
      case DetailLevel.simple:
        return 'Simple';
      case DetailLevel.detailed:
        return 'Detailed';
    }
  }

  Map<String, dynamic> toJson() => {
        'dietType': dietType.name,
        'allergies': allergies,
        'dislikes': dislikes,
        'budgetPreference': budgetPreference.name,
        'sustainabilityPriority': sustainabilityPriority.name,
        'nutritionGoal': nutritionGoal.name,
        'householdSize': householdSize,
        'detailLevel': detailLevel.name,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> j) => UserPreferences(
        dietType: DietType.values.firstWhere(
          (v) => v.name == j['dietType'],
          orElse: () => DietType.omnivore,
        ),
        allergies: (j['allergies'] as List? ?? []).map((e) => e.toString()).toList(),
        dislikes: (j['dislikes'] as List? ?? []).map((e) => e.toString()).toList(),
        budgetPreference: BudgetPreference.values.firstWhere(
          (v) => v.name == j['budgetPreference'],
          orElse: () => BudgetPreference.medium,
        ),
        sustainabilityPriority: SustainabilityPriority.values.firstWhere(
          (v) => v.name == j['sustainabilityPriority'],
          orElse: () => SustainabilityPriority.medium,
        ),
        nutritionGoal: NutritionGoal.values.firstWhere(
          (v) => v.name == j['nutritionGoal'],
          orElse: () => NutritionGoal.balanced,
        ),
        householdSize: (j['householdSize'] as num?)?.toInt() ?? 2,
        detailLevel: DetailLevel.values.firstWhere(
          (v) => v.name == j['detailLevel'],
          orElse: () => DetailLevel.simple,
        ),
      );
}