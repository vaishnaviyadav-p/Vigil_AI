import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigil_ai_mobile/models/risk_score_model.dart';
import 'package:vigil_ai_mobile/models/user_model.dart';
import 'package:vigil_ai_mobile/models/emergency_model.dart';
import 'package:vigil_ai_mobile/models/contact_model.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/core/storage/storage_service.dart';

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

    test('EmergencyModel tracking fields and copyWith live coordinates', () {
      final json = {
        'id': 1,
        'user_id': 5,
        'user_name': 'Test User',
        'alert_type': 'SOS_MANUAL',
        'severity': 'CRITICAL',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'accuracy': 8.5,
        'risk_score': 85.0,
        'status': 'ACTIVE',
        'is_live_sharing': true,
        'tracking_token': 'secure-token-123',
        'tracking_url': 'http://192.168.1.21:5000/track/secure-token-123',
        'sms_dispatch': {
          'configured': false,
          'status': 'NOT_CONFIGURED',
        },
      };

      final em = EmergencyModel.fromJson(json);
      expect(em.trackingToken, equals('secure-token-123'));
      expect(em.trackingUrl, equals('http://192.168.1.21:5000/track/secure-token-123'));
      expect(em.smsDispatch?['configured'], isFalse);

      // Test live location copyWith update
      final updated = em.copyWith(
        latitude: 12.9750,
        longitude: 77.5980,
        accuracy: 4.2,
      );
      expect(updated.latitude, equals(12.9750));
      expect(updated.longitude, equals(77.5980));
      expect(updated.accuracy, equals(4.2));
      expect(updated.trackingToken, equals('secure-token-123'));
    });

    test('StorageService.normalizeUrl properly sanitizes backend base URLs', () {
      expect(
        StorageService.normalizeUrl('http://10.86.146.132:5000'),
        equals('http://10.86.146.132:5000/api'),
      );
      expect(
        StorageService.normalizeUrl('http://10.86.146.132:5000/'),
        equals('http://10.86.146.132:5000/api'),
      );
      expect(
        StorageService.normalizeUrl('http://10.86.146.132:5000/api'),
        equals('http://10.86.146.132:5000/api'),
      );
      expect(
        StorageService.normalizeUrl('http://10.86.146.132:5000/api/'),
        equals('http://10.86.146.132:5000/api'),
      );
      expect(
        StorageService.normalizeUrl('http://10.86.146.132:5000/api/api'),
        equals('http://10.86.146.132:5000/api'),
      );
      expect(
        StorageService.normalizeUrl(''),
        equals(AppConstants.defaultBaseUrl),
      );
    });

    test('ContactModel serialization, deserialization and copyWith updates', () {
      final json = {
        'id': 6,
        'user_id': 4,
        'name': 'Nayana',
        'phone': '+918618085394',
        'email': 'nayana@example.com',
        'relationship': 'Friend',
        'priority': 1,
        'is_active': true,
        'notification_preference': 'ALL',
      };

      final contact = ContactModel.fromJson(json);
      expect(contact.id, equals(6));
      expect(contact.userId, equals(4));
      expect(contact.name, equals('Nayana'));
      expect(contact.phone, equals('+918618085394'));
      expect(contact.relationship, equals('Friend'));
      expect(contact.priority, equals(1));

      // Test copyWith edit operation
      final edited = contact.copyWith(
        name: 'Nayana (Best Friend)',
        phone: '+919999888877',
        priority: 2,
      );
      expect(edited.name, equals('Nayana (Best Friend)'));
      expect(edited.phone, equals('+919999888877'));
      expect(edited.priority, equals(2));
      expect(edited.id, equals(6));
      expect(edited.userId, equals(4));
      expect(edited.email, equals('nayana@example.com'));
    });

    test('Safe Route Recommendation response parsing, scoring & supporting data verification', () {
      final routePayload = {
        'start_location': {'latitude': 12.9716, 'longitude': 77.5946},
        'destination': {'latitude': 12.9850, 'longitude': 77.6100},
        'recommended_safe_route': {
          'name': 'AI Recommended Safe Path',
          'safety_score': 94,
          'risk_level': 'SAFE',
          'distance_km': 3.87,
          'estimated_time_mins': 52,
          'risk_exposure': 'Safer detour: Bypassed Railway Underpass (Isolated) [HIGH_RISK]',
          'is_recommended': true,
          'is_fallback': false,
          'waypoints': [
            {'lat': 12.9716, 'lon': 77.5946},
            {'lat': 12.9700, 'lon': 77.6010},
            {'lat': 12.9850, 'lon': 77.6100},
          ],
          'supporting_data': {
            'hazards_intersected': [],
            'incidents_nearby': [
              {'id': 1, 'category': 'Harassment', 'severity': 'MEDIUM', 'distance_meters': 185.2}
            ],
            'safe_zones_covered': [
              {'id': 1, 'name': 'Campus Main Security Hub', 'distance_meters': 29.5}
            ],
            'hazards_avoided': [
              'Bypassed Railway Underpass (Isolated)',
              'Avoided reported Harassment incident area',
            ]
          }
        },
        'shortest_route': {
          'name': 'Shortest Direct Path',
          'safety_score': 32,
          'risk_level': 'HIGH_RISK',
          'distance_km': 3.15,
          'estimated_time_mins': 42,
          'risk_exposure': 'Crosses Railway Underpass (Isolated) [HIGH_RISK] | 2 nearby reported incident(s)',
          'is_recommended': false,
          'is_fallback': false,
          'waypoints': [
            {'lat': 12.9716, 'lon': 77.5946},
            {'lat': 12.9810, 'lon': 77.6040},
            {'lat': 12.9850, 'lon': 77.6100},
          ],
          'supporting_data': {
            'hazards_intersected': [
              {'id': 3, 'name': 'Railway Underpass (Isolated)', 'zone_type': 'HIGH_RISK', 'distance_meters': 0.0}
            ],
            'incidents_nearby': [
              {'id': 1, 'category': 'Harassment', 'severity': 'HIGH', 'distance_meters': 92.2},
              {'id': 3, 'category': 'Physical Threat', 'severity': 'CRITICAL', 'distance_meters': 195.0}
            ],
            'safe_zones_covered': []
          }
        },
        'comparison': {
          'distance_diff_km': 0.72,
          'time_diff_mins': 10,
          'safety_score_diff': 62,
          'summary': '+720m (+10 mins) detour to increase safety score by 62 points.'
        },
        'is_fallback': false
      };

      // 1. Verify Recommended Safe Route
      final safeRoute = routePayload['recommended_safe_route'] as Map<String, dynamic>;
      expect(safeRoute['safety_score'], equals(94));
      expect(safeRoute['risk_level'], equals('SAFE'));
      expect(safeRoute['distance_km'], equals(3.87));
      expect(safeRoute['estimated_time_mins'], equals(52));
      expect(safeRoute['is_recommended'], isTrue);

      final safeSupporting = safeRoute['supporting_data'] as Map<String, dynamic>;
      final hazardsAvoided = safeSupporting['hazards_avoided'] as List;
      expect(hazardsAvoided.length, equals(2));
      expect(hazardsAvoided.first, contains('Railway Underpass'));

      // 2. Verify Shortest Route
      final shortestRoute = routePayload['shortest_route'] as Map<String, dynamic>;
      expect(shortestRoute['safety_score'], equals(32));
      expect(shortestRoute['risk_level'], equals('HIGH_RISK'));
      expect(shortestRoute['distance_km'], equals(3.15));
      expect(shortestRoute['is_recommended'], isFalse);

      final shortestSupporting = shortestRoute['supporting_data'] as Map<String, dynamic>;
      final hazardsIntersected = shortestSupporting['hazards_intersected'] as List;
      expect(hazardsIntersected.isNotEmpty, isTrue);
      expect(hazardsIntersected[0]['zone_type'], equals('HIGH_RISK'));

      // 3. Verify Route Comparison Metrics
      final comparison = routePayload['comparison'] as Map<String, dynamic>;
      expect(comparison['safety_score_diff'], equals(62));
      expect(comparison['distance_diff_km'], equals(0.72));
      expect(comparison['time_diff_mins'], equals(10));
    });

    test('Walking and Driving Travel Times calculated separately with distinct road profiles', () {
      final dualModePayload = {
        'start_location': {'latitude': 12.9716, 'longitude': 77.5946},
        'destination': {'latitude': 12.9850, 'longitude': 77.6100},
        'travel_mode': 'foot',
        'recommended_safe_route': {
          'name': 'AI Recommended Safe Path',
          'safety_score': 94,
          'risk_level': 'SAFE',
          'distance_km': 3.14,
          'estimated_time_mins': 42,
          'estimated_walking_time_mins': 42,
          'estimated_driving_time_mins': 7,
          'walking_time_text': '42 mins',
          'driving_time_text': '7 mins',
          'risk_exposure': 'Safer detour: Bypassed Railway Underpass (Isolated) [HIGH_RISK]',
          'is_recommended': true,
          'travel_mode': 'foot',
          'coordinates': [
            [12.9716, 77.5946],
            [12.9700, 77.6010],
            [12.9850, 77.6100],
          ],
          'supporting_data': {
            'hazards_intersected': [],
            'incidents_nearby': [],
            'safe_zones_covered': [{'name': 'Campus Security Hub'}],
            'hazards_avoided': ['Bypassed Railway Underpass (Isolated)'],
          }
        },
        'shortest_route': {
          'name': 'Shortest Direct Path',
          'safety_score': 12,
          'risk_level': 'HIGH_RISK',
          'distance_km': 2.85,
          'estimated_time_mins': 38,
          'estimated_walking_time_mins': 38,
          'estimated_driving_time_mins': 5,
          'walking_time_text': '38 mins',
          'driving_time_text': '5 mins',
          'risk_exposure': 'Crosses: Railway Underpass (Isolated) (HIGH_RISK)',
          'is_recommended': false,
          'travel_mode': 'foot',
          'coordinates': [
            [12.9716, 77.5946],
            [12.9810, 77.6040],
            [12.9850, 77.6100],
          ],
          'supporting_data': {
            'hazards_intersected': [{'name': 'Railway Underpass (Isolated)'}],
            'incidents_nearby': [{'category': 'Harassment', 'severity': 'HIGH'}],
            'safe_zones_covered': [],
          }
        },
        'walking_profile': {
          'mode': 'foot',
          'recommended_safe_route': {
            'distance_km': 3.14,
            'estimated_walking_time_mins': 42,
            'estimated_driving_time_mins': 7,
            'walking_time_text': '42 mins',
            'driving_time_text': '7 mins',
          },
          'shortest_route': {
            'distance_km': 2.85,
            'estimated_walking_time_mins': 38,
            'estimated_driving_time_mins': 5,
            'walking_time_text': '38 mins',
            'driving_time_text': '5 mins',
          }
        },
        'driving_profile': {
          'mode': 'driving',
          'recommended_safe_route': {
            'distance_km': 3.87,
            'estimated_walking_time_mins': 46,
            'estimated_driving_time_mins': 9,
            'walking_time_text': '46 mins',
            'driving_time_text': '9 mins',
          },
          'shortest_route': {
            'distance_km': 3.15,
            'estimated_walking_time_mins': 38,
            'estimated_driving_time_mins': 5,
            'walking_time_text': '38 mins',
            'driving_time_text': '5 mins',
          }
        }
      };

      final safe = dualModePayload['recommended_safe_route'] as Map<String, dynamic>;
      final shortest = dualModePayload['shortest_route'] as Map<String, dynamic>;

      // 1. Both walking and driving times are present on Recommended Safe Route
      expect(safe['estimated_walking_time_mins'], equals(42));
      expect(safe['estimated_driving_time_mins'], equals(7));
      expect(safe['walking_time_text'], equals('42 mins'));
      expect(safe['driving_time_text'], equals('7 mins'));
      expect(safe['distance_km'], equals(3.14));

      // 2. Both walking and driving times are present on Shortest Route
      expect(shortest['estimated_walking_time_mins'], equals(38));
      expect(shortest['estimated_driving_time_mins'], equals(5));
      expect(shortest['walking_time_text'], equals('38 mins'));
      expect(shortest['driving_time_text'], equals('5 mins'));
      expect(shortest['distance_km'], equals(2.85));

      // 3. Driving distance and walking distance differ according to road networks
      final walkProf = dualModePayload['walking_profile'] as Map<String, dynamic>;
      final driveProf = dualModePayload['driving_profile'] as Map<String, dynamic>;

      final walkSafe = walkProf['recommended_safe_route'] as Map<String, dynamic>;
      final driveSafe = driveProf['recommended_safe_route'] as Map<String, dynamic>;

      expect(walkSafe['distance_km'], equals(3.14));
      expect(driveSafe['distance_km'], equals(3.87));
      expect(walkSafe['distance_km'] != driveSafe['distance_km'], isTrue);

      // 4. Test "Unavailable" fallback formatting
      final unavailableRoute = {
        'name': 'Restricted Terrain Route',
        'estimated_walking_time_mins': null,
        'estimated_driving_time_mins': null,
        'walking_time_text': 'Unavailable (Pedestrian routing unavailable)',
        'driving_time_text': 'Unavailable (Driving routing unavailable)',
      };
      expect(unavailableRoute['walking_time_text'], contains('Unavailable'));
      expect(unavailableRoute['driving_time_text'], contains('Unavailable'));
    });
  });
}
