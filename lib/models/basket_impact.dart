class BasketImpact {
  final double totalCarbon; // kg CO2e
  final double totalWater; // litres
  final double totalLand; // m²
  final double totalCost; // £
  final double totalProtein; // g
  final double totalCalories; // kcal
  final double totalFibre; // g

  const BasketImpact({
    required this.totalCarbon,
    required this.totalWater,
    required this.totalLand,
    required this.totalCost,
    required this.totalProtein,
    required this.totalCalories,
    required this.totalFibre,
  });

  BasketImpact difference(BasketImpact other) {
    return BasketImpact(
      totalCarbon: totalCarbon - other.totalCarbon,
      totalWater: totalWater - other.totalWater,
      totalLand: totalLand - other.totalLand,
      totalCost: totalCost - other.totalCost,
      totalProtein: totalProtein - other.totalProtein,
      totalCalories: totalCalories - other.totalCalories,
      totalFibre: totalFibre - other.totalFibre,
    );
  }

  double percentChange(double original, double optimised) {
    if (original == 0) return 0;
    return ((optimised - original) / original) * 100;
  }

  double get carbonPercent => 0;
  double get waterPercent => 0;
  double get costPercent => 0;
  double get proteinPercent => 0;
}

class ImpactComparison {
  final BasketImpact original;
  final BasketImpact optimised;

  const ImpactComparison({
    required this.original,
    required this.optimised,
  });

  double get carbonChange =>
      _percentChange(original.totalCarbon, optimised.totalCarbon);
  double get waterChange =>
      _percentChange(original.totalWater, optimised.totalWater);
  double get landChange =>
      _percentChange(original.totalLand, optimised.totalLand);
  double get costChange =>
      _percentChange(original.totalCost, optimised.totalCost);
  double get proteinChange =>
      _percentChange(original.totalProtein, optimised.totalProtein);
  double get caloriesChange =>
      _percentChange(original.totalCalories, optimised.totalCalories);
  double get fibreChange =>
      _percentChange(original.totalFibre, optimised.totalFibre);

  double get costSaved => original.totalCost - optimised.totalCost;
  double get carbonSaved => original.totalCarbon - optimised.totalCarbon;
  double get waterSaved => original.totalWater - optimised.totalWater;

  double _percentChange(double original, double optimised) {
    if (original == 0) return 0;
    return ((optimised - original) / original) * 100;
  }
}
