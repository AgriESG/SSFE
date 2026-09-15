import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// The Price Outlook — the one signal in the app with a stated lead time
/// (engines/feed_cost_pressure.py: validated feed-cost moves that
/// historically show up in farm-gate price 20-26 weeks later). Every other
/// signal in the app describes current conditions; this one describes where
/// things are headed. That is the app's actual point of difference, so it
/// gets a visual identity of its own — a tinted card, not another neutral
/// white one — rather than blending into the row of "how tight is it right
/// now" readings around it. That treatment holds in both simple and
/// detailed mode; only how much explanation text shows underneath changes.
class PriceOutlookCard extends StatelessWidget {
  final FeedCostOutlook outlook;
  final bool isDetailed;

  const PriceOutlookCard({
    super.key,
    required this.outlook,
    this.isDetailed = false,
  });

  @override
  Widget build(BuildContext context) {
    final entries = outlook.pressures.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAnalyticsUp,
                color: AppColors.info,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Price Outlook',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Forward signal',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          if (isDetailed) ...[
            const SizedBox(height: 6),
            const Text(
              "Where a swap ingredient's cost is headed, based on a lead "
              "indicator with a proven historical lag — not a forecast for "
              'everything in your basket.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          ...entries.map(
            (e) => _row(e.key, e.value, outlook.explanations[e.key]),
          ),
          if (isDetailed) ...[
            const SizedBox(height: 4),
            Text(
              'Not yet tested for ${outlook.untestedCategories.join(', ')} — shown '
              'only where a category has a completed backtest.',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String category, ApiFeedCostPressure p, String? explanation) {
    final rising = p.pctChange13w > 0;
    final flat = p.pctChange13w.abs() < 1.0;
    final color = flat
        ? AppColors.textSecondary
        : (rising ? AppColors.warning : AppColors.success);
    final label =
        category.isEmpty ? category : category[0].toUpperCase() + category.substring(1);
    final lo = p.leadHorizonWeeks.isNotEmpty ? p.leadHorizonWeeks.first : 0;
    final hi = p.leadHorizonWeeks.length > 1 ? p.leadHorizonWeeks.last : lo;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: flat
                    ? HugeIcons.strokeRoundedAnalytics01
                    : (rising
                        ? HugeIcons.strokeRoundedArrowUp01
                        : HugeIcons.strokeRoundedArrowDown01),
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'over $lo-$hi wks',
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
          if (isDetailed) ...[
            if (explanation != null && explanation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                explanation,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (p.asOf.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Feed price as of ${p.asOf}',
                style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Compact, tappable teaser for placements that only have room for a glance
/// — Home (basket-independent, a standing market signal) and the Impact
/// Dashboard (before the user has even reached the swap suggestions). Reuses
/// the same info-tinted identity as the full card so the two clearly read as
/// the same feature, just at a different zoom level.
class PriceOutlookTeaser extends StatelessWidget {
  final FeedCostOutlook outlook;
  final VoidCallback? onTap;

  const PriceOutlookTeaser({super.key, required this.outlook, this.onTap});

  @override
  Widget build(BuildContext context) {
    final first = outlook.pressures.values.isNotEmpty
        ? outlook.pressures.values.first
        : null;
    if (first == null) return const SizedBox.shrink();

    final rising = first.pctChange13w > 0;
    final flat = first.pctChange13w.abs() < 1.0;
    final directionColor = flat
        ? AppColors.textSecondary
        : (rising ? AppColors.warning : AppColors.success);
    final category = first.category.isEmpty
        ? first.category
        : first.category[0].toUpperCase() + first.category.substring(1);
    final lo = first.leadHorizonWeeks.isNotEmpty ? first.leadHorizonWeeks.first : 0;
    final hi = first.leadHorizonWeeks.length > 1 ? first.leadHorizonWeeks.last : lo;
    final direction = flat ? 'holding steady' : (rising ? 'firming up' : 'easing');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: flat
                    ? HugeIcons.strokeRoundedAnalytics01
                    : (rising
                        ? HugeIcons.strokeRoundedArrowUp01
                        : HugeIcons.strokeRoundedArrowDown01),
                color: directionColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Price Outlook',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'FORWARD SIGNAL',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: AppColors.info,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$category prices $direction — expect a shelf effect over $lo-$hi wks',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.info,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
