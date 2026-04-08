import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../models/food_item.dart';
import '../models/user_preferences.dart';
import '../services/api_service.dart';
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
  ApiOptimisationResult? _result;
  bool _isOptimising = true;
  String? _errorMessage;

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
    _runOptimisation();
  }

  Future<void> _runOptimisation() async {
    try {
      final result = await ApiService.optimiseBasket(
        widget.originalBasket,
        widget.preferences,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _isOptimising = false;
        });
        _animController.forward();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isOptimising = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not reach the optimisation server. '
              'Check your connection and try again.';
          _isOptimising = false;
        });
      }
    }
  }

  void _navigateToSavings() {
    if (_result == null) return;
    // Convert ApiOptimisationResult → SavingsImpactScreen
    // Pass the raw result — update SavingsImpactScreen to accept ApiOptimisationResult
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavingsImpactScreen(result: _result!),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
      body: _isOptimising
          ? _buildOptimising()
          : _errorMessage != null
              ? _buildError()
              : _buildResult(),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading state — unchanged from original
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Error state — new
  // ---------------------------------------------------------------------------

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
            const SizedBox(height: 20),
            const Text(
              'Optimisation Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            AdaptiveButton(
              label: 'Try Again',
              onPressed: () {
                setState(() {
                  _isOptimising = true;
                  _errorMessage = null;
                });
                _runOptimisation();
              },
              isFullWidth: true,
              hugeIcon: HugeIcons.strokeRoundedRefresh,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Results state — same UI, now using ApiOptimisationResult
  // ---------------------------------------------------------------------------

  Widget _buildResult() {
    final result = _result!;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildComparisonBanner(result),
            const SizedBox(height: 24),
            if (result.substitutions.isNotEmpty) ...[
              SectionHeader(
                title: 'Suggested Swaps',
                subtitle: '${result.substitutions.length} improvements found',
              ),
              ...result.substitutions.map(
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
              const SizedBox(height: 20),
            ],
            SectionHeader(
              title: 'Your Optimised Basket',
              subtitle: '${result.optimisedBasket.length} items',
            ),
            ...result.optimisedBasket.asMap().entries.map((entry) {
              final item = entry.value;
              final wasSubstituted = result.substitutions
                  .any((s) => s.substituteId == item.id);
              return _buildOptimisedItemTile(item, wasSubstituted);
            }),
            if (result.insights.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionHeader(title: 'Insights', subtitle: ''),
              ...result.insights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    insight,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildComparisonBanner(ApiOptimisationResult result) {
    final comp = result.comparison;
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
                '${comp.envReduction.toStringAsFixed(0)}pts',
                'Less CO₂',
                HugeIcons.strokeRoundedAnalyticsDown,
              ),
              const SizedBox(width: 12),
              _bannerStat(
                '${comp.costReduction.toStringAsFixed(0)}pts',
                'Cost saved',
                HugeIcons.strokeRoundedPiggyBank,
              ),
              const SizedBox(width: 12),
              _bannerStat(
                '${result.substitutions.length}',
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
            HugeIcon(icon: icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
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
                  '${item.quantity}kg · £${item.totalPrice.toStringAsFixed(2)} · ${item.totalCarbon.toStringAsFixed(2)} kg CO₂',
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
                      if (item.isLocal)
                        _tagChip('📍 Local', AppColors.info),
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

  String _emojiFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('chicken')) return '🍗';
    if (lower.contains('beef')) return '🥩';
    if (lower.contains('salmon') || lower.contains('tuna')) return '🐟';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('yoghurt') || lower.contains('yogurt')) return '🥄';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('lentil') || lower.contains('bean') || lower.contains('chickpea')) return '🫘';
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

// ---------------------------------------------------------------------------
// Animated icon — unchanged
// ---------------------------------------------------------------------------

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
