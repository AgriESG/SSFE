enum DietType {
  omnivore,
  pescatarian,
  vegetarian,
  vegan,
}

enum BudgetPreference { low, medium, high }

enum SustainabilityPriority { low, medium, high }

enum NutritionGoal { balanced, highProtein, lowCarb, highFibre }

class UserPreferences {
  DietType dietType;
  List<String> allergies;
  List<String> dislikes;
  BudgetPreference budgetPreference;
  SustainabilityPriority sustainabilityPriority;
  NutritionGoal nutritionGoal;
  int householdSize;

  UserPreferences({
    this.dietType = DietType.omnivore,
    List<String>? allergies,
    List<String>? dislikes,
    this.budgetPreference = BudgetPreference.medium,
    this.sustainabilityPriority = SustainabilityPriority.medium,
    this.nutritionGoal = NutritionGoal.balanced,
    this.householdSize = 2,
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
}