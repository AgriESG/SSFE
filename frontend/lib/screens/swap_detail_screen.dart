import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/food_item.dart';
import '../widgets/adaptive_widgets.dart';

class SwapDetailScreen extends StatefulWidget {
  final ApiSubstitution substitution;

  const SwapDetailScreen({super.key, required this.substitution});

  @override
  State<SwapDetailScreen> createState() => _SwapDetailScreenState();
}

class _SwapDetailScreenState extends State<SwapDetailScreen>
    with SingleTickerProviderStateMixin {
  FoodItem? _original;
  FoodItem? _substitute;
  bool _isLoading = true;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  ApiSubstitution get sub => widget.substitution;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _loadDetails();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    try {
      final results = await Future.wait([
        ApiService.getFood(sub.originalId),
        ApiService.getFood(sub.substituteId),
      ]);
      if (mounted) {
        setState(() {
          _original = results[0];
          _substitute = results[1];
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load item details.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap Details'),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : FadeTransition(opacity: _fadeAnim, child: _buildContent()),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading comparison...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            AdaptiveButton(
              label: 'Retry',
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadDetails();
              },
              isFullWidth: false,
              hugeIcon: HugeIcons.strokeRoundedRefresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final orig = _original!;
    final swap = _substitute!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSwapBanner(orig, swap),
          const SizedBox(height: 24),

          _buildRationaleCard(),
          const SizedBox(height: 24),

          const SectionHeader(
            title: 'Carbon Footprint',
            subtitle: 'CO₂ emissions per kilogram',
          ),
          _buildComparisonBar(
            'Carbon',
            '${orig.carbonPerKg.toStringAsFixed(2)} kg CO₂/kg',
            '${swap.carbonPerKg.toStringAsFixed(2)} kg CO₂/kg',
            orig.carbonPerKg,
            swap.carbonPerKg,
            AppColors.carbonColor,
            lowerIsBetter: true,
          ),
          const SizedBox(height: 20),

          const SectionHeader(
            title: 'Cost',
            subtitle: 'Price per kilogram',
          ),
          _buildComparisonBar(
            'Price',
            '£${orig.pricePerKg.toStringAsFixed(2)}/kg',
            '£${swap.pricePerKg.toStringAsFixed(2)}/kg',
            orig.pricePerKg,
            swap.pricePerKg,
            AppColors.costColor,
            lowerIsBetter: true,
          ),
          const SizedBox(height: 20),

          const SectionHeader(
            title: 'Nutrition',
            subtitle: 'Macros per kilogram',
          ),
          _buildNutritionComparison(orig, swap),
          const SizedBox(height: 24),

          const SectionHeader(
            title: 'Environmental Details',
            subtitle: 'Water and land impact',
          ),
          _buildEnvDetails(orig, swap),
          const SizedBox(height: 24),

          _buildScoreCard(),
          const SizedBox(height: 24),

          AdaptiveButton(
            label: 'Accept This Swap',
            onPressed: () => Navigator.pop(context, true),
            isFullWidth: true,
            hugeIcon: HugeIcons.strokeRoundedTick02,
          ),
          const SizedBox(height: 8),
          AdaptiveButton(
            label: 'Keep Original',
            onPressed: () => Navigator.pop(context, false),
            isFullWidth: true,
            isPrimary: false,
            hugeIcon: HugeIcons.strokeRoundedCancel01,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSwapBanner(FoodItem orig, FoodItem swap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(orig.emoji, style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      orig.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Original',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(swap.emoji, style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      swap.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Suggested',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRationaleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedIdea,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Why This Swap?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sub.rationale.isNotEmpty
                ? sub.rationale
                : 'This substitution improves your basket\'s overall sustainability, '
                    'cost, and nutrition profile.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar(
    String label,
    String origLabel,
    String swapLabel,
    double origValue,
    double swapValue,
    Color color, {
    bool lowerIsBetter = false,
  }) {
    final maxVal = [origValue, swapValue, 0.01].reduce((a, b) => a > b ? a : b);
    final origRatio = origValue / maxVal;
    final swapRatio = swapValue / maxVal;
    final swapBetter = lowerIsBetter
        ? swapValue < origValue
        : swapValue > origValue;
    final diff = ((origValue - swapValue).abs());
    final pct = origValue > 0
        ? (diff / origValue * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  'Original',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: ImpactProgressBar(
                  progress: origRatio,
                  color: !swapBetter ? AppColors.success : color.withValues(alpha: 0.6),
                  height: 8,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: Text(
                  origLabel,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  'Swap',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: swapBetter ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: ImpactProgressBar(
                  progress: swapRatio,
                  color: swapBetter ? AppColors.success : color.withValues(alpha: 0.6),
                  height: 8,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: Text(
                  swapLabel,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: swapBetter ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (swapBetter)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '✓ $pct% ${lowerIsBetter ? "lower" : "higher"} with the swap',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNutritionComparison(FoodItem orig, FoodItem swap) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _nutritionRow('Protein', orig.proteinPerKg, swap.proteinPerKg, 'g/kg'),
          const Divider(height: 16, color: AppColors.divider),
          _nutritionRow('Calories', orig.caloriesPerKg, swap.caloriesPerKg, 'kcal/kg'),
          const Divider(height: 16, color: AppColors.divider),
          _nutritionRow('Fibre', orig.fibrePerKg, swap.fibrePerKg, 'g/kg'),
        ],
      ),
    );
  }

  Widget _nutritionRow(String label, double orig, double swap, String unit) {
    final diff = swap - orig;
    final isPositive = diff >= 0;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${orig.toStringAsFixed(0)} $unit',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${swap.toStringAsFixed(0)} $unit',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPositive ? AppColors.success : AppColors.error,
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${isPositive ? "+" : ""}${diff.toStringAsFixed(0)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isPositive ? AppColors.success : AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnvDetails(FoodItem orig, FoodItem swap) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _envRow(
            '💧',
            'Water Usage',
            '${orig.waterPerKg.toStringAsFixed(0)} L/kg',
            '${swap.waterPerKg.toStringAsFixed(0)} L/kg',
            swap.waterPerKg < orig.waterPerKg,
          ),
          const Divider(height: 16, color: AppColors.divider),
          _envRow(
            '🌍',
            'Land Use',
            '${orig.landPerKg.toStringAsFixed(1)} m²/kg',
            '${swap.landPerKg.toStringAsFixed(1)} m²/kg',
            swap.landPerKg < orig.landPerKg,
          ),
        ],
      ),
    );
  }

  Widget _envRow(
    String emoji,
    String label,
    String origValue,
    String swapValue,
    bool improved,
  ) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            origValue,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            swapValue,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: improved ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: improved
              ? HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  color: AppColors.success,
                  size: 16,
                )
              : HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowUp01,
                  color: AppColors.error,
                  size: 16,
                ),
        ),
      ],
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Score Improvements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _scoreRow(
            'Overall',
            sub.improvementScore,
            HugeIcons.strokeRoundedAnalyticsUp,
          ),
          const SizedBox(height: 8),
          _scoreRow(
            'Environmental',
            sub.envDelta,
            HugeIcons.strokeRoundedCloud,
          ),
          const SizedBox(height: 8),
          _scoreRow(
            'Cost',
            sub.costDelta,
            HugeIcons.strokeRoundedCoinsPound,
          ),
          const SizedBox(height: 8),
          _scoreRow(
            'Nutrition',
            sub.nutritionDelta,
            HugeIcons.strokeRoundedOrganicFood,
          ),
        ],
      ),
    );
  }

  Widget _scoreRow(
    String label,
    double delta,
    List<List<dynamic>> icon,
  ) {
    final isPositive = delta >= 0;
    return Row(
      children: [
        HugeIcon(
          icon: icon,
          color: isPositive ? AppColors.success : AppColors.error,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isPositive ? AppColors.success : AppColors.error)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${isPositive ? "+" : ""}${delta.toStringAsFixed(1)} pts',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isPositive ? AppColors.success : AppColors.error,
            ),
          ),
        ),
      ],
    );
  }
}
