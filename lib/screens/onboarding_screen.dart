import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../models/user_preferences.dart';
import '../widgets/adaptive_widgets.dart';
import 'basket_input_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _preferences = UserPreferences();

  final _allergyOptions = [
    'Dairy',
    'Gluten',
    'Nuts',
    'Soy',
    'Eggs',
    'Shellfish',
    'Fish',
  ];

  final _dislikeOptions = [
    'Tofu',
    'Mushrooms',
    'Lentils',
    'Broccoli',
    'Spinach',
    'Chickpeas',
    'Beans',
    'Oats',
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToBasketInput();
    }
  }

  void _navigateToBasketInput() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BasketInputScreen(preferences: _preferences),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    _buildProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'Step ${_currentPage + 1} of 4',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildDietPage(),
                    _buildAllergiesPage(),
                    _buildGoalsPage(),
                    _buildHouseholdPage(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    AdaptiveButton(
                      label: _currentPage < 3 ? 'Continue' : 'Start Optimising',
                      onPressed: _nextPage,
                      isFullWidth: true,
                      hugeIcon: _currentPage < 3
                          ? HugeIcons.strokeRoundedArrowRight01
                          : HugeIcons.strokeRoundedLeaf01,
                    ),
                    if (_currentPage > 0) ...[
                      const SizedBox(height: 8),
                      AdaptiveButton(
                        label: 'Back',
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        },
                        isPrimary: false,
                        isFullWidth: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: i <= _currentPage
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
        );
      }),
    );
  }

  // ── Page 1: Diet Type ──
  Widget _buildDietPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // const Text('🥗', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'What\'s your\ndiet type?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This helps us tailor your food suggestions and ensure all recommendations fit your lifestyle.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ...DietType.values.map((diet) => _buildDietOption(diet)),
        ],
      ),
    );
  }

  Widget _buildDietOption(DietType diet) {
    final isSelected = _preferences.dietType == diet;
    final Map<DietType, Map<String, String>> dietInfo = {
      DietType.omnivore: {
        'emoji': '🍖',
        'title': 'Omnivore',
        'desc': 'I eat everything — meat, fish, dairy, and plants',
      },
      DietType.vegetarian: {
        'emoji': '🥚',
        'title': 'Vegetarian',
        'desc': 'No meat or fish, but dairy and eggs are fine',
      },
      DietType.vegan: {
        'emoji': '🌱',
        'title': 'Vegan',
        'desc': 'Fully plant-based — no animal products',
      },
    };
    final info = dietInfo[diet]!;

    return GestureDetector(
      onTap: () => setState(() => _preferences.dietType = diet),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Text(info['emoji']!, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info['title']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info['desc']!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 2: Allergies & Dislikes ──
  Widget _buildAllergiesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'Any allergies\nor dislikes?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll exclude these from your recommendations so every suggestion works for you.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ALLERGIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allergyOptions.map((a) {
              final isSelected = _preferences.allergies.contains(a);
              return FilterChip(
                label: Text(a),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _preferences.allergies.add(a);
                    } else {
                      _preferences.allergies.remove(a);
                    }
                  });
                },
                selectedColor: AppColors.error.withValues(alpha: 0.15),
                checkmarkColor: AppColors.error,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.error : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'FOOD DISLIKES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dislikeOptions.map((d) {
              final isSelected = _preferences.dislikes.contains(d);
              return FilterChip(
                label: Text(d),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _preferences.dislikes.add(d);
                    } else {
                      _preferences.dislikes.remove(d);
                    }
                  });
                },
                selectedColor: AppColors.warning.withValues(alpha: 0.15),
                checkmarkColor: AppColors.warning,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.warning : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Page 3: Budget, Sustainability, Nutrition ──
  Widget _buildGoalsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // const Text('🎯', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'Set your\npriorities',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us what matters most — we\'ll balance cost, sustainability, and nutrition.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          _buildSelectorSection(
            '💰',
            'Budget Preference',
            BudgetPreference.values,
            _preferences.budgetPreference,
            (v) => setState(() => _preferences.budgetPreference = v),
            ['Budget-friendly', 'Moderate', 'Premium'],
          ),
          const SizedBox(height: 20),
          _buildSelectorSection(
            '🌍',
            'Sustainability Priority',
            SustainabilityPriority.values,
            _preferences.sustainabilityPriority,
            (v) => setState(() => _preferences.sustainabilityPriority = v),
            ['Low', 'Medium', 'High'],
          ),
          const SizedBox(height: 20),
          // const Text(
          //   '🥗  Nutrition Goal',
          //   style: TextStyle(
          //     fontSize: 16,
          //     fontWeight: FontWeight.w600,
          //     color: AppColors.textPrimary,
          //   ),
          // ),
          const SizedBox(height: 12),
          ...NutritionGoal.values.map((goal) {
            final isSelected = _preferences.nutritionGoal == goal;
            final labels = {
              NutritionGoal.balanced: 'Balanced Diet',
              NutritionGoal.highProtein: 'High Protein',
              NutritionGoal.lowCarb: 'Low Carb',
              NutritionGoal.highFibre: 'High Fibre',
            };
            return GestureDetector(
              onTap: () => setState(() => _preferences.nutritionGoal = goal),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        labels[goal]!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                        color: AppColors.primary,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectorSection<T>(
    String emoji,
    String title,
    List<T> values,
    T currentValue,
    ValueChanged<T> onChanged,
    List<String> labels,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(
        //   '$emoji  $title',
        //   style: const TextStyle(
        //     fontSize: 16,
        //     fontWeight: FontWeight.w600,
        //     color: AppColors.textPrimary,
        //   ),
        // ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: List.generate(values.length, (i) {
              final isSelected = values[i] == currentValue;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(values[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Page 4: Household Size ──
  Widget _buildHouseholdPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'Household\nsize',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How many people are you shopping for? We\'ll scale recommendations accordingly.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: _preferences.householdSize.toDouble(),
                  ),
                  duration: const Duration(milliseconds: 300),
                  builder: (_, value, __) {
                    return Text(
                      value.round().toString(),
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        height: 1,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  _preferences.householdSize == 1 ? 'person' : 'people',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepperButton(
                      icon: HugeIcons.strokeRoundedRemove01,
                      onTap: () {
                        if (_preferences.householdSize > 1)
                          setState(() => _preferences.householdSize--);
                      },
                      enabled: _preferences.householdSize > 1,
                    ),
                    const SizedBox(width: 40),
                    _buildStepperButton(
                      icon: HugeIcons.strokeRoundedAdd01,
                      onTap: () {
                        if (_preferences.householdSize < 10)
                          setState(() => _preferences.householdSize++);
                      },
                      enabled: _preferences.householdSize < 10,
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                _buildPreferenceSummary(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required List<List<dynamic>> icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            color: enabled ? AppColors.primary : AppColors.textTertiary,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildPreferenceSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Profile Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow('Diet', _preferences.dietTypeLabel),
          _summaryRow('Budget', _preferences.budgetLabel),
          _summaryRow('Sustainability', _preferences.sustainabilityLabel),
          _summaryRow('Nutrition', _preferences.nutritionGoalLabel),
          _summaryRow(
            'Household',
            '${_preferences.householdSize} ${_preferences.householdSize == 1 ? "person" : "people"}',
          ),
          if (_preferences.allergies.isNotEmpty)
            _summaryRow('Allergies', _preferences.allergies.join(', ')),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
