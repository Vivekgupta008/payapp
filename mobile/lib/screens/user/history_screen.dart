import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/sync_indicator.dart';
import '../../config/theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Transaction History'),
        automaticallyImplyLeading: false,
        actions: [
          if (wallet.isOnline)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () async {
                await txProvider.syncTransactions();
                await txProvider.fetchServerTransactions();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await txProvider.loadLocalTransactions(userId: auth.user?.id);
          if (wallet.isOnline) {
            await txProvider.fetchServerTransactions();
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Sync indicator
            SyncIndicator(
              isSyncing: txProvider.isSyncing,
              pendingCount: txProvider.pendingCount,
              onSync: wallet.isOnline
                  ? () => txProvider.syncTransactions()
                  : null,
            ),

            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Total',
                    value: '${txProvider.allTransactions.length}',
                    icon: Icons.receipt,
                    color: AppTheme.primaryColor,
                  ),
                  _StatItem(
                    label: 'Pending',
                    value: '${txProvider.pendingCount}',
                    icon: Icons.pending,
                    color: AppTheme.warningColor,
                  ),
                  _StatItem(
                    label: 'Settled',
                    value: '${txProvider.allTransactions.where((t) => t.isSettled).length}',
                    icon: Icons.check_circle,
                    color: AppTheme.successColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Transactions
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
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your offline payment history will appear here',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...txProvider.allTransactions.map((tx) {
                return TransactionTile(
                  transaction: tx,
                  isOutgoing: tx.senderId == auth.user?.id,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
