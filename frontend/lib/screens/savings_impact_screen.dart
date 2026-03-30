import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../services/optimisation_engine.dart';
import '../widgets/adaptive_widgets.dart';
import 'onboarding_screen.dart';

class SavingsImpactScreen extends StatefulWidget {
  final OptimisationResult result;

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
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Impact'),
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.primary, size: 24),
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
              const SectionHeader(title: 'Your Weekly Improvement', subtitle: 'What changes when you switch'),
              _buildImprovementGrid(),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Annual Projections', subtitle: 'If you maintain these changes over a year'),
              _buildAnnualProjections(),
              const SizedBox(height: 24),
              if (widget.result.substitutions.isNotEmpty) ...[
                const SectionHeader(title: 'Top Substitutions', subtitle: 'Your most impactful swaps'),
                ...widget.result.substitutions.take(3).map((s) =>
                  SubstitutionCard(
                    originalName: s.original.name,
                    originalEmoji: s.original.emoji,
                    replacementName: s.replacement.name,
                    replacementEmoji: s.replacement.emoji,
                    reason: s.reason,
                    carbonSaved: s.carbonSaved,
                    costSaved: s.costSaved,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const SectionHeader(title: 'Sustainability Insights'),
              ..._buildInsights(),
              const SizedBox(height: 24),
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
    final comp = widget.result.comparison;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
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
          const Text('Great Choices!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text("Here's how your optimised basket compares", style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 20),
          Row(
            children: [
              _heroMetric('${comp.carbonChange.abs().toStringAsFixed(0)}%', 'Carbon\nReduction', '🌍'),
              const SizedBox(width: 10),
              _heroMetric('£${comp.costSaved.abs().toStringAsFixed(0)}', 'Weekly\nSaving', '💰'),
              const SizedBox(width: 10),
              _heroMetric('${comp.proteinChange > 0 ? '+' : ''}${comp.proteinChange.toStringAsFixed(0)}%', 'Protein\nChange', '💪'),
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
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8), height: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovementGrid() {
    final comp = widget.result.comparison;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        MetricCard(
          label: 'Carbon Reduction',
          value: comp.carbonChange.abs().toStringAsFixed(0),
          unit: '%',
          hugeIcon: HugeIcons.strokeRoundedCloud,
          color: AppColors.carbonColor,
          changeText: '−${comp.carbonSaved.toStringAsFixed(1)} kg',
          isPositive: true,
        ),
        MetricCard(
          label: 'Water Saved',
          value: comp.waterChange.abs().toStringAsFixed(0),
          unit: '%',
          hugeIcon: HugeIcons.strokeRoundedDroplet,
          color: AppColors.waterColor,
          changeText: '−${(comp.waterSaved / 1000).toStringAsFixed(1)}k L',
          isPositive: true,
        ),
        MetricCard(
          label: 'Cost Saving',
          value: '£${comp.costSaved.abs().toStringAsFixed(0)}',
          unit: '/week',
          hugeIcon: HugeIcons.strokeRoundedPiggyBank,
          color: AppColors.costColor,
          changeText: '${comp.costChange.toStringAsFixed(0)}%',
          isPositive: comp.costSaved > 0,
        ),
        MetricCard(
          label: 'Fibre Change',
          value: '${comp.fibreChange > 0 ? '+' : ''}${comp.fibreChange.toStringAsFixed(0)}',
          unit: '%',
          hugeIcon: HugeIcons.strokeRoundedOrganicFood,
          color: AppColors.nutritionColor,
          changeText: comp.fibreChange > 0 ? 'Improved' : 'Similar',
          isPositive: comp.fibreChange >= 0,
        ),
      ],
    );
  }

  Widget _buildAnnualProjections() {
    final comp = widget.result.comparison;
    final annualCarbon = comp.carbonSaved * 52;
    final annualCost = comp.costSaved * 52;
    final annualWater = comp.waterSaved * 52;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _projectionRow('🌍', 'Carbon savings', '${(annualCarbon / 1000).toStringAsFixed(2)} tonnes CO₂', 'Equivalent to ${(annualCarbon / 100).toStringAsFixed(0)} trees planted'),
          const Divider(height: 20, color: AppColors.divider),
          _projectionRow('💰', 'Cost savings', '£${annualCost.toStringAsFixed(0)} per year', "That's ${(annualCost / 12).toStringAsFixed(0)} extra per month"),
          const Divider(height: 20, color: AppColors.divider),
          _projectionRow('💧', 'Water savings', '${(annualWater / 1000).toStringAsFixed(0)}k litres', 'Enough to fill ${(annualWater / 5000).toStringAsFixed(0)} bathtubs'),
        ],
      ),
    );
  }

  Widget _projectionRow(String emoji, String title, String value, String context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(context, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary, fontStyle: FontStyle.italic)),
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
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Text(insight, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.45)),
      );
    }).toList();
  }

  Widget _buildSeasonalSuggestions() {
    final seasonal = widget.result.optimisedBasket.where((i) => i.isSeasonal || i.isLocal).toList();
    if (seasonal.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Seasonal & Local Picks', subtitle: 'Support UK farmers and reduce food miles'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
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
                          Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          if (item.seasonalNote != null)
                            Text(item.seasonalNote!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.isSeasonal) const Padding(padding: EdgeInsets.only(right: 4), child: Text('🌿', style: TextStyle(fontSize: 14))),
                        if (item.isLocal) const Text('📍', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBeforeAfterComparison() {
    final comp = widget.result.comparison;
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
              const Expanded(flex: 2, child: Text('Metric', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary))),
              Expanded(child: Text('Before', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary))),
              Expanded(child: Text('After', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success))),
            ],
          ),
          const Divider(height: 16, color: AppColors.divider),
          _comparisonRow('Carbon', '${comp.original.totalCarbon.toStringAsFixed(1)} kg', '${comp.optimised.totalCarbon.toStringAsFixed(1)} kg', comp.carbonChange < 0),
          _comparisonRow('Water', '${(comp.original.totalWater / 1000).toStringAsFixed(1)}k L', '${(comp.optimised.totalWater / 1000).toStringAsFixed(1)}k L', comp.waterChange < 0),
          _comparisonRow('Cost', '£${comp.original.totalCost.toStringAsFixed(0)}', '£${comp.optimised.totalCost.toStringAsFixed(0)}', comp.costChange < 0),
          _comparisonRow('Protein', '${comp.original.totalProtein.toStringAsFixed(0)} g', '${comp.optimised.totalProtein.toStringAsFixed(0)} g', comp.proteinChange >= 0),
          _comparisonRow('Fibre', '${comp.original.totalFibre.toStringAsFixed(0)} g', '${comp.optimised.totalFibre.toStringAsFixed(0)} g', comp.fibreChange >= 0),
        ],
      ),
    );
  }

  Widget _comparisonRow(String label, String before, String after, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Expanded(child: Text(before, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(child: Text(after, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isGood ? AppColors.success : AppColors.error))),
        ],
      ),
    );
  }
}
