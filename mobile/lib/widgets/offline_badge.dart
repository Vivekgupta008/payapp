import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/offline_limit_service.dart';

class OfflineBadge extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;

  const OfflineBadge({
    super.key,
    required this.isOnline,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? AppTheme.successColor : AppTheme.offlineColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? AppTheme.successColor : AppTheme.offlineColor)
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (pendingCount > 0 && !isOnline) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pendingCount pending',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Prominent card showing the blob-based offline credit limit from SharedPrefs.
/// Spec requirement: "Offline limit: ₹1,450 available" on the home screen.
class OfflineLimitCard extends StatelessWidget {
  final bool isOnline;

  const OfflineLimitCard({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: _fetchLimits(),
      builder: (context, snapshot) {
        final available = snapshot.data?['available'] ?? 0.0;
        final total = snapshot.data?['total'] ?? 0.0;
        final isValid = snapshot.data != null;

        final pct = total > 0 ? (available / total).clamp(0.0, 1.0) : 0.0;
        final color = pct > 0.5
            ? AppTheme.successColor
            : pct > 0.2
                ? AppTheme.warningColor
                : AppTheme.errorColor;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              Icon(
                isOnline ? Icons.credit_score : Icons.credit_card_off,
                color: isValid ? color : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isValid
                          ? 'Offline limit: ₹${available.toStringAsFixed(0)} available'
                          : 'Offline limit not set — go online to fetch',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isValid ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    if (isValid && total > 0) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, double>> _fetchLimits() async {
    final svc = OfflineLimitService();
    final available = await svc.getAvailableLimit();
    final total = await svc.getTotalLimit();
    return {'available': available, 'total': total};
  }
}
