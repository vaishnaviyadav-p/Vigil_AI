import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';
import 'package:vigil_ai_mobile/models/incident_model.dart';

class IncidentState {
  final List<IncidentModel> allIncidents;
  final List<IncidentModel> userIncidents;
  final bool isLoading;

  IncidentState({
    this.allIncidents = const [],
    this.userIncidents = const [],
    this.isLoading = false,
  });

  IncidentState copyWith({
    List<IncidentModel>? allIncidents,
    List<IncidentModel>? userIncidents,
    bool? isLoading,
  }) {
    return IncidentState(
      allIncidents: allIncidents ?? this.allIncidents,
      userIncidents: userIncidents ?? this.userIncidents,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class IncidentNotifier extends StateNotifier<IncidentState> {
  final ApiClient _api = ApiClient();

  IncidentNotifier() : super(IncidentState()) {
    fetchIncidents();
  }

  Future<void> fetchIncidents() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.dio.get('/incidents');
      if (res.data['success'] == true) {
        final raw = res.data['data'] as List;
        final list = raw.map((i) => IncidentModel.fromJson(i)).toList();
        state = state.copyWith(allIncidents: list, isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> reportIncident({
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    String? address,
    String severity = 'MEDIUM',
  }) async {
    try {
      final res = await _api.dio.post('/incidents', data: {
        'category': category,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'severity': severity,
      });

      if (res.data['success'] == true) {
        await fetchIncidents();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final incidentProvider = StateNotifierProvider<IncidentNotifier, IncidentState>((ref) {
  return IncidentNotifier();
});
