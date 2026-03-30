import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class RiskProfileScreen extends StatefulWidget {
  const RiskProfileScreen({super.key});

  @override
  State<RiskProfileScreen> createState() => _RiskProfileScreenState();
}

class _RiskProfileScreenState extends State<RiskProfileScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  late AnimationController _gaugeCtrl;
  late Animation<double> _gaugeAnim;

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _gaugeAnim =
        CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get('/api/tokens/risk-profile');
      setState(() {
        _data = data;
        _loading = false;
      });
      _gaugeCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        title: const Text('AI Credit Profile',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          )
        ],
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _ProfileBody(data: _data!, gaugeAnim: _gaugeAnim),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final Animation<double> gaugeAnim;

  const _ProfileBody({required this.data, required this.gaugeAnim});

  @override
  Widget build(BuildContext context) {
    final riskScore = (data['risk_score'] as num).toDouble();
    final riskLevel = data['risk_level'] as String;
    final offlineLimit = (data['offline_limit'] as num).toDouble();
    final modelType = data['model_type'] as String;
    final explanation = data['explanation'] as String;
    final features =
        (data['features'] as Map<String, dynamic>).cast<String, dynamic>();

    // Sort features by importance descending
    final sortedFeatures = features.entries.toList()
      ..sort((a, b) {
        final ia = (a.value['importance'] as num).toDouble();
        final ib = (b.value['importance'] as num).toDouble();
        return ib.compareTo(ia);
      });

    return RefreshIndicator(
      onRefresh: () async {
        // bubble up to parent — can't easily call _load here, use key if needed
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Gauge card ──────────────────────────────────────────
          _GaugeCard(
              riskScore: riskScore,
              riskLevel: riskLevel,
              offlineLimit: offlineLimit,
              gaugeAnim: gaugeAnim),
          const SizedBox(height: 16),

          // ── Explanation card ────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.navyBlue.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: AppTheme.navyBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Why this limit?',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E))),
                ]),
                const SizedBox(height: 12),
                Text(explanation,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5)),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology,
                          size: 14, color: AppTheme.navyBlue),
                      const SizedBox(width: 6),
                      Text('Model: $modelType',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.navyBlue,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Feature breakdown ───────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Feature Breakdown',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 4),
                Text(
                  'Bar width = feature importance from the trained model. '
                  'Importance tells how much each signal influenced the risk score.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                ...sortedFeatures.map((e) => _FeatureRow(
                      name: e.key,
                      value: e.value['value'],
                      importance: (e.value['importance'] as num).toDouble(),
                      direction: e.value['direction'] as String,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Limit tiers reference ───────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How limits are assigned',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 12),
                ..._kTiers.map((t) => _TierRow(
                      label: t['label']!,
                      range: t['range']!,
                      limit: t['limit']!,
                      isActive: t['limit'] == '₹${offlineLimit.toInt()}',
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
}

const _kTiers = [
  {'label': 'Very Low Risk', 'range': 'Score < 0.20', 'limit': '₹5000'},
  {'label': 'Low Risk', 'range': '0.20 – 0.40', 'limit': '₹3000'},
  {'label': 'Moderate Risk', 'range': '0.40 – 0.60', 'limit': '₹1500'},
  {'label': 'High Risk', 'range': '0.60 – 0.80', 'limit': '₹500'},
  {'label': 'Very High Risk', 'range': '0.80 – 0.90', 'limit': '₹100'},
  {'label': 'Restricted', 'range': 'Score ≥ 0.90', 'limit': '₹0'},
];

// ── Gauge card ────────────────────────────────────────────────────────────────

class _GaugeCard extends StatelessWidget {
  final double riskScore;
  final String riskLevel;
  final double offlineLimit;
  final Animation<double> gaugeAnim;

  const _GaugeCard({
    required this.riskScore,
    required this.riskLevel,
    required this.offlineLimit,
    required this.gaugeAnim,
  });

  Color get _riskColor {
    if (riskScore < 0.2) return const Color(0xFF00C853);
    if (riskScore < 0.4) return const Color(0xFF64DD17);
    if (riskScore < 0.6) return const Color(0xFFFFAB00);
    if (riskScore < 0.8) return const Color(0xFFFF6D00);
    return const Color(0xFFD50000);
  }

  String get _riskLabel {
    switch (riskLevel) {
      case 'very_low':
        return 'Very Low Risk';
      case 'low':
        return 'Low Risk';
      case 'medium':
        return 'Moderate Risk';
      case 'high':
        return 'High Risk';
      default:
        return 'Very High Risk';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.navyBlue, const Color(0xFF003DA5)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Score gauge
          AnimatedBuilder(
            animation: gaugeAnim,
            builder: (_, __) => SizedBox(
              width: 180,
              height: 100,
              child: CustomPaint(
                painter: _GaugePainter(
                  score: riskScore * gaugeAnim.value,
                  color: _riskColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Score number
          AnimatedBuilder(
            animation: gaugeAnim,
            builder: (_, __) => Text(
              (riskScore * gaugeAnim.value).toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _riskColor.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _riskColor.withAlpha(100)),
            ),
            child: Text(
              _riskLabel,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _riskColor),
            ),
          ),
          const SizedBox(height: 20),
          // Limit pill
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  const Text('Offline Limit',
                      style: TextStyle(fontSize: 12, color: Colors.white54)),
                  Text(
                    '₹${offlineLimit.toInt()}',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              Column(
                children: [
                  const Text('Risk Score',
                      style: TextStyle(fontSize: 12, color: Colors.white54)),
                  Text(
                    '${(riskScore * 100).toStringAsFixed(1)}th percentile',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Semicircle gauge painter ───────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double score; // 0.0–1.0
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final r = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Background arc
    canvas.drawArc(
      rect,
      pi,
      pi,
      false,
      Paint()
        ..color = Colors.white.withAlpha(25)
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Gradient foreground arc
    final sweep = pi * score.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      pi,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: pi,
          endAngle: pi + sweep,
          colors: [const Color(0xFF00C853), color],
        ).createShader(rect)
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Needle dot
    final angle = pi + sweep;
    final dx = cx + r * cos(angle);
    final dy = cy + r * sin(angle);
    canvas.drawCircle(
        Offset(dx, dy),
        8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(dx, dy),
        5,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color;
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final String name;
  final dynamic value;
  final double importance;
  final String direction;

  const _FeatureRow({
    required this.name,
    required this.value,
    required this.importance,
    required this.direction,
  });

  static const _meta = {
    'transaction_count': (
      label: 'Transaction Count',
      icon: Icons.swap_horiz,
      unit: 'txns',
      desc: 'Total payments made on platform',
    ),
    'avg_transaction_amount': (
      label: 'Avg Transaction',
      icon: Icons.trending_up,
      unit: '₹',
      desc: 'Average payment value',
    ),
    'kyc_tier': (
      label: 'KYC Tier',
      icon: Icons.verified_user,
      unit: '/ 3',
      desc: 'Identity verification level (0=None, 3=Premium)',
    ),
    'device_trust_score': (
      label: 'Device Trust',
      icon: Icons.phone_android,
      unit: '/ 1.0',
      desc: 'Device security & behaviour score',
    ),
    'days_since_registration': (
      label: 'Account Age',
      icon: Icons.calendar_today,
      unit: 'days',
      desc: 'How long you have been on the platform',
    ),
    'fraud_flags': (
      label: 'Fraud Flags',
      icon: Icons.flag,
      unit: 'flags',
      desc: 'Number of fraud-related incidents',
    ),
    'total_spent': (
      label: 'Total Spent',
      icon: Icons.account_balance_wallet,
      unit: '₹',
      desc: 'Cumulative transaction volume',
    ),
  };

  String _formatValue() {
    if (name == 'avg_transaction_amount' || name == 'total_spent') {
      return '₹${(value as num).toStringAsFixed(0)}';
    }
    if (name == 'device_trust_score') {
      return (value as num).toStringAsFixed(2);
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta[name];
    final label = m?.label ?? name;
    final icon = m?.icon ?? Icons.circle;
    final desc = m?.desc ?? '';
    final isGood = direction == 'good';
    final Color barColor =
        isGood ? const Color(0xFF00897B) : const Color(0xFFE53935);
    final Color iconBg =
        isGood ? const Color(0xFFE0F2F1) : const Color(0xFFFFEBEE);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: barColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E))),
                    Text(desc,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatValue(),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E)),
                  ),
                  Text(
                    '${(importance * 100).toStringAsFixed(1)}% weight',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Importance bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: importance.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tier reference row ────────────────────────────────────────────────────────

class _TierRow extends StatelessWidget {
  final String label;
  final String range;
  final String limit;
  final bool isActive;

  const _TierRow({
    required this.label,
    required this.range,
    required this.limit,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.navyBlue.withAlpha(15)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppTheme.navyBlue.withAlpha(80)
              : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (isActive)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.arrow_right, size: 16, color: AppTheme.navyBlue),
            ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppTheme.navyBlue : Colors.grey.shade700,
              ),
            ),
          ),
          Text(range,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(width: 12),
          Text(
            limit,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isActive ? AppTheme.navyBlue : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Could not load risk profile',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(error,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
