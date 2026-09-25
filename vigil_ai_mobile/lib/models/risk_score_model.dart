class RiskScoreModel {
  final double riskScore;
  final double safetyScore;
  final String riskLevel;
  final List<RiskFactor> factors;
  final String disclaimer;

  RiskScoreModel({
    required this.riskScore,
    required this.safetyScore,
    required this.riskLevel,
    required this.factors,
    required this.disclaimer,
  });

  factory RiskScoreModel.fromJson(Map<String, dynamic> json) {
    var rawFactors = json['factors'] as List? ?? [];
    List<RiskFactor> factorsList = rawFactors.map((f) => RiskFactor.fromJson(f)).toList();

    return RiskScoreModel(
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 5.0,
      safetyScore: (json['safety_score'] as num?)?.toDouble() ?? 95.0,
      riskLevel: json['risk_level'] ?? 'SAFE',
      factors: factorsList,
      disclaimer: json['disclaimer'] ?? '',
    );
  }

  factory RiskScoreModel.initial() {
    return RiskScoreModel(
      riskScore: 8.0,
      safetyScore: 92.0,
      riskLevel: 'SAFE',
      factors: [
        RiskFactor(
          factor: 'Nominal Baseline Monitoring',
          impact: '+5',
          severity: 'LOW',
        )
      ],
      disclaimer: 'AI-assisted risk score. Serves as probabilistic indicator.',
    );
  }
}

class RiskFactor {
  final String factor;
  final String impact;
  final String severity;

  RiskFactor({
    required this.factor,
    required this.impact,
    required this.severity,
  });

  factory RiskFactor.fromJson(Map<String, dynamic> json) {
    return RiskFactor(
      factor: json['factor'] ?? '',
      impact: json['impact'] ?? '',
      severity: json['severity'] ?? 'LOW',
    );
  }
}
