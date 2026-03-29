import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../config/theme.dart';
import '../home_screen.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final user = auth.user;
    final firstName = user?.fullName.split(' ').first ?? 'User';
    final initials = user?.fullName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join() ??
        'U';

    return Scaffold(
      backgroundColor: AppTheme.lightBlue,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── App Bar ───────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.lightBlue,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                expandedHeight: 64,
                automaticallyImplyLeading: false,
                flexibleSpace: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Avatar + menu
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.yellow,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: AppTheme.navyBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppTheme.navyBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.lightBlue, width: 1.5),
                                ),
                                child: const Icon(Icons.menu,
                                    size: 8, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Paytm UPI logo
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Pay',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.navyBlue,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'tm',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.paytmBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              '—से UPI—',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navyBlue,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Icons
                        IconButton(
                          icon: const Icon(Icons.search,
                              color: AppTheme.navyBlue),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline,
                              color: AppTheme.navyBlue),
                          onPressed: () async {
                            await wallet.requestTokens();
                            await auth.refreshUser();
                            await txProvider.loadLocalTransactions(
                                userId: user?.id);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // ── Promo Banner ─────────────────────────────────
                    _PromoBanner(
                      isOnline: wallet.isOnline,
                      offlineLimit: wallet.offlineLimitRemaining,
                      onTap: () => context
                          .findAncestorStateOfType<HomeScreenState>()
                          ?.setTab(1),
                    ),
                    const SizedBox(height: 10),

                    // ── Money Transfer ────────────────────────────────
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Money Transfer ',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                              const Icon(Icons.currency_rupee,
                                  size: 16, color: AppTheme.navyBlue),
                              const Icon(Icons.double_arrow,
                                  size: 14, color: AppTheme.paytmBlue),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.78,
                            children: [
                              _GridItem(
                                icon: Icons.qr_code_scanner,
                                label: 'Scan & Pay',
                                color: AppTheme.paytmBlue,
                                onTap: () => context
                                    .findAncestorStateOfType<HomeScreenState>()
                                    ?.setTab(1),
                              ),
                              _GridItem(
                                icon: Icons.smartphone,
                                label: 'To Mobile',
                                color: const Color(0xFF5C6BC0),
                              ),
                              _GridItem(
                                icon: Icons.account_balance,
                                label: 'To Bank A/c',
                                color: const Color(0xFF26A69A),
                              ),
                              _GridItem(
                                icon: Icons.receipt_long,
                                label: 'Balance & History',
                                color: const Color(0xFF8D6E63),
                                badge: 'Passbook',
                                badgeColor: AppTheme.yellow,
                                onTap: () => context
                                    .findAncestorStateOfType<HomeScreenState>()
                                    ?.setTab(3),
                              ),
                              // ── OFFLINE PAYMENT (our feature) ──────
                              _GridItem(
                                icon: Icons.offline_bolt,
                                label: 'Pay Offline',
                                color: AppTheme.orange,
                                badge: 'New',
                                badgeColor: AppTheme.red,
                                onTap: () => context
                                    .findAncestorStateOfType<HomeScreenState>()
                                    ?.setTab(1),
                              ),
                              _GridItem(
                                icon: Icons.sync_alt,
                                label: 'To Self Account',
                                color: const Color(0xFF7E57C2),
                              ),
                              _GridItem(
                                icon: Icons.download_rounded,
                                label: 'Receive Money',
                                color: AppTheme.green,
                                badge: '⚡Instant',
                                badgeColor: AppTheme.yellow,
                              ),
                              _GridItem(
                                icon: Icons.card_giftcard,
                                label: 'Send a Gift Voucher',
                                color: AppTheme.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── My Paytm ─────────────────────────────────────
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'My Paytm',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${user?.email.split('@').first ?? 'user'}@paytm',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Balances row
                          Row(
                            children: [
                              _BalancePill(
                                label:
                                    'Rs ${(user?.balance ?? 0).toStringAsFixed(0)}',
                                color: AppTheme.green,
                              ),
                              const SizedBox(width: 8),
                              _BalancePill(
                                label:
                                    '₹${wallet.offlineLimitRemaining.toStringAsFixed(0)} offline',
                                color: wallet.isOnline
                                    ? AppTheme.navyBlue
                                    : AppTheme.orange,
                                icon: wallet.isOnline
                                    ? null
                                    : Icons.wifi_off,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // My Paytm items grid
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              _GridItem(
                                icon: Icons.account_balance_wallet,
                                label: 'Paytm Wallet',
                                color: AppTheme.navyBlue,
                                onTap: () => context
                                    .findAncestorStateOfType<HomeScreenState>()
                                    ?.setTab(2),
                              ),
                              _GridItem(
                                icon: Icons.offline_bolt,
                                label: 'Offline Limit',
                                color: AppTheme.orange,
                                badge:
                                    '₹${wallet.offlineLimitRemaining.toStringAsFixed(0)}',
                                badgeColor: AppTheme.navyBlue,
                                onTap: () => context
                                    .findAncestorStateOfType<HomeScreenState>()
                                    ?.setTab(1),
                              ),
                              _GridItem(
                                icon: Icons.people,
                                label: 'Refer & Earn',
                                color: const Color(0xFF26A69A),
                              ),
                              _GridItem(
                                icon: Icons.account_balance,
                                label: 'Personal Loan',
                                color: const Color(0xFF5C6BC0),
                                badge: '₹3Lakh Tak',
                                badgeColor: AppTheme.yellow,
                              ),
                            ],
                          ),

                          // Pending sync notice
                          if (txProvider.pendingCount > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppTheme.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.sync,
                                      size: 16, color: AppTheme.orange),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${txProvider.pendingCount} offline payment${txProvider.pendingCount > 1 ? 's' : ''} pending sync',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (wallet.isOnline)
                                    GestureDetector(
                                      onTap: () =>
                                          txProvider.syncTransactions(),
                                      child: Text(
                                        'Sync now',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.navyBlue,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Recharge & Bill Payments ──────────────────────
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Recharge & Bill Payments',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'My Bills',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.paytmBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: const [
                              _GridItem(
                                  icon: Icons.smartphone,
                                  label: 'Mobile\nRecharge',
                                  color: Color(0xFF5C6BC0)),
                              _GridItem(
                                  icon: Icons.bolt,
                                  label: 'Electricity',
                                  color: Color(0xFFFFA726)),
                              _GridItem(
                                  icon: Icons.wifi,
                                  label: 'Broadband',
                                  color: Color(0xFF26A69A)),
                              _GridItem(
                                  icon: Icons.local_gas_station,
                                  label: 'Gas',
                                  color: Color(0xFFEF5350)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Recent Transactions ───────────────────────────
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Recent Transactions',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                              const Spacer(),
                              if (txProvider.allTransactions.isNotEmpty)
                                GestureDetector(
                                  onTap: () => context
                                      .findAncestorStateOfType<
                                          HomeScreenState>()
                                      ?.setTab(3),
                                  child: const Text(
                                    'See All',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.paytmBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (txProvider.allTransactions.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_outlined,
                                        size: 40,
                                        color: Colors.grey.shade300),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No transactions yet',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...txProvider.allTransactions
                                .take(5)
                                .map((tx) => TransactionTile(
                                      transaction: tx,
                                      isOutgoing:
                                          tx.senderId == user?.id,
                                    )),
                        ],
                      ),
                    ),

                    // Bottom padding for FAB
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),

          // ── Floating "Scan Any QR" button ─────────────────────────
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => context
                    .findAncestorStateOfType<HomeScreenState>()
                    ?.setTab(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.navyBlue,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.navyBlue.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.qr_code_scanner,
                          color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Scan Any QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _PromoBanner extends StatelessWidget {
  final bool isOnline;
  final double offlineLimit;
  final VoidCallback onTap;

  const _PromoBanner({
    required this.isOnline,
    required this.offlineLimit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.offline_bolt,
                            size: 12, color: AppTheme.paytmBlue),
                        const SizedBox(width: 4),
                        const Text(
                          'Offline Payments',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.navyBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pay without internet.\nAlways.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navyBlue,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.navyBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pay Offline →',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'T&C Apply',
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
            ),
            // Right side — big limit display
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₹${offlineLimit.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                  Text(
                    isOnline ? 'available' : 'offline',
                    style: TextStyle(
                      fontSize: 10,
                      color: isOnline ? AppTheme.paytmBlue : AppTheme.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 14,
                    color: isOnline ? AppTheme.paytmBlue : AppTheme.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const _GridItem({
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
    this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              if (badge != null)
                Positioned(
                  top: -6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor ?? AppTheme.yellow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _BalancePill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
