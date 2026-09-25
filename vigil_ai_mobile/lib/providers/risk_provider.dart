import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';
import 'package:vigil_ai_mobile/models/risk_score_model.dart';

class RiskState {
  final RiskScoreModel scoreModel;
  final bool isEvaluating;
  final List<double> weeklyTrend;

  RiskState({
    required this.scoreModel,
    this.isEvaluating = false,
    this.weeklyTrend = const [92, 88, 95, 90, 84, 89, 92],
  });

  RiskState copyWith({
    RiskScoreModel? scoreModel,
    bool? isEvaluating,
    List<double>? weeklyTrend,
  }) {
    return RiskState(
      scoreModel: scoreModel ?? this.scoreModel,
      isEvaluating: isEvaluating ?? this.isEvaluating,
      weeklyTrend: weeklyTrend ?? this.weeklyTrend,
    );
  }
}

class RiskNotifier extends StateNotifier<RiskState> {
  final ApiClient _api = ApiClient();

  RiskNotifier() : super(RiskState(scoreModel: RiskScoreModel.initial()));

  Future<void> evaluateRisk({
    bool isSos = false,
    bool isFall = false,
    bool isAnomaly = false,
    double anomalyScore = 0.0,
    bool isDistressVoice = false,
    String? voiceKeyword,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(isEvaluating: true);
    try {
      final res = await _api.dio.post('/risk/evaluate', data: {
        'is_sos': isSos,
        'is_fall': isFall,
        'is_anomaly': isAnomaly,
        'anomaly_score': anomalyScore,
        'is_distress_voice': isDistressVoice,
        'voice_keyword': voiceKeyword,
        'latitude': latitude,
        'longitude': longitude,
      });

      if (res.data['success'] == true) {
        final model = RiskScoreModel.fromJson(res.data['data']);
        state = state.copyWith(
          scoreModel: model,
          isEvaluating: false,
        );
      }
    } catch (_) {
      // Local fallback calculation so presentation never halts
      double computedRisk = 5.0;
      List<RiskFactor> factors = [];

      if (isSos) {
        computedRisk += 70.0;
        factors.add(RiskFactor(factor: 'Manual SOS Triggered', impact: '+70', severity: 'CRITICAL'));
      }
      if (isFall) {
        computedRisk += 35.0;
        factors.add(RiskFactor(factor: 'Possible Fall Impact Event', impact: '+35', severity: 'HIGH'));
      }
      if (isAnomaly) {
        computedRisk += 25.0;
        factors.add(RiskFactor(factor: 'Abnormal Sensor Movement', impact: '+25', severity: 'MEDIUM'));
      }
      if (isDistressVoice) {
        computedRisk += 30.0;
        factors.add(RiskFactor(factor: 'Distress Keyword ("HELP")', impact: '+30', severity: 'HIGH'));
      }

      computedRisk = computedRisk.clamp(0.0, 100.0);
      String level = 'SAFE';
      if (computedRisk > 85) level = 'CRITICAL';
      else if (computedRisk > 70) level = 'HIGH';
      else if (computedRisk > 50) level = 'MEDIUM';
      else if (computedRisk > 30) level = 'LOW';

      state = state.copyWith(
        scoreModel: RiskScoreModel(
          riskScore: computedRisk,
          safetyScore: 100.0 - computedRisk,
          riskLevel: level,
          factors: factors.isEmpty ? [RiskFactor(factor: 'Nominal Baseline Monitoring', impact: '+5', severity: 'LOW')] : factors,
          disclaimer: 'AI-assisted risk score. Serves as probabilistic indicator.',
        ),
        isEvaluating: false,
      );
    }
  }

  void resetToNominal() {
    state = state.copyWith(scoreModel: RiskScoreModel.initial());
  }
}

final riskProvider = StateNotifierProvider<RiskNotifier, RiskState>((ref) {
  return RiskNotifier();
});
