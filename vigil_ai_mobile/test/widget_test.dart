import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigil_ai_mobile/models/risk_score_model.dart';
import 'package:vigil_ai_mobile/models/user_model.dart';

void main() {
  group('VIGIL AI Mobile Core Tests', () {
    test('Calculates Euclidean Acceleration Magnitude accurately', () {
      const double x = 3.0;
      const double y = 4.0;
      const double z = 12.0;
      final double magnitude = sqrt(x * x + y * y + z * z);
      expect(magnitude, equals(13.0));
    });

    test('RiskScoreModel parsing and level checks', () {
      final initial = RiskScoreModel.initial();
      expect(initial.safetyScore, equals(92.0));
      expect(initial.riskLevel, equals('SAFE'));
      expect(initial.factors.isNotEmpty, isTrue);
    });

    test('UserModel JSON deserialization', () {
      final json = {
        'id': 10,
        'full_name': 'Test User',
        'email': 'test@vigilai.com',
        'phone': '+919999999999',
        'role': 'USER',
        'is_active': true,
        'profile': {
          'blood_group': 'B+',
          'emergency_countdown': 5,
          'shake_to_sos': true,
        }
      };

      final user = UserModel.fromJson(json);
      expect(user.id, equals(10));
      expect(user.fullName, equals('Test User'));
      expect(user.profile?.bloodGroup, equals('B+'));
      expect(user.profile?.emergencyCountdown, equals(5));
    });
  });
}
