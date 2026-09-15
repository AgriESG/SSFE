import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/food_item.dart';
import '../models/user_preferences.dart';
import '../widgets/adaptive_widgets.dart';

class SwapDetailScreen extends StatefulWidget {
  final ApiSubstitution substitution;
  final UserPreferences preferences;

  const SwapDetailScreen({
    super.key,
    required this.substitution,
    required this.preferences,
  });

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Swap Intelligence'),
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
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Analyzing supply chain & impact...',
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
              icon: HugeIcons.strokeRoundedCloudLoading,
              color: AppColors.warning,
              size: 40,
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSwapBanner(orig, swap),
          const SizedBox(height: 24),

          _buildQuickStats(),
          const SizedBox(height: 24),

          _buildRationaleCard(),
          const SizedBox(height: 24),

          _buildSupplyChainSection(),
          const SizedBox(height: 24),

          const SectionHeader(
            title: 'Environmental Footprint',
            subtitle: 'CO₂ emissions & resource usage',
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
          const SizedBox(height: 12),
          _buildEnvDetails(orig, swap),
          const SizedBox(height: 24),

          const SectionHeader(
            title: 'Economic & Nutritional',
            subtitle: 'Cost efficiency and health profile',
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
          const SizedBox(height: 12),
          _buildNutritionComparison(orig, swap),
          const SizedBox(height: 24),

          if (widget.preferences.detailLevel == DetailLevel.detailed) ...[
            _buildOptimisationInsights(),
            const SizedBox(height: 32),
          ],

          AdaptiveButton(
            label: 'Accept This Swap',
            onPressed: () {
              // Telemetry: fire and forget, never blocks the pop.
              ApiService.sendSwapFeedback(sub, accepted: true);
              Navigator.pop(context, true);
            },
            isFullWidth: true,
            hugeIcon: HugeIcons.strokeRoundedTick02,
          ),
          const SizedBox(height: 8),
          AdaptiveButton(
            label: 'Keep Original',
            onPressed: () {
              // Telemetry: fire and forget, never blocks the pop.
              ApiService.sendSwapFeedback(sub, accepted: false);
              Navigator.pop(context, false);
            },
            isFullWidth: true,
            isPrimary: false,
            hugeIcon: HugeIcons.strokeRoundedCancel01,
          ),
          const SizedBox(height: 40),
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
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(orig.emoji, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 12),
                Text(
                  orig.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(swap.emoji, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 12),
                Text(
                  swap.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _statItem(
          'Stability',
          '${(sub.supplyStability * 100).toStringAsFixed(0)}%',
          HugeIcons.strokeRoundedAnalyticsUp,
          AppColors.info,
        ),
        const SizedBox(width: 12),
        _statItem(
          'Realism',
          '${(sub.realismScore * 100).toStringAsFixed(0)}%',
          HugeIcons.strokeRoundedUserGroup,
          AppColors.accentDark,
        ),
        const SizedBox(width: 12),
        _statItem(
          'Rank',
          '#${sub.paretoRank}',
          HugeIcons.strokeRoundedTarget02,
          AppColors.success,
        ),
      ],
    );
  }

  Widget _statItem(String label, String value, List<List<dynamic>> icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            HugeIcon(icon: icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRationaleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
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
                  icon: HugeIcons.strokeRoundedIdea,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Selection Rationale',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            sub.rationale,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
          if (sub.humanFlaggedLowRealism) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlertCircle,
                    color: AppColors.warning.withValues(alpha: 0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This swap is identified as a behavioral stretch.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF856404),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplyChainSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Supply & Realism',
          subtitle: 'UK agricultural data vs behavioral patterns',
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              _buildStabilityBar('UK Supply Stability', sub.supplyStability),
              const SizedBox(height: 20),
              _buildStabilityBar('Behavioral Realism', sub.realismScore),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStabilityBar(String label, double value) {
    Color barColor = value > 0.7 
        ? AppColors.success 
        : (value > 0.4 ? AppColors.warning : AppColors.error);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: barColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildOptimisationInsights() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mathematical Context',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This swap was selected from a frontier of ${sub.paretoFrontSize} Pareto-efficient options. It was ranked #${sub.paretoRank} based on your current weighting profiles:',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sub.weightsApplied.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Text(
                  '${e.key}: ${(e.value * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              );
            }).toList(),
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
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
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
          const SizedBox(height: 12),
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
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
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
          if (swapBetter) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '✓ $pct% ${lowerIsBetter ? "reduction" : "improvement"} with swap',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
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
          _nutritionRow('Protein', orig.proteinPerKg, swap.proteinPerKg, 'g'),
          const Divider(height: 16, color: AppColors.divider),
          _nutritionRow('Calories', orig.caloriesPerKg, swap.caloriesPerKg, 'kcal'),
          const Divider(height: 16, color: AppColors.divider),
          _nutritionRow('Fibre', orig.fibrePerKg, swap.fibrePerKg, 'g'),
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
            '${orig.toStringAsFixed(0)}$unit',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${swap.toStringAsFixed(0)}$unit',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isPositive ? AppColors.success : AppColors.textPrimary,
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
            '${orig.waterPerKg.toStringAsFixed(0)}L',
            '${swap.waterPerKg.toStringAsFixed(0)}L',
            swap.waterPerKg < orig.waterPerKg,
          ),
          const Divider(height: 16, color: AppColors.divider),
          _envRow(
            '🌍',
            'Land Use',
            '${orig.landPerKg.toStringAsFixed(1)}m²',
            '${swap.landPerKg.toStringAsFixed(1)}m²',
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
              fontSize: 13,
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
              fontWeight: FontWeight.w700,
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
}
