import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/sync_indicator.dart';
import '../../config/theme.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${user?.fullName.split(' ').first ?? "User"} 👋',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'KYC Tier ${user?.kycTier ?? 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await wallet.requestTokens();
              await auth.refreshUser();
              await txProvider.loadLocalTransactions(userId: user?.id);
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
          await wallet.requestTokens();
          await auth.refreshUser();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance Card
            BalanceCard(
              balance: user?.balance ?? 0,
              offlineLimit: user?.offlineLimit ?? wallet.offlineLimit,
              offlineAvailable: wallet.availableBalance,
              isOnline: wallet.isOnline,
              onRequestTokens: wallet.isOnline
                  ? () => wallet.requestTokens()
                  : null,
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

            // Risk Score Card
            if (wallet.riskScore > 0) ...[
              const SizedBox(height: 16),
              _buildRiskCard(wallet),
            ],

            // Quick Actions
            const SizedBox(height: 20),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.send,
                    label: 'Pay',
                    color: AppTheme.secondaryColor,
                    onTap: () {
                      // Navigate to pay tab (index 1)
                      final homeState = context.findAncestorStateOfType<State>();
                      if (homeState != null) {
                        // Use the bottom nav bar
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.account_balance_wallet,
                    label: 'Tokens',
                    color: AppTheme.accentColor,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.sync,
                    label: 'Sync',
                    color: AppTheme.warningColor,
                    onTap: wallet.isOnline
                        ? () => txProvider.syncTransactions()
                        : null,
                  ),
                ),
              ],
            ),

            // Recent Transactions
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (txProvider.allTransactions.isNotEmpty)
                  TextButton(
                    onPressed: () {},
                    child: const Text('See All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (txProvider.allTransactions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No transactions yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Make your first offline payment!',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...txProvider.allTransactions.take(5).map((tx) {
                return TransactionTile(
                  transaction: tx,
                  isOutgoing: tx.senderId == user?.id,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard(WalletProvider wallet) {
    final score = wallet.riskScore;
    Color scoreColor;
    String riskLabel;

    if (score >= 0.7) {
      scoreColor = AppTheme.successColor;
      riskLabel = 'Low Risk';
    } else if (score >= 0.4) {
      scoreColor = AppTheme.warningColor;
      riskLabel = 'Medium Risk';
    } else {
      scoreColor = AppTheme.errorColor;
      riskLabel = 'High Risk';
    }

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
      child: Row(
        children: [
          // Score circle
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score,
                  backgroundColor: scoreColor.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                  strokeWidth: 4,
                ),
                Text(
                  '${(score * 100).toInt()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'AI Risk Score',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        riskLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: scoreColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on transaction history & KYC',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
