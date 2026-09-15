import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../models/food_item.dart';
import '../models/history_entry.dart';
import '../models/user_preferences.dart';
import '../services/api_service.dart';
import '../services/history_store.dart';
import '../services/preferences_store.dart';
import '../widgets/adaptive_widgets.dart';
import '../widgets/price_outlook_card.dart';
import 'savings_impact_screen.dart';
import 'swap_detail_screen.dart';

class OptimisedBasketScreen extends StatefulWidget {
  final List<FoodItem> originalBasket;
  final UserPreferences preferences;
  final String? historyEntryId;

  const OptimisedBasketScreen({
    super.key,
    required this.originalBasket,
    required this.preferences,
    this.historyEntryId,
  });

  @override
  State<OptimisedBasketScreen> createState() => _OptimisedBasketScreenState();
}

class _OptimisedBasketScreenState extends State<OptimisedBasketScreen>
    with TickerProviderStateMixin {
  ApiOptimisationResult? _result;
  bool _isOptimising = true;
  String? _errorMessage;

  // Independent of the optimisation call and allowed to fail silently: this
  // is a bonus signal, not something the rest of the screen depends on.
  FeedCostOutlook? _feedOutlook;

  // Substitutions the user has explicitly accepted, keyed by originalId.
  // The API returns every suggested swap ranked and ready, but applying them
  // to the basket before the user has looked at a single one read as the app
  // silently changing their shopping list on its own. Nothing is applied
  // until "Accept This Swap" is tapped; "Keep Original" undoes an acceptance.
  final Set<String> _acceptedIds = {};

  // ---------------------------------------------------------------------------
  // Display thresholds.
  //
  // Money and carbon are shown in the units a shopper actually thinks in,
  // computed from the basket rather than read off the score deltas. Score
  // points are the optimiser's internal currency and mean nothing to a user:
  // "0pts less CO2" is not a statement anybody can act on.
  // ---------------------------------------------------------------------------
  static const double _penceBand = 0.01;   // below this, the price is the same
  static const double _carbonBand = 0.05;  // kg CO2e

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
    _loadFeedOutlook();
  }

  Future<void> _loadFeedOutlook() async {
    try {
      final outlook = await ApiService.getFeedCostPressure();
      if (mounted) setState(() => _feedOutlook = outlook);
    } catch (_) {
      // No outlook card rather than an error state — this section is a
      // bonus on top of the swap suggestions, not a thing worth blocking or
      // retrying for.
    }
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
    } catch (_) {
      // Deliberately one message for every failure mode. The user cannot act
      // on a status code or a server name, and naming our infrastructure in
      // the UI reads as a debug string that escaped.
      if (mounted) {
        setState(() {
          _errorMessage =
              "We couldn't work out your swaps just now. Check your "
              'connection and try again.';
          _isOptimising = false;
        });
      }
    }
  }

  void _navigateToSavings() {
    if (_result == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavingsImpactScreen(
          result: _result!,
          preferences: widget.preferences,
        ),
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
  // Loading state
  // ---------------------------------------------------------------------------

  Widget _buildOptimising() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedOptimiseIcon(),
          const SizedBox(height: 28),
          const Text(
            'Working out your swaps...',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comparing price, carbon, nutrition and UK supply',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
  // Error state
  // ---------------------------------------------------------------------------

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
            const SizedBox(height: 20),
            const Text(
              "Couldn't optimise your basket",
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please try again.',
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
  // Basket as currently displayed: starts as the original basket untouched,
  // and only shows a substitute once its swap has been accepted.
  // ---------------------------------------------------------------------------

  List<FoodItem> get _displayBasket {
    final result = _result!;
    return widget.originalBasket.map((item) {
      for (final s in result.substitutions) {
        if (s.originalId == item.id && _acceptedIds.contains(s.originalId)) {
          for (final o in result.optimisedBasket) {
            if (o.id == s.substituteId) return o.copyWith(quantity: item.quantity);
          }
        }
      }
      return item;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Headline figures.
  //
  // Computed from the basket the user is actually looking at, not from the
  // comparison the API returned. Those two diverge the moment a swap is
  // accepted or undone: the API figures are fixed at response time and assume
  // every swap is taken, so they used to claim savings the basket didn't
  // actually deliver until the user had accepted anything at all.
  // ---------------------------------------------------------------------------

  double get _originalCost =>
      widget.originalBasket.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get _currentCost =>
      _displayBasket.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get _costSaved => _originalCost - _currentCost;

  double get _originalCarbon =>
      widget.originalBasket.fold(0.0, (sum, i) => sum + i.totalCarbon);
  double get _currentCarbon =>
      _displayBasket.fold(0.0, (sum, i) => sum + i.totalCarbon);
  double get _carbonSaved => _originalCarbon - _currentCarbon;

  int get _activeSwaps => _result!.substitutions
      .where((s) => _acceptedIds.contains(s.originalId))
      .length;

  // Keeps the History row this basket started from up to date with the
  // savings actually realised, not the savings on offer. Fire-and-forget:
  // this is a local write and nothing in the UI depends on its completion.
  // Reads the existing row first so the original analysis timestamp is
  // preserved rather than bumped to "now" on every swap toggle.
  Future<void> _syncHistory() async {
    final id = widget.historyEntryId;
    if (id == null) return;
    final entries = await HistoryStore.load();
    final matches = entries.where((e) => e.id == id);
    final base = matches.isNotEmpty
        ? matches.first
        : HistoryEntry(
          id: id,
          timestamp: DateTime.now(),
          itemCount: widget.originalBasket.length,
          itemNames: widget.originalBasket.map((i) => i.name).toList(),
          totalCost: _originalCost,
          totalCarbon: _originalCarbon,
        );
    await HistoryStore.upsert(base.copyWith(
      swapsAccepted: _activeSwaps,
      costSaved: _costSaved,
      carbonSaved: _carbonSaved,
    ));
  }

  // Direction, not just movement. An earlier version asked only whether
  // anything had changed, so a basket that came out worse on both axes still
  // got a congratulatory green header over "11.7 kg more / £12.07 more".
  bool get _costBetter => _costSaved >= _penceBand;
  bool get _costWorse => _costSaved <= -_penceBand;
  bool get _carbonBetter => _carbonSaved >= _carbonBand;
  bool get _carbonWorse => _carbonSaved <= -_carbonBand;

  bool get _anyBetter => _costBetter || _carbonBetter;
  bool get _anyWorse => _costWorse || _carbonWorse;

  /// Green is earned only when something improved and nothing went backwards.
  bool get _isWin => _anyBetter && !_anyWorse;

  String get _costLine {
    if (_costSaved.abs() < _penceBand) return 'Same price';
    final amount = '£${_costSaved.abs().toStringAsFixed(2)}';
    return _costSaved > 0 ? '$amount less' : '$amount more';
  }

  String get _carbonLine {
    if (_carbonSaved.abs() < _carbonBand) return 'Same carbon';
    final amount = '${_carbonSaved.abs().toStringAsFixed(1)} kg';
    return _carbonSaved > 0 ? '$amount less' : '$amount more';
  }

  bool get _isDetailed =>
      widget.preferences.detailLevel == DetailLevel.detailed;

  void _toggleDetailLevel() {
    setState(() {
      widget.preferences.detailLevel =
          _isDetailed ? DetailLevel.simple : DetailLevel.detailed;
    });
    PreferencesStore.save(widget.preferences);
  }

  // ---------------------------------------------------------------------------
  // Results
  // ---------------------------------------------------------------------------

  Widget _buildResult() {
    final result = _result!;

    // A swap whose rationale is "marginal" has nothing concrete to offer.
    // Presenting it under the same heading as a real improvement teaches the
    // user to distrust the list, so it goes in a separate, quieter section.
    final meaningful = result.substitutions
        .where((s) => !s.rationale.toLowerCase().startsWith('marginal'))
        .toList();
    final marginal = result.substitutions
        .where((s) => s.rationale.toLowerCase().startsWith('marginal'))
        .toList();

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildComparisonBanner(),
            const SizedBox(height: 16),
            if (result.supplyPressure != null)
              _buildSupplyPressureBanner(
                result.supplyPressure!,
                result.cropProvenance,
              ),
            if (_feedOutlook != null && _feedOutlook!.pressures.isNotEmpty) ...[
              const SizedBox(height: 12),
              PriceOutlookCard(outlook: _feedOutlook!, isDetailed: _isDetailed),
            ],
            const SizedBox(height: 24),
            if (meaningful.isNotEmpty) ...[
              SectionHeader(
                title: 'Suggested Swaps',
                subtitle: meaningful.length == 1
                    ? 'One change to consider'
                    : '${meaningful.length} changes to consider',
              ),
              ...meaningful.map(_buildSwapCard),
              const SizedBox(height: 20),
            ],
            if (marginal.isNotEmpty) ...[
              SectionHeader(
                title: 'Close Calls',
                subtitle: marginal.length == 1
                    ? "One alternative that's about the same either way"
                    : '${marginal.length} alternatives that are about the same either way',
              ),
              ...marginal.map(_buildSwapCard),
              const SizedBox(height: 20),
            ],
            if (result.substitutions.isEmpty) _buildNoSwaps(),
            SectionHeader(
              title: 'Your Optimised Basket',
              subtitle:
                  '${_displayBasket.length} ${_displayBasket.length == 1 ? "item" : "items"} · '
                  '£${_currentCost.toStringAsFixed(2)} · '
                  '${_currentCarbon.toStringAsFixed(1)} kg CO₂',
            ),
            ..._displayBasket.map((item) {
              final wasSubstituted = result.substitutions.any(
                (s) =>
                    s.substituteId == item.id &&
                    _acceptedIds.contains(s.originalId),
              );
              return _buildOptimisedItemTile(item, wasSubstituted);
            }),
            if (result.insights.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionHeader(title: 'Insights'),
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

  Widget _buildSwapCard(ApiSubstitution s) {
    return GestureDetector(
      onTap: () async {
        final accepted = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => SwapDetailScreen(
              substitution: s,
              preferences: widget.preferences,
            ),
          ),
        );
        if (!mounted) return;
        setState(() {
          if (accepted == true) {
            _acceptedIds.add(s.originalId);
          } else if (accepted == false) {
            _acceptedIds.remove(s.originalId);
          }
        });
        if (accepted != null) _syncHistory();
      },
      child: SubstitutionCard(
        originalName: s.originalName,
        originalEmoji: _emojiFor(s.originalName),
        replacementName: s.substituteName,
        replacementEmoji: _emojiFor(s.substituteName),
        reason: s.rationale,
        carbonSaved: s.carbonDeltaKgPerKg,
        costSaved: s.costDeltaGbpPerKg,
        supplyStability: s.supplyStability,
        realismScore: s.realismScore,
        paretoRank: s.paretoRank,
        isLowRealism: s.humanFlaggedLowRealism,
        showRank: _isDetailed,
        accepted: _acceptedIds.contains(s.originalId),
      ),
    );
  }

  Widget _buildNoSwaps() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nothing worth swapping',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'No alternative beat what you already have on price, carbon, '
            'nutrition and UK supply together.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Headline banner
  //
  // Reports pounds and kilograms, not score points, and only claims a win when
  // the basket actually improved. A green celebration over "0pts / 0pts", or
  // over a basket that got more expensive, tells the user the app is not
  // paying attention.
  // ---------------------------------------------------------------------------

  Widget _buildComparisonBanner() {
    final win = _isWin;
    final String headline;
    if (_activeSwaps == 0) {
      headline = 'No changes made';
    } else if (win) {
      headline = 'Your basket, improved';
    } else if (_anyBetter && _anyWorse) {
      headline = 'Better in some ways, worse in others';
    } else if (_anyWorse) {
      headline = 'This basket costs you more';
    } else {
      headline = 'Swapped, much the same';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: win
              ? const [Color(0xFF52B788), Color(0xFF40916C)]
              : const [Color(0xFF6C8A7B), Color(0xFF52705F)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: win ? 0.3 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          HugeIcon(
            icon: win
                ? HugeIcons.strokeRoundedMagicWand01
                : HugeIcons.strokeRoundedAnalytics01,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            headline,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _bannerStat(
                _carbonLine,
                'Carbon',
                HugeIcons.strokeRoundedAnalyticsDown,
              ),
              const SizedBox(width: 12),
              _bannerStat(
                _costLine,
                'Weekly cost',
                HugeIcons.strokeRoundedPiggyBank,
              ),
              const SizedBox(width: 12),
              _bannerStat(
                '$_activeSwaps',
                _activeSwaps == 1 ? 'Swap' : 'Swaps',
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
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
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
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

  // ---------------------------------------------------------------------------
  // Supply Chain Outlook
  //
  // Previously six unlabelled bars with no scale, no numbers and no stated
  // direction, which communicates nothing. Now every row carries its value and
  // the section says in words what a high reading means.
  //
  // Readings sitting exactly on 0.500 are the pipeline's neutral default for a
  // commodity with no published stock series (oats, currently). Rendering that
  // as an amber bar presents absent data as a measurement, so it is greyed and
  // labelled instead.
  // ---------------------------------------------------------------------------

  static const double _neutralPressure = 0.5;
  static const double _neutralEpsilon = 0.001;

  bool _isNoData(double v) => (v - _neutralPressure).abs() < _neutralEpsilon;

  /// Where this basket comes from, in UK crops.
  ///
  /// Traces provenance rather than ranking pressure. An earlier version named
  /// the user's "tightest category", which was circular — the category is the
  /// food type, so "bread is tightest and your bread depends on it" says
  /// nothing — and it invented a ranking out of readings that were all
  /// comfortable.
  ///
  /// The feed route is the half worth showing: a chicken is, in supply terms,
  /// largely a wheat product, and hardly any shopper knows that. It also holds
  /// up on an ordinary season, which matters because most seasons are ordinary.
  Widget? _buildProvenanceLines(ApiCropProvenance? p) {
    if (p == null || !p.hasAnything) return null;

    String joinNames(List<String> names) {
      final shown = names.take(3).toList();
      final extra = names.length - shown.length;
      final base = shown.length == 1
          ? shown.first
          : '${shown.take(shown.length - 1).join(", ")} and ${shown.last}';
      return extra > 0 ? '$base and $extra more' : base;
    }

    final rows = <Widget>[];
    for (final g in p.grains) {
      final parts = <String>[];
      if (g.directFoods.isNotEmpty) {
        parts.add('your ${joinNames(g.directFoods)}');
      }
      if (g.feedFoods.isNotEmpty) {
        parts.add('the feed behind your ${joinNames(g.feedFoods)}');
      }
      if (parts.isEmpty) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '${g.grain}: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(text: '${parts.join(", and ")}.'),
              ],
            ),
          ),
        ),
      );
    }
    if (rows.isEmpty) return null;

    // State sentence. Grains sharing a reading are grouped so the line reads
    // as prose rather than as three separate verdicts.
    final byState = <String, List<String>>{};
    for (final g in p.grains) {
      if (!g.hasData || g.state.isEmpty) continue;
      byState.putIfAbsent(g.state, () => []).add(g.grain);
    }
    final stateParts = byState.entries.map((e) {
      final names = e.value;
      final subject = names.length == 1
          ? names.first
          : '${names.take(names.length - 1).join(", ")} and ${names.last}';
      final verb = names.length == 1 ? 'is' : 'are';
      return '$subject $verb ${e.key}';
    }).toList();

    final n = p.grains.length;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your basket traces back to $n UK ${n == 1 ? "crop" : "crops"}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...rows,
          if (stateParts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${stateParts.join("; ")} this season.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildSupplyPressureBanner(
    ApiSupplyPressure pressure,
    ApiCropProvenance? provenance,
  ) {
    final grains = pressure.grainPressure.entries.toList();
    final categories = pressure.foodCategoryPressure.entries.take(3).toList();

    // Only real readings should set the headline status. A no-data default
    // must not be able to tip the whole section into "moderate pressure".
    final measured = [
      ...pressure.grainPressure.values,
      ...pressure.foodCategoryPressure.values,
    ].where((v) => !_isNoData(v)).toList();

    final maxP = measured.isNotEmpty
        ? measured.reduce((a, b) => a > b ? a : b)
        : 0.0;

    final Color statusColor = measured.isEmpty
        ? AppColors.textTertiary
        : (maxP > 0.7
            ? AppColors.error
            : (maxP > 0.4 ? AppColors.warning : AppColors.success));
    final String statusText = measured.isEmpty
        ? 'No data'
        : (maxP > 0.7
            ? 'Tight supply'
            : (maxP > 0.4 ? 'Some pressure' : 'Comfortable supply'));

    final hasNoData = [...grains, ...categories].any((e) => _isNoData(e.value));
    final provenanceLines = _buildProvenanceLines(provenance);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAnalytics01,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'UK Supply Outlook',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'How tight UK supply is right now. Higher means tighter, which '
            'tends to feed through to shelf prices later.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (_isDetailed) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Grains',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...grains.map((e) => _pressureRow(e.key, e.value)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Food categories',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...categories.map((e) => _pressureRow(e.key, e.value)),
                    ],
                  ),
                ),
              ],
            ),
            if (pressure.dataVintage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'AHDB balance sheets, ${pressure.dataVintage}.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (hasNoData) ...[
              const SizedBox(height: 4),
              const Text(
                'No data: no stock figures are published for that commodity, '
                'so it is treated neutrally rather than penalised.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            ?provenanceLines,
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _toggleDetailLevel,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isDetailed ? 'Show less' : 'Show grain & crop breakdown',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                HugeIcon(
                  icon: _isDetailed
                      ? HugeIcons.strokeRoundedArrowUp01
                      : HugeIcons.strokeRoundedArrowDown01,
                  color: AppColors.primary,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pressureRow(String label, double value) {
    final noData = _isNoData(value);
    final Color color = noData
        ? AppColors.textTertiary
        : (value > 0.7
            ? AppColors.error
            : (value > 0.4 ? AppColors.warning : AppColors.success));
    final display = label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: noData ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            width: 34,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              // A missing series has no magnitude, so the bar reads empty
              // rather than sitting at the halfway mark.
              widthFactor: noData ? 0.0 : value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text(
              noData ? 'no data' : '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: noData ? 10 : 11,
                fontWeight: FontWeight.w600,
                fontStyle: noData ? FontStyle.italic : FontStyle.normal,
                color: color,
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
    if (lower.contains('lamb')) return '🍖';
    if (lower.contains('pork') || lower.contains('bacon')) return '🥓';
    if (lower.contains('sausage')) return '🌭';
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
    if (lower.contains('pasta') || lower.contains('couscous')) return '🍝';
    if (lower.contains('flour')) return '🌾';
    if (lower.contains('rice')) return '🍚';
    if (lower.contains('oat')) return '🥣';
    if (lower.contains('sweetcorn') || lower.contains('maize')) return '🌽';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('apple')) return '🍎';
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('broccoli')) return '🥦';
    if (lower.contains('sprout')) return '🥬';
    if (lower.contains('carrot')) return '🥕';
    if (lower.contains('spinach') || lower.contains('lettuce')) return '🥬';
    return '🍽️';
  }
}

// ---------------------------------------------------------------------------
// Animated icon
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
