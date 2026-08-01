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

  // ---------------------------------------------------------------------------
  // Display thresholds.
  //
  // Score deltas below _noiseBand are not movement, they are rounding. Anything
  // inside the band is reported as "no change" rather than being rounded to zero
  // and then labelled as an improvement, which is what produced "+0 pts /
  // Improved" in earlier builds.
  // ---------------------------------------------------------------------------
  static const double _noiseBand = 0.5;

  // The celebratory headline needs a clearly positive composite result, not a
  // marginal one, so it uses a wider band than the individual cards.
  static const double _headlineBand = 1.0;

  // The SPI pipeline returns exactly 0.500 for commodities with no free stock
  // series published in the AHDB balance sheets (oats is the standing example).
  // That is a missing value, not a measured neutral reading, and it is rendered
  // as such.
  static const double _neutralPressure = 0.5;
  static const double _neutralEpsilon = 0.001;

  // Average supply stability at or above this reads as a genuine tilt towards
  // steadier supply. Below it, the figure is reported without the claim.
  static const double _supplyClaimThreshold = 0.60;

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

  // ---------------------------------------------------------------------------
  // Formatting helpers.
  //
  // _fmtDelta applies the sign exactly once. Never concatenate a '+' or '-' onto
  // its output; that is what produced "+-1pts".
  // ---------------------------------------------------------------------------

  String _fmtDelta(double v) {
    if (v.abs() < _noiseBand) return '0';
    return '${v > 0 ? '+' : '-'}${v.abs().toStringAsFixed(0)}';
  }

  /// Status word chosen by the sign of the delta, so a card can never label a
  /// regression as an improvement.
  String _statusFor(double v, {required String up, required String down}) {
    if (v.abs() < _noiseBand) return 'No change';
    return v > 0 ? up : down;
  }

  bool _isGood(double v) => v >= _noiseBand;

  bool _isNoData(double pressure) =>
      (pressure - _neutralPressure).abs() < _neutralEpsilon;

  String _titleCase(String raw) {
    final cleaned = raw.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return cleaned;
    return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }

  // Convenience getters — map API score deltas to display values
  ApiBasketComparison get _comp => widget.result.comparison;

  // env and cost: positive delta = improvement (scores are 0-100, lower better)
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

  String get _heroHeadline {
    if (_basketGain >= _headlineBand) return 'Great Choices!';
    if (_basketGain <= -_headlineBand) return 'Mixed Result';
    return 'Broadly Even';
  }

  String get _heroSubtitle {
    if (_basketGain >= _headlineBand) {
      return "Here's how your optimised basket compares";
    }
    if (_basketGain <= -_headlineBand) {
      return 'Some dimensions improved, others gave ground';
    }
    return 'Your optimised basket scores about the same overall';
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
              if (_visibleInsights.isNotEmpty) ...[
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
            child: Text(
              _basketGain >= _headlineBand ? '🏆' : '📊',
              style: const TextStyle(fontSize: 36),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _heroHeadline,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _heroSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _heroMetric(
                '${_fmtDelta(_envReduction)}pts',
                'Carbon\nReduction',
                '🌍',
              ),
              const SizedBox(width: 8),
              _heroMetric(
                '${_fmtDelta(_costReduction)}pts',
                'Cost\nChange',
                '💰',
              ),
              const SizedBox(width: 8),
              _heroMetric(
                '${_fmtDelta(_nutritionGain)}pts',
                'Nutrition\nChange',
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
  //
  // Commodities with no published free stock series return exactly 0.500 from
  // the pipeline. Those are shown as "No data" rather than as a mid-range
  // pressure reading, so the chart never presents an absent series as a
  // measurement.
  // ---------------------------------------------------------------------------

  Widget _buildSupplyIntelligence() {
    final sp = widget.result.supplyPressure!;

    // Combine grain and category pressures, keep the tightest few to show.
    // Rows with real readings sort ahead of no-data rows, so the visible
    // selection is not crowded out by placeholders.
    final entries = <MapEntry<String, double>>[
      ...sp.grainPressure.entries,
      ...sp.foodCategoryPressure.entries,
    ]..sort((a, b) {
        final aNoData = _isNoData(a.value);
        final bNoData = _isNoData(b.value);
        if (aNoData != bNoData) return aNoData ? 1 : -1;
        return b.value.compareTo(a.value); // highest pressure first
      });

    final topPressures = entries.take(4).toList();
    final hasNoDataRow = topPressures.any((e) => _isNoData(e.value));
    final swaps = widget.result.substitutions.length;
    final avgPct = (_avgSupplyStability * 100).toStringAsFixed(0);

    final String summaryLine;
    if (swaps == 0) {
      summaryLine =
          'Live UK supply conditions, read from 25 years of AHDB balance-sheet data.';
    } else if (_avgSupplyStability >= _supplyClaimThreshold) {
      summaryLine =
          'Your swaps favour foods with steadier UK supply. Average supply '
          'stability across your $swaps ${swaps == 1 ? "swap" : "swaps"}: $avgPct%.';
    } else {
      summaryLine =
          'Average supply stability across your $swaps '
          '${swaps == 1 ? "swap" : "swaps"}: $avgPct%. Higher means steadier '
          'UK supply behind the foods you are moving to.';
    }

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
                  summaryLine,
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
          if (hasNoDataRow) ...[
            const SizedBox(height: 6),
            const Text(
              'No data: the AHDB balance sheets publish no free stock series '
              'for this commodity, so the optimiser treats it neutrally rather '
              'than penalising it.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _supplyPressureRow(String label, double value) {
    final noData = _isNoData(value);

    final Color color = noData
        ? AppColors.textTertiary
        : (value > 0.7
            ? AppColors.error
            : (value > 0.4 ? AppColors.warning : AppColors.success));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              _titleCase(label),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: noData ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                // A missing series has no magnitude, so the bar reads empty
                // rather than sitting at the halfway mark.
                value: noData ? 0.0 : value.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              noData ? 'No data' : '${(value * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: noData ? 10 : 12,
                fontWeight: noData ? FontWeight.w600 : FontWeight.w700,
                fontStyle: noData ? FontStyle.italic : FontStyle.normal,
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
          value: _fmtDelta(_envReduction),
          unit: 'pts',
          hugeIcon: HugeIcons.strokeRoundedCloud,
          color: AppColors.carbonColor,
          changeText: _statusFor(_envReduction, up: 'Improved', down: 'Worse'),
          isPositive: _isGood(_envReduction),
        ),
        MetricCard(
          label: 'Cost Score',
          value: _fmtDelta(_costReduction),
          unit: 'pts',
          hugeIcon: HugeIcons.strokeRoundedPiggyBank,
          color: AppColors.costColor,
          changeText: _statusFor(_costReduction, up: 'Cheaper', down: 'Pricier'),
          isPositive: _isGood(_costReduction),
        ),
        MetricCard(
          label: 'Nutrition',
          value: _fmtDelta(_nutritionGain),
          unit: 'pts',
          hugeIcon: HugeIcons.strokeRoundedOrganicFood,
          color: AppColors.nutritionColor,
          changeText:
              _statusFor(_nutritionGain, up: 'Improved', down: 'Reduced'),
          isPositive: _isGood(_nutritionGain),
        ),
        MetricCard(
          label: 'Overall Score',
          value: _fmtDelta(_basketGain),
          unit: 'pts',
          hugeIcon: HugeIcons.strokeRoundedAnalyticsUp,
          color: AppColors.success,
          changeText:
              '${widget.result.substitutions.length} supply-ranked swaps',
          isPositive: _isGood(_basketGain),
        ),
      ],
    );
  }

  Widget _buildAnnualProjections() {
    // Project score movements into a weekly narrative. Direction words are
    // derived from the sign, never assumed, so a basket that got more expensive
    // is not described as cheaper.
    final swaps = widget.result.substitutions.length;

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
            _weeklyLine(_envReduction, better: 'better', worse: 'worse'),
            _envReduction.abs() < _noiseBand
                ? 'Carbon load is broadly unchanged by these swaps'
                : 'Consistent swaps compound over time',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _projectionRow(
            '💰',
            'Cost impact',
            _weeklyLine(_costReduction,
                better: 'cheaper', worse: 'more expensive'),
            'Aldi prices factored in across $swaps ${swaps == 1 ? "swap" : "swaps"}',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _projectionRow(
            '💪',
            'Nutrition impact',
            _weeklyLine(_nutritionGain, better: 'better', worse: 'weaker'),
            _nutritionGain.abs() < _noiseBand
                ? 'Protein and fibre balance holds steady'
                : 'Driven by protein and fibre density in the new items',
          ),
          if (widget.result.substitutions.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.divider),
            _projectionRow(
              '🌾',
              'Supply resilience',
              '${(_avgSupplyStability * 100).toStringAsFixed(0)}% average stability',
              'Supply stability carries a fixed 0.15 weight in every ranking',
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a weekly projection line whose direction word follows the sign of
  /// the delta, and which says nothing when the delta is inside the noise band.
  String _weeklyLine(double delta, {required String better, required String worse}) {
    if (delta.abs() < _noiseBand) return 'Broadly unchanged per week';
    final magnitude = delta.abs().toStringAsFixed(0);
    return '$magnitude pts ${delta > 0 ? better : worse} per week';
  }

  // ---------------------------------------------------------------------------
  // Insights.
  //
  // The API occasionally emits an insight for a dimension that did not actually
  // move ("Nutrition score up 0 pts"). Those assert a benefit the number does
  // not support, so they are dropped rather than displayed. The real fix is on
  // the backend generator; this is the client-side guard.
  // ---------------------------------------------------------------------------

  static final RegExp _zeroChangeInsight =
      RegExp(r'\b(?:by|up|down)\s+0(?:\.0+)?\s*pts?\b', caseSensitive: false);

  List<String> get _visibleInsights => widget.result.insights
      .where((i) => !_zeroChangeInsight.hasMatch(i))
      .toList();

  List<Widget> _buildInsights() {
    return _visibleInsights.map((insight) {
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
            children: const [
              Expanded(
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
                  style: TextStyle(
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
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
    if (lower.contains('pork')) return '🥓';
    if (lower.contains('salmon') || lower.contains('tuna')) return '🐟';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('yoghurt') || lower.contains('yogurt')) return '🥄';
    if (lower.contains('cheese')) return '🧀';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('lentil') ||
        lower.contains('bean') ||
        lower.contains('chickpea')) {
      return '🫘';
    }
    if (lower.contains('tofu')) return '🫘';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('flour')) return '🌾';
    if (lower.contains('rice')) return '🍚';
    if (lower.contains('oat')) return '🥣';
    if (lower.contains('maize') || lower.contains('corn')) return '🌽';
    if (lower.contains('apple')) return '🍎';
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('broccoli')) return '🥦';
    if (lower.contains('sprout')) return '🥬';
    if (lower.contains('carrot')) return '🥕';
    if (lower.contains('spinach') || lower.contains('lettuce')) return '🥬';
    return '🍽️';
  }
}
