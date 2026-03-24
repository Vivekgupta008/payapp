import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../config/theme.dart';

class SettlementScreen extends StatelessWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final wallet = context.watch<WalletProvider>();
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    final pending = txProvider.allTransactions.where((t) => t.isPending).toList();
    final settled = txProvider.allTransactions.where((t) => t.isSettled).toList();
    final flagged = txProvider.allTransactions.where((t) => t.isFlagged).toList();

    final pendingTotal = pending.fold(0.0, (s, t) => s + t.amount);
    final settledTotal = settled.fold(0.0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Settlement'),
        automaticallyImplyLeading: false,
        actions: [
          if (wallet.isOnline)
            TextButton.icon(
              onPressed: txProvider.isSyncing
                  ? null
                  : () => txProvider.syncTransactions(),
              icon: txProvider.isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.sync, color: Colors.white, size: 18),
              label: Text(
                txProvider.isSyncing ? 'Syncing...' : 'Sync All',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Pending Settlement',
                  value: formatter.format(pendingTotal),
                  count: '${pending.length} transactions',
                  color: AppTheme.warningColor,
                  icon: Icons.pending_actions,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Settled',
                  value: formatter.format(settledTotal),
                  count: '${settled.length} transactions',
                  color: AppTheme.successColor,
                  icon: Icons.check_circle,
                ),
              ),
            ],
          ),

          if (flagged.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: AppTheme.errorColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Flagged Transactions',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorColor,
                          ),
                        ),
                        Text(
                          '${flagged.length} transaction(s) under review',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Connection status
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: wallet.isOnline
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.offlineColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  wallet.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: wallet.isOnline
                      ? AppTheme.successColor
                      : AppTheme.offlineColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  wallet.isOnline
                      ? 'Connected - settlements will process automatically'
                      : 'Offline - settlements will process when connected',
                  style: TextStyle(
                    fontSize: 12,
                    color: wallet.isOnline
                        ? AppTheme.successColor
                        : AppTheme.offlineColor,
                  ),
                ),
              ],
            ),
          ),

          // Pending transactions
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Pending Settlement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...pending.map((tx) => TransactionTile(
                  transaction: tx,
                  isOutgoing: false,
                )),
          ],

          // Settled transactions
          if (settled.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Settled Transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...settled.take(20).map((tx) => TransactionTile(
                  transaction: tx,
                  isOutgoing: false,
                )),
          ],

          // Empty state
          if (txProvider.allTransactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No settlements yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      'Accept offline payments to see them here',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String count;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
