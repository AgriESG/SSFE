import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../models/food_item.dart';
import '../models/user_preferences.dart';
import '../services/api_service.dart';
import '../widgets/adaptive_widgets.dart';
import 'impact_dashboard_screen.dart';

class BasketInputScreen extends StatefulWidget {
  final UserPreferences preferences;

  const BasketInputScreen({super.key, required this.preferences});

  @override
  State<BasketInputScreen> createState() => _BasketInputScreenState();
}

class _BasketInputScreenState extends State<BasketInputScreen>
    with SingleTickerProviderStateMixin {
  final List<FoodItem> _basket = [];

  // Food catalogue state
  List<FoodItem> _allFoods = [];
  List<FoodItem> _filteredFoods = [];
  List<String> _categories = ['All'];
  bool _isLoading = true;
  String? _loadError;

  // ---------------------------------------------------------------------------
  // Cold-start handling.
  //
  // The API is hosted on a tier that spins down after a period of inactivity
  // and takes the better part of a minute to wake. The first request after an
  // idle period therefore fails while the service starts, and a single attempt
  // shows the user an error for something that is about to work on its own.
  //
  // So: retry automatically with a widening gap before surfacing anything, and
  // if the first attempt is slow, tell the user it is waking rather than
  // leaving them watching a spinner with no explanation.
  // ---------------------------------------------------------------------------
  static const int _maxAttempts = 3;
  static const List<Duration> _retryBackoff = [
    Duration(seconds: 3),
    Duration(seconds: 8),
  ];
  static const Duration _slowStartThreshold = Duration(seconds: 5);

  bool _slowStart = false;
  Timer? _slowStartTimer;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pasteController = TextEditingController();
  bool _showPasteMode = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadFoods();
  }

  @override
  void dispose() {
    _slowStartTimer?.cancel();
    _searchController.dispose();
    _pasteController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadFoods() async {
    _slowStartTimer?.cancel();
    _slowStartTimer = Timer(_slowStartThreshold, () {
      if (mounted && _isLoading) {
        setState(() => _slowStart = true);
      }
    });

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final foods = await ApiService.getAllFoods();
        final cats = [
          'All',
          ...{...foods.map((f) => f.category)}.toList()..sort(),
        ];
        _slowStartTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _allFoods = foods;
          _filteredFoods = foods;
          _categories = cats;
          _isLoading = false;
          _slowStart = false;
          _loadError = null;
        });
        _animController.forward();
        return;
      } catch (_) {
        if (attempt < _maxAttempts) {
          // Still worth waiting: the service may simply be starting up.
          await Future.delayed(_retryBackoff[attempt - 1]);
          if (!mounted) return;
          continue;
        }

        // Out of attempts. Say what the user can do, not what our
        // infrastructure is doing.
        _slowStartTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _loadError =
              "We couldn't load your foods just now. Check your connection "
              'and try again.';
          _isLoading = false;
          _slowStart = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  void _applyFilter() {
    var items = _selectedCategory == 'All'
        ? _allFoods
        : _allFoods.where((f) => f.category == _selectedCategory).toList();

    if (_searchQuery.isNotEmpty) {
      items = items
          .where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    setState(() => _filteredFoods = items);
  }

  // ---------------------------------------------------------------------------
  // Basket operations
  // ---------------------------------------------------------------------------

  // The /foods list endpoint that populates search results carries no
  // price/carbon/nutrition data (see FoodItem.fromApiJson) — only the
  // /foods/{id} detail endpoint does. Fetch that detail the first time an
  // item is added so the basket, and everything computed from it downstream
  // (optimised basket totals, insights), has real numbers instead of zeros.
  Future<void> _addToBasket(FoodItem item) async {
    final idx = _basket.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      setState(() {
        _basket[idx] = _basket[idx].copyWith(quantity: _basket[idx].quantity + 1);
      });
      return;
    }

    FoodItem detailed;
    try {
      detailed = await ApiService.getFood(item.id);
    } catch (_) {
      detailed = item;
    }
    if (!mounted) return;

    setState(() {
      final existing = _basket.indexWhere((i) => i.id == item.id);
      if (existing >= 0) {
        _basket[existing] =
            _basket[existing].copyWith(quantity: _basket[existing].quantity + 1);
      } else {
        _basket.add(detailed.copyWith(quantity: 1));
      }
    });
  }

  void _removeFromBasket(int index) {
    setState(() => _basket.removeAt(index));
  }

  void _adjustQuantity(int index, double delta) {
    setState(() {
      final newQty = _basket[index].quantity + delta;
      if (newQty <= 0) {
        _basket.removeAt(index);
      } else {
        _basket[index] = _basket[index].copyWith(quantity: newQty);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Paste mode — searches against loaded catalogue
  // ---------------------------------------------------------------------------

  Future<void> _parsePastedList() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) return;

    final lines = text
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'^[\-•\*]\s*'), ''))
        .where((l) => l.isNotEmpty);

    int added = 0;
    int unmatched = 0;
    for (final line in lines) {
      final lower = line.toLowerCase();
      final match = _allFoods.where(
        (f) => f.name.toLowerCase().contains(lower),
      ).toList();
      if (match.isNotEmpty) {
        await _addToBasket(match.first);
        added++;
      } else {
        unmatched++;
      }
    }

    setState(() => _showPasteMode = false);
    _pasteController.clear();

    if (!mounted) return;

    // Previously a list where nothing matched produced no feedback at all, so
    // the screen simply closed and appeared to have done nothing.
    final String message;
    final Color background;
    if (added == 0) {
      message = "We couldn't match any of those to foods we know.";
      background = AppColors.error;
    } else if (unmatched > 0) {
      message = 'Added $added ${added == 1 ? "item" : "items"}. '
          '$unmatched not recognised.';
      background = AppColors.success;
    } else {
      message = 'Added $added ${added == 1 ? "item" : "items"} to your basket';
      background = AppColors.success;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToImpact() {
    if (_basket.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImpactDashboardScreen(
          basket: _basket,
          preferences: widget.preferences,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Your Basket'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: _showPasteMode
                  ? HugeIcons.strokeRoundedSearch01
                  : HugeIcons.strokeRoundedClipboard,
              color: AppColors.primary,
              size: 22,
            ),
            onPressed: () => setState(() => _showPasteMode = !_showPasteMode),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _loadError != null
              ? _buildError()
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      Expanded(
                        child: _showPasteMode
                            ? _buildPasteMode()
                            : _buildSearchMode(),
                      ),
                      _buildBasketSummary(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _slowStart ? 'Still loading' : 'Loading your foods...',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_slowStart) ...[
              const SizedBox(height: 6),
              const Text(
                'This can take up to a minute the first time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
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
              _loadError ?? "Something went wrong. Please try again.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            AdaptiveButton(
              label: 'Try Again',
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = null;
                  _slowStart = false;
                });
                _loadFoods();
              },
              isFullWidth: false,
              hugeIcon: HugeIcons.strokeRoundedRefresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchMode() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (q) {
              _searchQuery = q;
              _applyFilter();
            },
            decoration: InputDecoration(
              hintText: 'Search for food items...',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = '';
                        _applyFilter();
                      },
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Category chips
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) {
                    _selectedCategory = cat;
                    _applyFilter();
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filteredFoods.isEmpty
              ? _buildNoResults()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredFoods.length,
                  itemBuilder: (_, i) {
                    final item = _filteredFoods[i];
                    final inBasket = _basket.any((b) => b.id == item.id);
                    return _buildFoodItemTile(item, inBasket);
                  },
                ),
        ),
      ],
    );
  }

  /// A search that matches nothing previously rendered a blank area with no
  /// explanation, which reads as a broken screen rather than an empty result.
  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              color: AppColors.textTertiary,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No foods matching "$_searchQuery"'
                  : 'Nothing in this category yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try a different search or category.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasteMode() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Paste Your List',
            subtitle: 'Paste your grocery list below — one item per line',
          ),
          Expanded(
            child: TextField(
              controller: _pasteController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'chicken breast\nmilk\nrice\ntomatoes\neggs\n...',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AdaptiveButton(
            label: 'Add Items From List',
            onPressed: _parsePastedList,
            isFullWidth: true,
            hugeIcon: HugeIcons.strokeRoundedAdd01,
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItemTile(FoodItem item, bool inBasket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: inBasket
            ? AppColors.primary.withValues(alpha: 0.04)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inBasket
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          item.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          item.pricePerKg > 0
              ? '£${item.pricePerKg.toStringAsFixed(2)}/kg · ${item.carbonPerKg.toStringAsFixed(2)} kg CO₂/kg'
              : item.category,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: GestureDetector(
          onTap: () => _addToBasket(item),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: inBasket
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: inBasket
                  ? HugeIcons.strokeRoundedTick02
                  : HugeIcons.strokeRoundedAdd01,
              color: inBasket ? AppColors.success : AppColors.primary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasketSummary() {
    if (_basket.isEmpty) return _buildEmptyBasket();

    final totalCost = _basket.fold(0.0, (sum, i) => sum + i.totalPrice);
    final totalCarbon = _basket.fold(0.0, (sum, i) => sum + i.totalCarbon);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _basket.length,
                itemBuilder: (_, i) {
                  final item = _basket[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _adjustQuantity(i, -0.5),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedRemove01,
                              color: AppColors.textSecondary,
                              size: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${item.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _adjustQuantity(i, 0.5),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedAdd01,
                              color: AppColors.primary,
                              size: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeFromBasket(i),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete02,
                            color: AppColors.error,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalCost > 0
                      ? '${_basket.length} items · £${totalCost.toStringAsFixed(2)} · ${totalCarbon.toStringAsFixed(1)} kg CO₂'
                      : '${_basket.length} items selected',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AdaptiveButton(
              label: 'Analyse My Basket',
              onPressed: _basket.isNotEmpty ? _navigateToImpact : null,
              isFullWidth: true,
              hugeIcon: HugeIcons.strokeRoundedAnalytics01,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBasket() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedShoppingBasket01,
                color: AppColors.primary.withValues(alpha: 0.4),
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your basket is empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Search or paste items above to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
