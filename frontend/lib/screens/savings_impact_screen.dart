import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/adaptive_widgets.dart';
import 'swap_detail_screen.dart';

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
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Convenience getters — map API score deltas to display values
  ApiBasketComparison get _comp => widget.result.comparison;

  // env and cost: higher delta = bigger improvement (scores are 0-100)
  double get _envReduction => _comp.envReduction;         // score pts saved
  double get _costReduction => _comp.costReduction;       // score pts saved
  double get _nutritionGain => _comp.nutritionGain;       // score pts gained
  double get _basketGain   => _comp.basketScoreGain;      // composite pts

  // Average supply stability across the swaps, expressed 0-1.
  // Every substitution carries a supply_stability field from the SPI
  // pipeline; the mean is the headline supply-resilience figure.
  double get _avgSupplyStability {
    final subs = widget.result.substitutions;
    if (subs.isEmpty) return 0;
    final total = subs.fold<double>(0, (sum, s) => sum + s.supplyStability);
    return total / subs.length;
  }

  bool get _hasSupplyData {
    final sp = widget.result.supplyPressure;
    if (sp == null) return false;
    return sp.grainPressure.isNotEmpty || sp.foodCategoryPressure.isNotEmpty;
  }

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
              // Supply intelligence sits directly under the hero, before
              // the conventional cost/carbon/nutrition breakdown, because
              // it is the distinguishing dimension of the product.
              if (_hasSupplyData) ...[
                const SectionHeader(
                  title: 'UK Supply Intelligence',
                  subtitle: 'Why these swaps hold up against supply pressure',
                ),
                _buildSupplyIntelligence(),
                const SizedBox(height: 24),
              ],
              const SectionHeader(
                title: 'Your Improvement Breakdown',
                subtitle: 'Score changes across every dimension',
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
                  subtitle: 'Ranked by the supply-aware optimiser',
                ),
                ...widget.result.substitutions.take(3).map(
                  (s) => GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SwapDetailScreen(substitution: s),
                        ),
                      );
                    },
                    child: SubstitutionCard(
                      originalName: s.originalName,
                      originalEmoji: _emojiFor(s.originalName),
                      replacementName: s.substituteName,
                      replacementEmoji: _emojiFor(s.substituteName),
                      reason: s.rationale,
                      carbonSaved: s.envDelta,
                      costSaved: s.costDelta,
                      supplyStability: s.supplyStability,
                      realismScore: s.realismScore,
                      paretoRank: s.paretoRank,
                      isLowRealism: s.humanFlaggedLowRealism,
                    ),
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
              const SizedBox(width: 8),
              _heroMetric(
                '${_costReduction.toStringAsFixed(0)}pts',
                'Cost\nImprovement',
                '💰',
              ),
              const SizedBox(width: 8),
              _heroMetric(
                '+${_nutritionGain.toStringAsFixed(0)}pts',
                'Nutrition\nGain',
                '💪',
              ),
              if (widget.result.substitutions.isNotEmpty) ...[
                const SizedBox(width: 8),
                _heroMetric(
                  '${(_avgSupplyStability * 100).toStringAsFixed(0)}%',
                  'Supply\nStability',
                  '🌾',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String value, String label, String emoji) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UK Supply Intelligence — the distinguishing section. Surfaces the
  // Supply Pressure Index that feeds the optimiser: how tight current UK
  // supply is for the relevant grains and food categories, and the average
  // stability of the chosen swaps. All values come straight from the API's
  // supply_pressure_index and per-swap supply_stability fields.
  // ---------------------------------------------------------------------------

  Widget _buildSupplyIntelligence() {
    final sp = widget.result.supplyPressure!;

    // Combine grain and category pressures, keep the tightest few to show.
    final entries = <MapEntry<String, double>>[
      ...sp.grainPressure.entries,
      ...sp.foodCategoryPressure.entries,
    ]..sort((a, b) => b.value.compareTo(a.value)); // highest pressure first

    final topPressures = entries.take(4).toList();
    final swaps = widget.result.substitutions.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAnalytics01,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  swaps > 0
                      ? 'Your swaps favour foods with steadier UK supply. Average supply stability across your $swaps ${swaps == 1 ? "swap" : "swaps"}: ${(_avgSupplyStability * 100).toStringAsFixed(0)}%.'
                      : 'Live UK supply conditions, read from 25 years of AHDB balance-sheet data.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Current supply pressure',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          ...topPressures.map((e) => _supplyPressureRow(e.key, e.value)),
          const SizedBox(height: 6),
          Text(
            'Higher bars mean tighter current supply. The optimiser steers '
            'towards categories under less pressure. Data vintage ${sp.dataVintage}.',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplyPressureRow(String label, double value) {
    final Color color = value > 0.7
        ? AppColors.error
        : (value > 0.4 ? AppColors.warning : AppColors.success);
    final display = label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              display,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              '${(value * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
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
            'Aldi prices factored in across $swaps swaps',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _projectionRow(
            '💪',
            'Nutrition impact',
            '+${_nutritionGain.toStringAsFixed(0)} pts per week',
            'Better protein and fibre balance maintained',
          ),
          if (widget.result.substitutions.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.divider),
            _projectionRow(
              '🌾',
              'Supply resilience',
              '${(_avgSupplyStability * 100).toStringAsFixed(0)}% average stability',
              'Swaps weighted towards steadier UK supply',
            ),
          ],
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
        lower.contains('chickpea')) {
      return '🫘';
    }
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
