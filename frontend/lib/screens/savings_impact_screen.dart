import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/adaptive_widgets.dart';
import 'onboarding_screen.dart';

class SavingsImpactScreen extends StatefulWidget {
  final ApiOptimisationResult result;

  const SavingsImpactScreen({super.key, required this.result});

  @override
  State<SavingsImpactScreen> createState() => _SavingsImpactScreenState();
}

class _SavingsImpactScreenState extends State<SavingsImpactScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _startOver() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  // Convenience getters — map API score deltas to display values
  ApiBasketComparison get _comp => widget.result.comparison;

  // env and cost: higher delta = bigger improvement (scores are 0-100)
  double get _envReduction => _comp.envReduction;         // score pts saved
  double get _costReduction => _comp.costReduction;       // score pts saved
  double get _nutritionGain => _comp.nutritionGain;       // score pts gained
  double get _basketGain   => _comp.basketScoreGain;      // composite pts

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Impact'),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroSavings(),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Your Improvement Breakdown',
                subtitle: 'Score changes across all three dimensions',
              ),
              _buildImprovementGrid(),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Annual Projections',
                subtitle: 'If you maintain these changes over a year',
              ),
              _buildAnnualProjections(),
              const SizedBox(height: 24),
              if (widget.result.substitutions.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Top Substitutions',
                  subtitle: 'Your most impactful swaps',
                ),
                ...widget.result.substitutions.take(3).map(
                  (s) => SubstitutionCard(
                    originalName: s.originalName,
                    originalEmoji: _emojiFor(s.originalName),
                    replacementName: s.substituteName,
                    replacementEmoji: _emojiFor(s.substituteName),
                    reason: s.rationale,
                    carbonSaved: s.envDelta,
                    costSaved: s.costDelta,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (widget.result.insights.isNotEmpty) ...[
                const SectionHeader(title: 'Sustainability Insights'),
                ..._buildInsights(),
                const SizedBox(height: 24),
              ],
              _buildSeasonalSuggestions(),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Before & After'),
              _buildBeforeAfterComparison(),
              const SizedBox(height: 28),
              AdaptiveButton(
                label: 'Start New Analysis',
                onPressed: _startOver,
                isFullWidth: true,
                hugeIcon: HugeIcons.strokeRoundedRefresh,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSavings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
        ),
        borderRadius: BorderRadius.circular(24),
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('🏆', style: TextStyle(fontSize: 36)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Great Choices!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Here's how your optimised basket compares",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _heroMetric(
                '${_envReduction.toStringAsFixed(0)}pts',
                'Carbon\nReduction',
                '🌍',
              ),
              const SizedBox(width: 10),
              _heroMetric(
                '${_costReduction.toStringAsFixed(0)}pts',
                'Cost\nImprovement',
                '💰',
              ),
              const SizedBox(width: 10),
              _heroMetric(
                '+${_nutritionGain.toStringAsFixed(0)}pts',
                'Nutrition\nGain',
                '💪',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String value, String label, String emoji) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovementGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        MetricCard(
          label: 'Environmental',
          value: _envReduction.toStringAsFixed(0),
          unit: 'pts',
          hugeIcon: HugeIcons.strokeRoundedCloud,
          color: AppColors.carbonColor,
          changeText: _envReduction > 0 ? 'Improved' : 'No change',
          isPositive: _envReduction > 0,
        ),
        MetricCard(
          label: 'Cost Score',
          value: _costReduction.toStringAsFixed(0),
          unit: 'pts',
          hugeIcon: HugeIcons.strokeRoundedPiggyBank,
          color: AppColors.costColor,
          changeText: _costReduction > 0 ? 'Cheaper' : 'Similar',
          isPositive: _costReduction > 0,
        ),
        MetricCard(
          label: 'Nutrition',
          value: '+${_nutritionGain.toStringAsFixed(0)}',
          unit: 'pts',
          hugeIcon: HugeIcons.strokeRoundedOrganicFood,
          color: AppColors.nutritionColor,
          changeText: _nutritionGain > 0 ? 'Improved' : 'Maintained',
          isPositive: _nutritionGain >= 0,
        ),
        MetricCard(
          label: 'Overall Score',
          value: _basketGain.toStringAsFixed(0),
          unit: 'pts',
          hugeIcon: HugeIcons.strokeRoundedAnalyticsUp,
          color: AppColors.success,
          changeText: '${widget.result.substitutions.length} swaps',
          isPositive: _basketGain > 0,
        ),
      ],
    );
  }

  Widget _buildAnnualProjections() {
    // Project score improvements into weekly/yearly narrative
    final swaps = widget.result.substitutions.length;
    final envWeekly = _envReduction;
    final costWeekly = _costReduction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          _projectionRow(
            '🌍',
            'Carbon impact',
            '${envWeekly.toStringAsFixed(0)} pts better per week',
            'Consistent swaps compound over time',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _projectionRow(
            '💰',
            'Cost impact',
            '${costWeekly.toStringAsFixed(0)} pts cheaper per week',
            'Aldi prices factored in across ${swaps} swaps',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _projectionRow(
            '💪',
            'Nutrition impact',
            '+${_nutritionGain.toStringAsFixed(0)} pts per week',
            'Better protein and fibre balance maintained',
          ),
        ],
      ),
    );
  }

  Widget _projectionRow(
    String emoji,
    String title,
    String value,
    String context,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildInsights() {
    return widget.result.insights.map((insight) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          insight,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.45,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSeasonalSuggestions() {
    final seasonal = widget.result.optimisedBasket
        .where((i) => i.isSeasonal || i.isLocal)
        .toList();
    if (seasonal.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Seasonal & Local Picks',
          subtitle: 'Support UK farmers and reduce food miles',
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: seasonal.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.seasonalNote != null)
                            Text(
                              item.seasonalNote!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.isSeasonal)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Text(
                              '🌿',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        if (item.isLocal)
                          const Text('📍', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBeforeAfterComparison() {
    final before = _comp.before;
    final after = _comp.after;

    bool improved(double b, double a) => a < b; // lower score = better

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
              const Expanded(
                flex: 2,
                child: Text(
                  'Metric',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Before',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'After',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.divider),
          _comparisonRow(
            'Basket score',
            before.basketScore.toStringAsFixed(1),
            after.basketScore.toStringAsFixed(1),
            improved(before.basketScore, after.basketScore),
          ),
          _comparisonRow(
            'Env score',
            before.avgEnvScore.toStringAsFixed(1),
            after.avgEnvScore.toStringAsFixed(1),
            improved(before.avgEnvScore, after.avgEnvScore),
          ),
          _comparisonRow(
            'Cost score',
            before.avgCostScore.toStringAsFixed(1),
            after.avgCostScore.toStringAsFixed(1),
            improved(before.avgCostScore, after.avgCostScore),
          ),
          _comparisonRow(
            'Nutrition score',
            before.avgNutritionScore.toStringAsFixed(1),
            after.avgNutritionScore.toStringAsFixed(1),
            after.avgNutritionScore >= before.avgNutritionScore,
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow(
    String label,
    String before,
    String after,
    bool isGood,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              before,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              after,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isGood ? AppColors.success : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _emojiFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('chicken')) return '🍗';
    if (lower.contains('beef')) return '🥩';
    if (lower.contains('salmon') || lower.contains('tuna')) return '🐟';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('yoghurt') || lower.contains('yogurt')) return '🥄';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('lentil') ||
        lower.contains('bean') ||
        lower.contains('chickpea')) return '🫘';
    if (lower.contains('tofu')) return '🫘';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('rice')) return '🍚';
    if (lower.contains('oat')) return '🥣';
    if (lower.contains('apple')) return '🍎';
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('broccoli')) return '🥦';
    if (lower.contains('carrot')) return '🥕';
    if (lower.contains('spinach')) return '🥬';
    return '🍽️';
  }
}
