import 'package:flutter/material.dart';
import '../config/theme.dart';

class SyncIndicator extends StatelessWidget {
  final bool isSyncing;
  final int pendingCount;
  final VoidCallback? onSync;

  const SyncIndicator({
    super.key,
    required this.isSyncing,
    required this.pendingCount,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0 && !isSyncing) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.warningColor),
              ),
            )
          else
            const Icon(
              Icons.cloud_upload_outlined,
              color: AppTheme.warningColor,
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSyncing
                      ? 'Syncing transactions...'
                      : '$pendingCount transaction${pendingCount > 1 ? "s" : ""} pending',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.warningColor,
                  ),
                ),
                if (!isSyncing)
                  Text(
                    'Will sync when online',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.warningColor.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
          if (!isSyncing && onSync != null)
            TextButton(
              onPressed: onSync,
              child: const Text(
                'Sync Now',
                style: TextStyle(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
