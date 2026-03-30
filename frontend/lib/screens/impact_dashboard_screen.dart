import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../models/food_item.dart';
import '../models/user_preferences.dart';
import '../models/basket_impact.dart';
import '../services/optimisation_engine.dart';
import '../widgets/adaptive_widgets.dart';
import 'optimised_basket_screen.dart';

class ImpactDashboardScreen extends StatefulWidget {
  final List<FoodItem> basket;
  final UserPreferences preferences;

  const ImpactDashboardScreen({
    super.key,
    required this.basket,
    required this.preferences,
  });

  @override
  State<ImpactDashboardScreen> createState() => _ImpactDashboardScreenState();
}

class _ImpactDashboardScreenState extends State<ImpactDashboardScreen>
    with SingleTickerProviderStateMixin {
  late BasketImpact _impact;
  bool _isCalculating = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);

    _impact = const BasketImpact(
      totalCarbon: 0, totalWater: 0, totalLand: 0,
      totalCost: 0, totalProtein: 0, totalCalories: 0, totalFibre: 0,
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _impact = OptimisationEngine.calculateImpact(widget.basket);
          _isCalculating = false;
        });
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateToOptimise() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OptimisedBasketScreen(
          originalBasket: widget.basket,
          preferences: widget.preferences,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impact Dashboard'),
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.primary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isCalculating ? _buildLoading() : _buildDashboard(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(icon: HugeIcons.strokeRoundedChartColumn, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 24),
          const Text('Analysing your basket...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Calculating environmental & nutritional impact', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            _buildHeroCard(),
            const SizedBox(height: 24),

            // Metric grid
            const SectionHeader(
              title: 'Environmental Impact',
              subtitle: 'Your basket\'s weekly footprint',
            ),
            _buildMetricGrid(),
            const SizedBox(height: 24),

            // Nutrition summary
            const SectionHeader(title: 'Nutrition Summary'),
            _buildNutritionSummary(),
            const SizedBox(height: 24),

            // Carbon breakdown
            const SectionHeader(
              title: 'Carbon Breakdown',
              subtitle: 'CO₂ contribution by item',
            ),
            _buildCarbonBreakdown(),
            const SizedBox(height: 24),

            // CTA
            AdaptiveButton(
              label: 'Optimise My Basket',
              onPressed: _navigateToOptimise,
              isFullWidth: true,
              hugeIcon: HugeIcons.strokeRoundedMagicWand01,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedShoppingBasket01, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          const Text('Your Weekly Basket', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroStat('${_impact.totalCarbon.toStringAsFixed(1)}', 'kg CO₂', HugeIcons.strokeRoundedCloud),
              const SizedBox(width: 12),
              _heroStat('£${_impact.totalCost.toStringAsFixed(0)}', 'total', HugeIcons.strokeRoundedCoinsPound),
              const SizedBox(width: 12),
              _heroStat('${widget.basket.length}', 'items', HugeIcons.strokeRoundedShoppingBasket01),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label, List<List<dynamic>> icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            HugeIcon(icon: icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        MetricCard(
          label: 'Carbon Footprint',
          value: _impact.totalCarbon.toStringAsFixed(1),
          unit: 'kg CO₂',
          hugeIcon: HugeIcons.strokeRoundedCloud,
          color: AppColors.carbonColor,
        ),
        MetricCard(
          label: 'Water Usage',
          value: (_impact.totalWater / 1000).toStringAsFixed(1),
          unit: 'k litres',
          hugeIcon: HugeIcons.strokeRoundedDroplet,
          color: AppColors.waterColor,
        ),
        MetricCard(
          label: 'Total Cost',
          value: '£${_impact.totalCost.toStringAsFixed(0)}',
          unit: '/week',
          hugeIcon: HugeIcons.strokeRoundedCoinsPound,
          color: AppColors.costColor,
        ),
        MetricCard(
          label: 'Land Use',
          value: _impact.totalLand.toStringAsFixed(1),
          unit: 'm²',
          hugeIcon: HugeIcons.strokeRoundedMountain,
          color: AppColors.landColor,
        ),
      ],
    );
  }

  Widget _buildNutritionSummary() {
    // Approximate daily recommended values (UK adults, per week)
    const weeklyProtein = 350.0;  // ~50g/day x 7
    const weeklyCalories = 14000.0;  // 2000/day x 7
    const weeklyFibre = 210.0;  // 30g/day x 7

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _nutritionRow('Protein', _impact.totalProtein, weeklyProtein, 'g', AppColors.primary),
          const SizedBox(height: 14),
          _nutritionRow('Calories', _impact.totalCalories, weeklyCalories, 'kcal', AppColors.warning),
          const SizedBox(height: 14),
          _nutritionRow('Fibre', _impact.totalFibre, weeklyFibre, 'g', AppColors.success),
        ],
      ),
    );
  }

  Widget _nutritionRow(String label, double value, double target, String unit, Color color) {
    final progress = (value / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text('${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ImpactProgressBar(progress: progress, color: color),
      ],
    );
  }

  Widget _buildCarbonBreakdown() {
    final sorted = List<FoodItem>.from(widget.basket)
      ..sort((a, b) => b.totalCarbon.compareTo(a.totalCarbon));
    final maxCarbon = sorted.isNotEmpty ? sorted.first.totalCarbon : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: sorted.take(8).map((item) {
          final ratio = item.totalCarbon / maxCarbon;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    Text('${item.totalCarbon.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                ImpactProgressBar(
                  progress: ratio,
                  color: ratio > 0.7 ? AppColors.error : ratio > 0.4 ? AppColors.warning : AppColors.success,
                  height: 4,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
