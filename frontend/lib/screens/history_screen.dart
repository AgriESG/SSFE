import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/history_entry.dart';
import '../services/history_store.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

/// Public so HomeShell can force a reload when this tab is selected — it
/// lives inside an IndexedStack, which keeps the widget mounted rather than
/// rebuilding it, so initState alone would only ever show the first load.
class HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final entries = await HistoryStore.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  Future<void> _delete(HistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this analysis?'),
        content: const Text('This only removes it from your history on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await HistoryStore.remove(entry.id);
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummary(),
                      const SizedBox(height: 20),
                      const Text(
                        'Past Analyses',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._entries.map(_buildEntryCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummary() {
    final swapEntries = _entries.where((e) => e.swapsAccepted > 0);
    final totalCostSaved = swapEntries.fold(0.0, (s, e) => s + e.costSaved);
    final totalCarbonSaved = swapEntries.fold(0.0, (s, e) => s + e.carbonSaved);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Cumulative Impact',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryStat(
                  '${_entries.length}',
                  _entries.length == 1 ? 'basket analysed' : 'baskets analysed',
                ),
              ),
              Expanded(
                child: _summaryStat(
                  '£${totalCostSaved.toStringAsFixed(2)}',
                  'saved via swaps',
                ),
              ),
              Expanded(
                child: _summaryStat(
                  '${totalCarbonSaved.toStringAsFixed(1)} kg',
                  'CO₂ saved',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(HistoryEntry entry) {
    final hasSwaps = entry.swapsAccepted > 0;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedDelete02,
          color: AppColors.error,
          size: 20,
        ),
      ),
      confirmDismiss: (_) async {
        await _delete(entry);
        return false; // _delete already reloads; avoid double-removal races.
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                Expanded(
                  child: Text(
                    _formatDate(entry.timestamp),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${entry.itemCount} ${entry.itemCount == 1 ? "item" : "items"}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.itemNames.take(4).join(', ') +
                  (entry.itemNames.length > 4 ? '…' : ''),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _tinyStat(HugeIcons.strokeRoundedCoins01,
                    '£${entry.totalCost.toStringAsFixed(2)}'),
                const SizedBox(width: 14),
                _tinyStat(HugeIcons.strokeRoundedCloud,
                    '${entry.totalCarbon.toStringAsFixed(1)} kg CO₂'),
              ],
            ),
            if (hasSwaps) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${entry.swapsAccepted} ${entry.swapsAccepted == 1 ? "swap" : "swaps"} · '
                  '£${entry.costSaved.abs().toStringAsFixed(2)} ${entry.costSaved >= 0 ? "saved" : "more"} · '
                  '${entry.carbonSaved.abs().toStringAsFixed(1)} kg CO₂ ${entry.carbonSaved >= 0 ? "saved" : "more"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tinyStat(List<List<dynamic>> icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, color: AppColors.textTertiary, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
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
              'No basket analyses yet',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Build and analyse a basket and it will\nshow up here, with a running tally of\nwhat your swaps save you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today, $time';
    if (isYesterday) return 'Yesterday, $time';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
