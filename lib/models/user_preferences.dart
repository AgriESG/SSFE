enum DietType { omnivore, vegetarian, vegan }

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
      case DietType.vegetarian:
        return 'Vegetarian';
      case DietType.vegan:
        return 'Vegan';
    }
  }

  String get budgetLabel {
    switch (budgetPreference) {
      case BudgetPreference.low:
        return 'Budget-friendly';
      case BudgetPreference.medium:
        return 'Moderate';
      case BudgetPreference.high:
        return 'Premium';
    }
  }

  String get sustainabilityLabel {
    switch (sustainabilityPriority) {
      case SustainabilityPriority.low:
        return 'Low';
      case SustainabilityPriority.medium:
        return 'Medium';
      case SustainabilityPriority.high:
        return 'High';
    }
  }

  String get nutritionGoalLabel {
    switch (nutritionGoal) {
      case NutritionGoal.balanced:
        return 'Balanced Diet';
      case NutritionGoal.highProtein:
        return 'High Protein';
      case NutritionGoal.lowCarb:
        return 'Low Carb';
      case NutritionGoal.highFibre:
        return 'High Fibre';
    }
  }
}
