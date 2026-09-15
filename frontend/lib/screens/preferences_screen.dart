import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../models/user_preferences.dart';
import '../widgets/adaptive_widgets.dart';
import '../services/preferences_store.dart';

class PreferencesScreen extends StatefulWidget {
  final UserPreferences preferences;

  const PreferencesScreen({super.key, required this.preferences});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen>
    with SingleTickerProviderStateMixin {
  late UserPreferences _prefs;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _hasChanges = false;

  final _allergyOptions = [
    'Dairy',
    'Lactose Intolerant',
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

  @override
  void initState() {
    super.initState();
    _prefs = UserPreferences(
      dietType: widget.preferences.dietType,
      allergies: List<String>.from(widget.preferences.allergies),
      dislikes: List<String>.from(widget.preferences.dislikes),
      budgetPreference: widget.preferences.budgetPreference,
      sustainabilityPriority: widget.preferences.sustainabilityPriority,
      nutritionGoal: widget.preferences.nutritionGoal,
      householdSize: widget.preferences.householdSize,
      detailLevel: widget.preferences.detailLevel,
    );
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  void _saveAndPop() {
    widget.preferences.dietType = _prefs.dietType;
    widget.preferences.allergies
      ..clear()
      ..addAll(_prefs.allergies);
    widget.preferences.dislikes
      ..clear()
      ..addAll(_prefs.dislikes);
    widget.preferences.budgetPreference = _prefs.budgetPreference;
    widget.preferences.sustainabilityPriority = _prefs.sustainabilityPriority;
    widget.preferences.nutritionGoal = _prefs.nutritionGoal;
    widget.preferences.householdSize = _prefs.householdSize;
    widget.preferences.detailLevel = _prefs.detailLevel;
    PreferencesStore.save(widget.preferences);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Preferences saved ✓'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveAndPop,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 28),

              _buildSectionTitle('🍽️', 'Diet Type'),
              const SizedBox(height: 12),
              ...DietType.values.map(_buildDietOption),
              const SizedBox(height: 24),

              _buildSectionTitle('💰', 'Budget Preference'),
              const SizedBox(height: 12),
              _buildSegmentedSelector<BudgetPreference>(
                BudgetPreference.values,
                _prefs.budgetPreference,
                (v) {
                  setState(() => _prefs.budgetPreference = v);
                  _markChanged();
                },
                ['Save Money', 'Balanced', 'Premium'],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('🌍', 'Sustainability Priority'),
              const SizedBox(height: 12),
              _buildSegmentedSelector<SustainabilityPriority>(
                SustainabilityPriority.values,
                _prefs.sustainabilityPriority,
                (v) {
                  setState(() => _prefs.sustainabilityPriority = v);
                  _markChanged();
                },
                ['Low', 'Balanced', 'High'],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('💪', 'Nutrition Goal'),
              const SizedBox(height: 12),
              _buildSegmentedSelector<NutritionGoal>(
                NutritionGoal.values,
                _prefs.nutritionGoal,
                (v) {
                  setState(() => _prefs.nutritionGoal = v);
                  _markChanged();
                },
                ['Balanced', 'High Protein', 'Low Carb', 'High Fibre'],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('👥', 'Household Size'),
              const SizedBox(height: 12),
              _buildHouseholdStepper(),
              const SizedBox(height: 24),

              _buildSectionTitle('🔍', 'Insight Detail'),
              const SizedBox(height: 4),
              const Text(
                'How much depth to show for UK supply and optimiser data.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _buildSegmentedSelector<DetailLevel>(
                DetailLevel.values,
                _prefs.detailLevel,
                (v) {
                  setState(() => _prefs.detailLevel = v);
                  _markChanged();
                },
                ['Simple', 'Detailed'],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('⚠️', 'Allergies'),
              const SizedBox(height: 12),
              _buildChipGroup(
                _allergyOptions,
                _prefs.allergies,
                AppColors.error,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('🚫', 'Food Dislikes'),
              const SizedBox(height: 12),
              _buildChipGroup(
                _dislikeOptions,
                _prefs.dislikes,
                AppColors.warning,
              ),
              const SizedBox(height: 32),

              AdaptiveButton(
                label: _hasChanges ? 'Save Changes' : 'No Changes',
                onPressed: _hasChanges ? _saveAndPop : null,
                isFullWidth: true,
                hugeIcon: HugeIcons.strokeRoundedTick02,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your Preferences',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Update your diet, budget, and sustainability goals',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDietOption(DietType diet) {
    final isSelected = _prefs.dietType == diet;
    final Map<DietType, Map<String, String>> dietInfo = {
      DietType.omnivore: {
        'emoji': '🍖',
        'title': 'Omnivore',
        'desc': 'Meat, fish, dairy, and plants',
      },
      DietType.pescatarian: {
        'emoji': '🐟',
        'title': 'Pescatarian',
        'desc': 'Fish, dairy, eggs, and plants',
      },
      DietType.vegetarian: {
        'emoji': '🥚',
        'title': 'Vegetarian',
        'desc': 'No meat or fish',
      },
      DietType.vegan: {
        'emoji': '🌱',
        'title': 'Vegan',
        'desc': 'Fully plant-based',
      },
    };
    final info = dietInfo[diet]!;

    return GestureDetector(
      onTap: () {
        setState(() => _prefs.dietType = diet);
        _markChanged();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(info['emoji']!, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info['title']!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    info['desc']!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 22,
              height: 22,
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
                      size: 12,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedSelector<T>(
    List<T> values,
    T currentValue,
    ValueChanged<T> onChanged,
    List<String> labels,
  ) {
    return Container(
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
                  color:
                      isSelected ? AppColors.surface : Colors.transparent,
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
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
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
    );
  }

  Widget _buildHouseholdStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (_prefs.householdSize > 1) {
                setState(() => _prefs.householdSize--);
                _markChanged();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _prefs.householdSize > 1
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _prefs.householdSize > 1
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedRemove01,
                  color: _prefs.householdSize > 1
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Column(
            children: [
              Text(
                '${_prefs.householdSize}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              Text(
                _prefs.householdSize == 1 ? 'person' : 'people',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: () {
              if (_prefs.householdSize < 10) {
                setState(() => _prefs.householdSize++);
                _markChanged();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _prefs.householdSize < 10
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _prefs.householdSize < 10
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  color: _prefs.householdSize < 10
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipGroup(
    List<String> options,
    List<String> selected,
    Color color,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return FilterChip(
          label: Text(opt),
          selected: isSelected,
          onSelected: (sel) {
            setState(() {
              if (sel) {
                selected.add(opt);
              } else {
                selected.remove(opt);
              }
            });
            _markChanged();
          },
          selectedColor: color.withValues(alpha: 0.15),
          checkmarkColor: color,
          labelStyle: TextStyle(
            color: isSelected ? color : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      }).toList(),
    );
  }
}
