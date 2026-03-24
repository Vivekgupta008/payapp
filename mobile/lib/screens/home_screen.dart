import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/transaction_provider.dart';
import 'user/user_dashboard.dart';
import 'user/pay_screen.dart';
import 'user/wallet_screen.dart';
import 'user/history_screen.dart';
import 'merchant/merchant_dashboard.dart';
import 'merchant/accept_payment.dart';
import 'merchant/settlement_screen.dart';
import '../config/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    final txProvider = context.read<TransactionProvider>();

    // Load cached tokens
    await wallet.loadCachedTokens();
    await wallet.checkConnectivity();

    // Load local transactions
    await txProvider.loadLocalTransactions(userId: auth.user?.id);

    // Start background sync
    txProvider.startSync();

    // If online, request fresh tokens
    if (wallet.isOnline) {
      await wallet.requestTokens();
      await txProvider.fetchServerTransactions(isUser: auth.isUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isUser = auth.isUser;

    final userPages = [
      const UserDashboard(),
      const PayScreen(),
      const WalletScreen(),
      const HistoryScreen(),
    ];

    final merchantPages = [
      const MerchantDashboard(),
      const AcceptPaymentScreen(),
      const SettlementScreen(),
    ];

    return Scaffold(
      body: isUser
          ? userPages[_currentIndex.clamp(0, userPages.length - 1)]
          : merchantPages[_currentIndex.clamp(0, merchantPages.length - 1)],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: AppTheme.primaryColor.withOpacity(0.1),
        destinations: isUser
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryColor),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.send_outlined),
                  selectedIcon: Icon(Icons.send, color: AppTheme.primaryColor),
                  label: 'Pay',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor),
                  label: 'Wallet',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history, color: AppTheme.primaryColor),
                  label: 'History',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryColor),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.qr_code_scanner_outlined),
                  selectedIcon: Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                  label: 'Accept',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                  label: 'Settlement',
                ),
              ],
      ),
    );
  }
}
