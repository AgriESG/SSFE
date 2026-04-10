import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedClock01,
                  color: AppColors.primary.withValues(alpha: 0.5),
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your past basket analyses and optimisation\nhistory will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _featureRow(HugeIcons.strokeRoundedChartColumn,
                        'Track your weekly baskets'),
                    const SizedBox(height: 12),
                    _featureRow(HugeIcons.strokeRoundedAnalyticsUp,
                        'See how your scores change'),
                    const SizedBox(height: 12),
                    _featureRow(HugeIcons.strokeRoundedLeaf01,
                        'Monitor cumulative CO₂ savings'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _featureRow(List<List<dynamic>> icon, String text) {
    return Row(
      children: [
        HugeIcon(icon: icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}
