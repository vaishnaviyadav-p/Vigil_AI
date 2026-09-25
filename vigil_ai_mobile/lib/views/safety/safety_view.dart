import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/providers/risk_provider.dart';
import 'package:vigil_ai_mobile/providers/sensor_provider.dart';
import 'package:vigil_ai_mobile/services/sensor_service.dart';

class SafetyView extends ConsumerWidget {
  const SafetyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskState = ref.watch(riskProvider);
    final sensorState = ref.watch(sensorProvider);

    final safetyScore = riskState.scoreModel.safetyScore;
    final riskScore = riskState.scoreModel.riskScore;
    final riskLevel = riskState.scoreModel.riskLevel;
    final riskColor = AppColors.getRiskColor(riskLevel);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Risk & Safety Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-evaluate',
            onPressed: () {
              ref.read(riskProvider.notifier).evaluateRisk();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Master Score Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Text('OVERALL SAFETY INDEX', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.0)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${safetyScore.toInt()}',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: riskColor,
                        ),
                      ),
                      const Text(
                        ' / 100',
                        style: TextStyle(fontSize: 20, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: riskColor, width: 1.5),
                    ),
                    child: Text(
                      'ASSESSED RISK: $riskLevel ($riskScore%)',
                      style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Contributing Factors Breakdown
            const Text(
              'AI Contributing Factors',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),

            if (riskState.scoreModel.factors.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                child: const Text('No anomalous risk factors detected.', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: riskState.scoreModel.factors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final f = riskState.scoreModel.factors[i];
                  Color fColor = AppColors.safeGreen;
                  if (f.severity == 'CRITICAL') fColor = AppColors.sosRed;
                  else if (f.severity == 'HIGH') fColor = AppColors.highRiskOrange;
                  else if (f.severity == 'MEDIUM') fColor = AppColors.cautionYellow;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.factor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text('Severity: ${f.severity}', style: TextStyle(fontSize: 11, color: fColor)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: fColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            f.impact,
                            style: TextStyle(color: fColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Weekly Trend Chart
            const Text(
              'Weekly Safety Score Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            Container(
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (v, meta) => Text(
                          '${v.toInt()}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          final idx = v.toInt();
                          if (idx >= 0 && idx < days.length) {
                            return Text(days[idx], style: const TextStyle(color: AppColors.textMuted, fontSize: 10));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 40,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 92),
                        const FlSpot(1, 88),
                        const FlSpot(2, 95),
                        const FlSpot(3, 90),
                        const FlSpot(4, 84),
                        const FlSpot(5, 89),
                        FlSpot(6, safetyScore),
                      ],
                      isCurved: true,
                      color: AppColors.primaryLight,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primaryLight.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Live Telemetry Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Sensor Stream', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricBox('Accel Mag', '${sensorState.currentMagnitude.toStringAsFixed(2)} m/s²'),
                      _metricBox('Mode', sensorState.mode == SensorMode.real ? 'Real Hardware' : 'Simulation'),
                      _metricBox('Activity', sensorState.currentActivity),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Ethical AI Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: Text(
                riskState.scoreModel.disclaimer,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _metricBox(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
