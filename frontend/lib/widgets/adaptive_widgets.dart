import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import 'dart:io' show Platform;

bool get isIOS {
  try {
    return Platform.isIOS;
  } catch (_) {
    return false;
  }
}

/// Adaptive button that uses platform-appropriate styling
class AdaptiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isFullWidth;
  final List<List<dynamic>>? hugeIcon;

  const AdaptiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.isFullWidth = false,
    this.hugeIcon,
  });

  @override
  Widget build(BuildContext context) {
    final button = isPrimary
        ? ElevatedButton(
            onPressed: onPressed,
            child: Row(
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hugeIcon != null) ...[
                  HugeIcon(icon: hugeIcon!, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            child: Row(
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hugeIcon != null) ...[
                  HugeIcon(icon: hugeIcon!, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
          );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Metric card for showing impact values
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final List<List<dynamic>> hugeIcon;
  final Color color;
  final String? changeText;
  final bool isPositive;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.hugeIcon,
    required this.color,
    this.changeText,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(icon: hugeIcon, color: color, size: 20),
              ),
              const Spacer(),
              if (changeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isPositive ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    changeText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Substitution card showing original → replacement
class SubstitutionCard extends StatelessWidget {
  final String originalName;
  final String originalEmoji;
  final String replacementName;
  final String replacementEmoji;
  final String reason;

  /// Real deltas per kilogram of product, or null when the underlying figure
  /// is missing. These are NOT the optimiser's score deltas: those are 0-100
  /// normalised values, and an earlier version rendered them with "kg CO2" and
  /// "£" labels, so a swap shown as "-58.9 kg CO2" was really 58.9 environment
  /// points. A chip that names a unit the number does not have is worse than
  /// no chip, so null means nothing is drawn.
  final double? carbonSaved;
  final double? costSaved;
  final double? supplyStability;
  final double? realismScore;
  final int? paretoRank;
  final bool isLowRealism;

  /// Whether to show the optimiser's Pareto rank badge ("#2 Rank"). That
  /// number means little without knowing what a Pareto frontier is, so it is
  /// opt-in via the user's detail-level preference rather than shown on every
  /// card by default.
  final bool showRank;

  /// Whether the user has explicitly accepted this swap. Swaps start
  /// unapplied — nothing changes in the basket until this is true — so the
  /// card needs its own visible confirmation rather than leaving the user to
  /// scroll down and check the basket list to find out.
  final bool accepted;

  const SubstitutionCard({
    super.key,
    required this.originalName,
    required this.originalEmoji,
    required this.replacementName,
    required this.replacementEmoji,
    required this.reason,
    this.carbonSaved,
    this.costSaved,
    this.supplyStability,
    this.realismScore,
    this.paretoRank,
    this.isLowRealism = false,
    this.showRank = false,
    this.accepted = false,
  });

  // ---------------------------------------------------------------------------
  // Supply stability badge.
  //
  // Supply is the distinguishing dimension of this product, and until now it
  // was claimed in the headers of the impact screens and invisible on every
  // individual recommendation. supplyStability was already being passed into
  // this card and simply never drawn.
  //
  // Two rules govern when it shows:
  //
  //   The pipeline returns exactly 0.5 for a food with no published stock
  //   series. That is absent data, not a mid-range reading, and must never be
  //   rendered as a measurement.
  //
  //   Unremarkable readings stay quiet. A chip on every card saying "56%
  //   supply" is noise, and it dilutes the cards where supply genuinely
  //   distinguished the swap.
  //
  // The chip carries words rather than a percentage because the rationale
  // string already states both figures, e.g. "steadier UK supply (0.64 vs
  // 0.57)". Duplicating the number would add nothing; a scannable label does.
  // ---------------------------------------------------------------------------
  static const double _neutralStability = 0.5;
  static const double _neutralEpsilon = 0.001;
  static const double _steadyThreshold = 0.60;
  static const double _tightThreshold = 0.40;

  // Movements below these are rounding rather than change, and a chip reading
  // "−0.0 kg CO₂" is worse than no chip at all.
  static const double _carbonBand = 0.05;
  static const double _costBand = 0.01;

  bool get _hasSupplyData =>
      supplyStability != null &&
      (supplyStability! - _neutralStability).abs() > _neutralEpsilon;

  Widget? _supplyChip() {
    if (!_hasSupplyData) return null;
    final v = supplyStability!;
    if (v >= _steadyThreshold) {
      return _intelligenceMarker(
        'Steadier supply',
        HugeIcons.strokeRoundedPlant02,
        AppColors.success,
      );
    }
    if (v <= _tightThreshold) {
      return _intelligenceMarker(
        'Tighter supply',
        HugeIcons.strokeRoundedPlant02,
        AppColors.warning,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // A Pareto-optimal swap is undominated, not better on every objective, so
    // it can legitimately give ground somewhere. The previous version only
    // drew a chip when the value was positive, which meant a swap that raised
    // carbon or cost showed nothing at all in that slot and the trade-off was
    // invisible.
    final chips = <Widget>[];

    final carbon = carbonSaved;
    if (carbon != null && carbon.abs() >= _carbonBand) {
      chips.add(_savingsChip(
        '${carbon > 0 ? "−" : "+"}'
        '${carbon.abs().toStringAsFixed(1)} kg CO₂/kg',
        carbon > 0 ? AppColors.carbonColor : AppColors.warning,
      ));
    }
    final cost = costSaved;
    if (cost != null && cost.abs() >= _costBand) {
      chips.add(_savingsChip(
        '${cost > 0 ? "−" : "+"}£${cost.abs().toStringAsFixed(2)}/kg',
        cost > 0 ? AppColors.costColor : AppColors.warning,
      ));
    }
    final supply = _supplyChip();
    if (supply != null) chips.add(supply);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accepted
            ? AppColors.success.withValues(alpha: 0.04)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accepted
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.border.withValues(alpha: 0.5),
          width: accepted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Original
              Expanded(
                child: Row(
                  children: [
                    Text(originalEmoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        originalName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: AppColors.success,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              // Replacement
              Expanded(
                child: Row(
                  children: [
                    Text(
                      replacementEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        replacementName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Reason
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Wrap rather than Row: with the supply chip added, three chips plus
          // the rank marker overflow a narrow screen.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (accepted)
                _intelligenceMarker(
                  'Accepted',
                  HugeIcons.strokeRoundedTick02,
                  AppColors.success,
                ),
              ...chips,
              if (paretoRank != null && showRank)
                _intelligenceMarker(
                  '#$paretoRank Rank',
                  HugeIcons.strokeRoundedTarget02,
                  AppColors.primary,
                ),
              if (isLowRealism)
                _intelligenceMarker(
                  'Stretch',
                  HugeIcons.strokeRoundedAlertCircle,
                  AppColors.warning,
                ),
            ],
          ),
          if (!accepted) ...[
            const SizedBox(height: 8),
            Text(
              'Tap to review and accept this swap',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _intelligenceMarker(
    String text,
    List<List<dynamic>> icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.8),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _savingsChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Section header
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Animated progress indicator
class ImpactProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color color;
  final double height;

  const ImpactProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}
