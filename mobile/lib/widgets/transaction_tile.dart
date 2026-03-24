import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../config/theme.dart';

class TransactionTile extends StatelessWidget {
  final OfflineTransaction transaction;
  final bool isOutgoing;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.isOutgoing = true,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM, hh:mm a');

    DateTime txDate;
    try {
      txDate = DateTime.parse(transaction.createdAt);
    } catch (_) {
      txDate = DateTime.now();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isOutgoing
                      ? AppTheme.errorColor
                      : AppTheme.successColor)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isOutgoing
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: isOutgoing ? AppTheme.errorColor : AppTheme.successColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOutgoing
                      ? 'Paid to ${transaction.receiverName ?? "Merchant"}'
                      : 'Received from ${transaction.receiverName ?? "User"}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatusChip(transaction.status),
                    const SizedBox(width: 8),
                    Text(
                      dateFormatter.format(txDate),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Amount
          Text(
            '${isOutgoing ? "-" : "+"}${formatter.format(transaction.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isOutgoing ? AppTheme.errorColor : AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'pending_offline':
        bgColor = AppTheme.offlineColor.withOpacity(0.1);
        textColor = AppTheme.offlineColor;
        icon = Icons.cloud_off;
        break;
      case 'synced':
        bgColor = AppTheme.warningColor.withOpacity(0.1);
        textColor = AppTheme.warningColor;
        icon = Icons.sync;
        break;
      case 'settled':
        bgColor = AppTheme.successColor.withOpacity(0.1);
        textColor = AppTheme.successColor;
        icon = Icons.check_circle;
        break;
      case 'fraud_flagged':
        bgColor = AppTheme.errorColor.withOpacity(0.1);
        textColor = AppTheme.errorColor;
        icon = Icons.warning;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            OfflineTransaction(
              tokenId: '',
              senderId: '',
              amount: 0,
              nonce: '',
              signature: '',
              status: status,
            ).statusDisplay,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
