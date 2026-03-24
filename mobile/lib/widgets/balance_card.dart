import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final double offlineLimit;
  final double offlineAvailable;
  final bool isOnline;
  final VoidCallback? onRequestTokens;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.offlineLimit,
    required this.offlineAvailable,
    required this.isOnline,
    this.onRequestTokens,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            Color(0xFF283593),
            AppTheme.accentColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
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
                'Offline Wallet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppTheme.successColor.withOpacity(0.2)
                      : AppTheme.offlineColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOnline
                        ? AppTheme.successColor.withOpacity(0.5)
                        : AppTheme.offlineColor.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off,
                      size: 14,
                      color: isOnline
                          ? AppTheme.successColor
                          : AppTheme.offlineColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline
                            ? AppTheme.successColor
                            : AppTheme.offlineColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatter.format(offlineAvailable),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const Text(
            'Available Offline Balance',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Limit: ${formatter.format(offlineLimit)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  Text(
                    offlineLimit > 0
                        ? '${((offlineAvailable / offlineLimit) * 100).toStringAsFixed(0)}% remaining'
                        : '0%',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: offlineLimit > 0
                    ? (offlineAvailable / offlineLimit).clamp(0.0, 1.0)
                    : 0,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  offlineAvailable / (offlineLimit > 0 ? offlineLimit : 1) > 0.5
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
          if (onRequestTokens != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRequestTokens,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh Tokens'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
