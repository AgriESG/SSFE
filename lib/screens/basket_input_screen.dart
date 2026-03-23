import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../models/food_item.dart';
import '../models/user_preferences.dart';
import '../services/food_database.dart';
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
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pasteController = TextEditingController();
  bool _showPasteMode = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  List<String> get categories => ['All', ...FoodDatabase.categories];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pasteController.dispose();
    _animController.dispose();
    super.dispose();
  }

  List<FoodItem> get _filteredItems {
    var items = _selectedCategory == 'All'
        ? FoodDatabase.allFoods
        : FoodDatabase.byCategory(_selectedCategory);
    if (_searchQuery.isNotEmpty) {
      items = items
          .where(
            (item) =>
                item.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    return items;
  }

  void _addToBasket(FoodItem item) {
    setState(() {
      final idx = _basket.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        _basket[idx] = _basket[idx].copyWith(
          quantity: _basket[idx].quantity + 1,
        );
      } else {
        _basket.add(item.copyWith(quantity: 1));
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

  void _parsePastedList() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) return;
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    int added = 0;
    for (final line in lines) {
      final cleanLine = line.replaceAll(RegExp(r'^[\-•\*]\s*'), '');
      final results = FoodDatabase.search(cleanLine);
      if (results.isNotEmpty) {
        _addToBasket(results.first);
        added++;
      }
    }
    setState(() => _showPasteMode = false);
    _pasteController.clear();
    if (added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $added items to your basket'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Your Basket'),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            Expanded(
              child: _showPasteMode ? _buildPasteMode() : _buildSearchMode(),
            ),
            _buildBasketSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchMode() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (q) => setState(() => _searchQuery = q),
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
                        setState(() => _searchQuery = '');
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
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final cat = categories[i];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Item list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredItems.length,
            itemBuilder: (_, i) {
              final item = _filteredItems[i];
              final inBasket = _basket.any((b) => b.id == item.id);
              return _buildFoodItemTile(item, inBasket);
            },
          ),
        ),
      ],
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
        // leading: Text(item.emoji, style: const TextStyle(fontSize: 26)),
        title: Text(
          item.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '£${item.pricePerKg.toStringAsFixed(2)}/kg · ${item.carbonPerKg.toStringAsFixed(1)} kg CO₂/kg',
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
    if (_basket.isEmpty) return const SizedBox.shrink();

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
            // Basket items summary
            if (_basket.isNotEmpty)
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
                          Text(
                            item.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
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
                          // Quantity controls
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
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_basket.length} items · £${totalCost.toStringAsFixed(2)} · ${totalCarbon.toStringAsFixed(1)} kg CO₂',
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
}
