import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../models/food_item.dart';
import '../models/basket_impact.dart';
import '../models/user_preferences.dart';
import '../services/optimisation_engine.dart';
import '../widgets/adaptive_widgets.dart';
import 'savings_impact_screen.dart';

class OptimisedBasketScreen extends StatefulWidget {
  final List<FoodItem> originalBasket;
  final UserPreferences preferences;

  const OptimisedBasketScreen({
    super.key,
    required this.originalBasket,
    required this.preferences,
  });

  @override
  State<OptimisedBasketScreen> createState() => _OptimisedBasketScreenState();
}

class _OptimisedBasketScreenState extends State<OptimisedBasketScreen>
    with TickerProviderStateMixin {
  late OptimisationResult _result;
  bool _isOptimising = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    // Initialise with empty result
    _result = OptimisationResult(
      optimisedBasket: [],
      substitutions: [],
      comparison: ImpactComparison(
        original: const BasketImpact(
          totalCarbon: 0,
          totalWater: 0,
          totalLand: 0,
          totalCost: 0,
          totalProtein: 0,
          totalCalories: 0,
          totalFibre: 0,
        ),
        optimised: const BasketImpact(
          totalCarbon: 0,
          totalWater: 0,
          totalLand: 0,
          totalCost: 0,
          totalProtein: 0,
          totalCalories: 0,
          totalFibre: 0,
        ),
      ),
      insights: [],
    );

    // Simulate optimisation
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _result = OptimisationEngine.optimise(
            widget.originalBasket,
            widget.preferences,
          );
          _isOptimising = false;
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

  void _navigateToSavings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SavingsImpactScreen(result: _result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimised Basket'),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isOptimising ? _buildOptimising() : _buildResult(),
    );
  }

  Widget _buildOptimising() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedOptimiseIcon(),
          const SizedBox(height: 28),
          const Text(
            'Optimising your basket...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Finding the best swaps for you',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Checking sustainability • Matching your budget • Preserving nutrition',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(AppColors.success),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildComparisonBanner(),
            const SizedBox(height: 24),
            if (_result.substitutions.isNotEmpty) ...[
              SectionHeader(
                title: 'Suggested Swaps',
                subtitle: '${_result.substitutions.length} improvements found',
              ),
              ..._result.substitutions.map(
                (s) => SubstitutionCard(
                  originalName: s.original.name,
                  originalEmoji: s.original.emoji,
                  replacementName: s.replacement.name,
                  replacementEmoji: s.replacement.emoji,
                  reason: s.reason,
                  carbonSaved: s.carbonSaved,
                  costSaved: s.costSaved,
                ),
              ),
              const SizedBox(height: 20),
            ],
            const SectionHeader(
              title: 'Your Optimised Basket',
              subtitle: 'Tap items for more details',
            ),
            ..._result.optimisedBasket.asMap().entries.map((entry) {
              final item = entry.value;
              final wasSubstituted = _result.substitutions.any(
                (s) => s.replacement.id == item.id,
              );
              return _buildOptimisedItemTile(item, wasSubstituted);
            }),
            const SizedBox(height: 24),
            AdaptiveButton(
              label: 'View Full Savings Report',
              onPressed: _navigateToSavings,
              isFullWidth: true,
              hugeIcon: HugeIcons.strokeRoundedAnalyticsUp,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonBanner() {
    final comp = _result.comparison;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF52B788), Color(0xFF40916C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMagicWand01,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'Optimisation Complete!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _bannerStat(
                '${comp.carbonChange.abs().toStringAsFixed(0)}%',
                'Less CO₂',
                HugeIcons.strokeRoundedAnalyticsDown,
              ),
              const SizedBox(width: 12),
              _bannerStat(
                '£${comp.costSaved.abs().toStringAsFixed(0)}',
                'Saved',
                HugeIcons.strokeRoundedPiggyBank,
              ),
              const SizedBox(width: 12),
              _bannerStat(
                '${_result.substitutions.length}',
                'Swaps',
                HugeIcons.strokeRoundedExchange01,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String value, String label, List<List<dynamic>> icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: icon,
              color: Colors.white.withValues(alpha: 0.8),
              size: 18,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimisedItemTile(FoodItem item, bool wasSubstituted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: wasSubstituted
            ? AppColors.success.withValues(alpha: 0.04)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: wasSubstituted
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.5),
          width: wasSubstituted ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (wasSubstituted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'SWAPPED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity}kg · £${item.totalPrice.toStringAsFixed(2)} · ${item.totalCarbon.toStringAsFixed(1)} kg CO₂',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.isSeasonal || item.isLocal) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.isSeasonal)
                        _tagChip('🌿 Seasonal', AppColors.success),
                      if (item.isSeasonal && item.isLocal)
                        const SizedBox(width: 6),
                      if (item.isLocal) _tagChip('📍 Local', AppColors.info),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Animated icon for optimisation loading state
class _AnimatedOptimiseIcon extends StatefulWidget {
  @override
  State<_AnimatedOptimiseIcon> createState() => _AnimatedOptimiseIconState();
}

class _AnimatedOptimiseIconState extends State<_AnimatedOptimiseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedSettings01,
          color: AppColors.success,
          size: 48,
        ),
      ),
    );
  }
}
