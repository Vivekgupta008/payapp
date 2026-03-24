import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/sync_indicator.dart';
import '../../config/theme.dart';

class MerchantDashboard extends StatelessWidget {
  const MerchantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final user = auth.user;
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    // Calculate today's earnings from transactions
    final today = DateTime.now();
    final todayTx = txProvider.allTransactions.where((tx) {
      try {
        final d = DateTime.parse(tx.createdAt);
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      } catch (_) {
        return false;
      }
    }).toList();
    final todayEarnings = todayTx.fold(0.0, (sum, tx) => sum + tx.amount);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user?.fullName ?? "Merchant"} 🏪',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              wallet.isOnline ? 'Online' : 'Offline Mode',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await auth.refreshUser();
              await txProvider.loadLocalTransactions(userId: user?.id);
              if (wallet.isOnline) {
                await txProvider.fetchServerTransactions(isUser: false);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              txProvider.stopSync();
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await auth.refreshUser();
          await txProvider.loadLocalTransactions(userId: user?.id);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Revenue card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Earnings",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${todayTx.length} transactions',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatter.format(todayEarnings),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _MerchantStat(
                        label: 'Total Balance',
                        value: formatter.format(user?.balance ?? 0),
                      ),
                      const SizedBox(width: 24),
                      _MerchantStat(
                        label: 'Pending Sync',
                        value: '${txProvider.pendingCount}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sync indicator
            SyncIndicator(
              isSyncing: txProvider.isSyncing,
              pendingCount: txProvider.pendingCount,
              onSync: wallet.isOnline
                  ? () => txProvider.syncTransactions()
                  : null,
            ),

            // Quick stats
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.payments,
                    label: 'Total Received',
                    value: '${txProvider.allTransactions.length}',
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.cloud_upload,
                    label: 'Pending',
                    value: formatter.format(txProvider.pendingAmount),
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),

            // Recent Transactions
            const SizedBox(height: 24),
            const Text(
              'Recent Payments Received',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            if (txProvider.allTransactions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No payments received',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan customer QR codes to accept payments',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...txProvider.allTransactions.take(10).map((tx) {
                return TransactionTile(
                  transaction: tx,
                  isOutgoing: false, // Merchant receives
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MerchantStat extends StatelessWidget {
  final String label;
  final String value;

  const _MerchantStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
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
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
