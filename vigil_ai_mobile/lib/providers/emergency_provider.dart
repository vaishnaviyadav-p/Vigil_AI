import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';
import 'package:vigil_ai_mobile/models/emergency_model.dart';
import 'package:vigil_ai_mobile/services/location_service.dart';
import 'package:vigil_ai_mobile/services/notification_service.dart';

class EmergencyState {
  final bool isCountingDown;
  final int countdownRemaining;
  final bool isEmergencyActive;
  final EmergencyModel? activeEmergency;
  final bool isLiveLocationSharing;
  final String? statusMessage;
  final bool isOfflineQueued;
  final String? trackingUrl;
  final String? trackingToken;
  final Map<String, dynamic>? smsDispatch;
  final String? lastError;
  final int updateCount;
  final DateTime? lastLocationUpdate;
  final bool isBroadcasting;

  EmergencyState({
    this.isCountingDown = false,
    this.countdownRemaining = 5,
    this.isEmergencyActive = false,
    this.activeEmergency,
    this.isLiveLocationSharing = false,
    this.statusMessage,
    this.isOfflineQueued = false,
    this.trackingUrl,
    this.trackingToken,
    this.smsDispatch,
    this.lastError,
    this.updateCount = 0,
    this.lastLocationUpdate,
    this.isBroadcasting = false,
  });

  EmergencyState copyWith({
    bool? isCountingDown,
    int? countdownRemaining,
    bool? isEmergencyActive,
    EmergencyModel? activeEmergency,
    bool? isLiveLocationSharing,
    String? statusMessage,
    bool? isOfflineQueued,
    String? trackingUrl,
    String? trackingToken,
    Map<String, dynamic>? smsDispatch,
    String? lastError,
    int? updateCount,
    DateTime? lastLocationUpdate,
    bool? isBroadcasting,
  }) {
    return EmergencyState(
      isCountingDown: isCountingDown ?? this.isCountingDown,
      countdownRemaining: countdownRemaining ?? this.countdownRemaining,
      isEmergencyActive: isEmergencyActive ?? this.isEmergencyActive,
      activeEmergency: activeEmergency ?? this.activeEmergency,
      isLiveLocationSharing: isLiveLocationSharing ?? this.isLiveLocationSharing,
      statusMessage: statusMessage ?? this.statusMessage,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      trackingToken: trackingToken ?? this.trackingToken,
      smsDispatch: smsDispatch ?? this.smsDispatch,
      lastError: lastError,
      updateCount: updateCount ?? this.updateCount,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
    );
  }
}

class EmergencyNotifier extends StateNotifier<EmergencyState> {
  final ApiClient _api = ApiClient();
  final LocationService _location = LocationService();
  final NotificationService _notification = NotificationService();

  Timer? _countdownTimer;
  Timer? _liveLocationTimer;
  bool _isSendingLocation = false;

  EmergencyNotifier() : super(EmergencyState()) {
    checkActiveEmergency();
  }

  Future<void> checkActiveEmergency() async {
    try {
      final res = await _api.dio.get('/emergency/active');
      if (res.data['success'] == true) {
        final data = res.data['data'];
        if (data['has_active'] == true && data['emergency'] != null) {
          final em = EmergencyModel.fromJson(data['emergency']);
          state = state.copyWith(
            isEmergencyActive: true,
            activeEmergency: em,
            isLiveLocationSharing: em.isLiveSharing,
            trackingToken: em.trackingToken,
            trackingUrl: em.trackingUrl,
            updateCount: 1,
            lastLocationUpdate: em.lastLocationUpdate ?? em.createdAt,
            isBroadcasting: em.isLiveSharing,
          );

          if (em.isLiveSharing) {
            _startLiveLocationBroadcasting(em.id);
          }
        }
      }
    } catch (_) {}
  }

  void startCountdown({int seconds = 5, String alertType = 'SOS_MANUAL'}) {
    _countdownTimer?.cancel();
    state = state.copyWith(
      isCountingDown: true,
      countdownRemaining: seconds,
      lastError: null,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdownRemaining <= 1) {
        timer.cancel();
        state = state.copyWith(isCountingDown: false);
        triggerSos(alertType: alertType);
      } else {
        state = state.copyWith(
          countdownRemaining: state.countdownRemaining - 1,
        );
      }
    });
  }

  void cancelCountdown() {
    _countdownTimer?.cancel();
    state = state.copyWith(
      isCountingDown: false,
      countdownRemaining: 5,
    );
  }

  Future<bool> triggerSos({
    String alertType = 'SOS_MANUAL',
    String? description,
  }) async {
    cancelCountdown();

    // 1. Get REAL current GPS latitude and longitude (no mock / fallback coordinates)
    final locResult = await _location.getRealPosition();
    if (!locResult.isSuccess || locResult.position == null) {
      final errorMsg = locResult.errorMessage ?? 'GPS location acquisition failed.';
      state = state.copyWith(
        lastError: errorMsg,
        statusMessage: errorMsg,
        isEmergencyActive: false,
        isLiveLocationSharing: false,
      );
      return false;
    }

    final pos = locResult.position!;
    final payload = {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'speed': pos.speed,
      'heading': pos.heading,
      'alert_type': alertType,
      'description': description ?? 'Emergency SOS triggered via VIGIL AI Mobile App.',
    };

    try {
      final res = await _api.dio.post('/emergency/sos', data: payload);
      if (res.data['success'] == true) {
        final data = res.data['data'];
        final trackingUrl = data['tracking_url'] as String?;
        final trackingToken = data['tracking_token'] as String?;
        final smsDispatch = data['sms_dispatch'] as Map<String, dynamic>?;

        final em = EmergencyModel.fromJson(
          data['emergency'],
          trackingUrl: trackingUrl,
          smsDispatch: smsDispatch,
        );

        String statusMsg;
        if (smsDispatch != null && smsDispatch['status'] == 'DELIVERED') {
          statusMsg = '🚨 SOS active! Cellular SMS dispatched to emergency contacts via Twilio.';
        } else {
          statusMsg = '🚨 SOS active! Live tracking link created and SMS dispatch initiated.';
          final alertText = (smsDispatch?['alert_text'] as String?) ??
              'Vigil AI SOS Alert!\n'
              'User has triggered an EMERGENCY SOS.\n'
              'Current Location: (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})\n'
              'Live Tracking Link: ${trackingUrl ?? ""}\n'
              'Please check on them immediately!';

          final attempted = smsDispatch?['contacts_attempted'] as List<dynamic>?;
          if (attempted != null && attempted.isNotEmpty) {
            final firstContact = attempted.first;
            final phone = (firstContact['normalized_phone'] ?? firstContact['phone'] ?? '').toString();
            if (phone.isNotEmpty) {
              _autoLaunchNativeSms(phone, alertText);
            }
          }
        }

        state = state.copyWith(
          isEmergencyActive: true,
          activeEmergency: em,
          isLiveLocationSharing: true,
          isOfflineQueued: false,
          trackingUrl: trackingUrl,
          trackingToken: trackingToken,
          smsDispatch: smsDispatch,
          statusMessage: statusMsg,
          lastError: null,
          updateCount: 1,
          lastLocationUpdate: DateTime.now(),
          isBroadcasting: true,
        );

        // Start periodic GPS streaming while SOS is active
        _startLiveLocationBroadcasting(em.id);

        await _notification.showNotification(
          id: 101,
          title: '🚨 EMERGENCY SOS ACTIVE',
          body: 'Live tracking URL is active and broadcasting your location.',
        );

        return true;
      } else {
        final errorMsg = res.data['message'] ?? 'SOS creation failed on backend.';
        state = state.copyWith(
          isEmergencyActive: false,
          isLiveLocationSharing: false,
          lastError: errorMsg,
          statusMessage: errorMsg,
        );
        return false;
      }
    } catch (e) {
      final errorMsg = 'Failed to connect to backend server: $e';
      state = state.copyWith(
        isEmergencyActive: false,
        isLiveLocationSharing: false,
        lastError: errorMsg,
        statusMessage: errorMsg,
      );
      return false;
    }
  }

  void _startLiveLocationBroadcasting(int emergencyId) {
    _stopLiveLocationBroadcasting();

    // 1. Geolocator continuous position stream
    _location.startTracking(
      onUpdate: (position) {
        _sendPeriodicLocationUpdate(emergencyId, position);
      },
    );

    // 2. Periodic heartbeat timer (every 4 seconds) to ensure frequent updates even if stationary
    _liveLocationTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!state.isEmergencyActive || !state.isLiveLocationSharing) {
        timer.cancel();
        return;
      }
      final pos = await _location.getCurrentPosition();
      if (pos != null) {
        _sendPeriodicLocationUpdate(emergencyId, pos);
      }
    });
  }

  void _stopLiveLocationBroadcasting() {
    _location.stopTracking();
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
  }

  Future<void> _sendPeriodicLocationUpdate(int emergencyId, Position pos) async {
    if (_isSendingLocation) return;
    if (!state.isEmergencyActive || !state.isLiveLocationSharing) return;

    _isSendingLocation = true;
    try {
      final res = await _api.dio.post(
        '/emergency/$emergencyId/location',
        data: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'accuracy': pos.accuracy,
          'speed': pos.speed,
          'heading': pos.heading,
        },
      );

      if (res.data['success'] == true) {
        final updatedEm = state.activeEmergency?.copyWith(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          lastLocationUpdate: DateTime.now(),
        );

        state = state.copyWith(
          activeEmergency: updatedEm,
          updateCount: state.updateCount + 1,
          lastLocationUpdate: DateTime.now(),
        );
      }
    } catch (_) {
      // Ignore temporary network packet drops during live broadcast
    } finally {
      _isSendingLocation = false;
    }
  }

  Future<void> resolveEmergency() async {
    _stopLiveLocationBroadcasting();
    if (state.activeEmergency != null) {
      try {
        await _api.dio.post('/emergency/${state.activeEmergency!.id}/resolve');
      } catch (_) {}
    }

    state = state.copyWith(
      isEmergencyActive: false,
      activeEmergency: null,
      isLiveLocationSharing: false,
      statusMessage: 'Emergency resolved. Live location sharing stopped.',
      isBroadcasting: false,
    );
  }

  Future<void> cancelEmergency() async {
    _stopLiveLocationBroadcasting();
    if (state.activeEmergency != null) {
      try {
        await _api.dio.post('/emergency/${state.activeEmergency!.id}/cancel');
      } catch (_) {}
    }

    state = state.copyWith(
      isEmergencyActive: false,
      activeEmergency: null,
      isLiveLocationSharing: false,
      statusMessage: 'Emergency cancelled by user. Live location sharing stopped.',
      isBroadcasting: false,
    );
  }

  void setLiveSharing(bool active) {
    state = state.copyWith(isLiveLocationSharing: active);
    if (state.activeEmergency != null) {
      if (active) {
        _startLiveLocationBroadcasting(state.activeEmergency!.id);
      } else {
        _stopLiveLocationBroadcasting();
      }
    }
  }

  Future<void> _autoLaunchNativeSms(String phone, String message) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: {'body': message},
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[EmergencyNotifier] Auto SMS launch error: $e');
    }
  }

  @override
  void dispose() {
    _stopLiveLocationBroadcasting();
    _countdownTimer?.cancel();
    super.dispose();
  }
}

final emergencyProvider =
    StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
  return EmergencyNotifier();
});
