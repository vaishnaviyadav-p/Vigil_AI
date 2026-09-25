import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';
import 'package:vigil_ai_mobile/models/incident_model.dart';
import 'package:vigil_ai_mobile/models/zone_model.dart';
import 'package:vigil_ai_mobile/services/location_service.dart';

class MapView extends ConsumerStatefulWidget {
  const MapView({super.key});

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  LatLng _currentLocation = const LatLng(12.9716, 77.5946);
  List<ZoneModel> _zones = [];
  List<IncidentModel> _incidents = [];
  bool _loading = true;
  String? _activeZoneWarning;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      _currentLocation = LatLng(pos.latitude, pos.longitude);
    }

    try {
      final resZ = await ApiClient().dio.get('/zones');
      if (resZ.data['success'] == true) {
        final raw = resZ.data['data'] as List;
        _zones = raw.map((z) => ZoneModel.fromJson(z)).toList();
      }

      final resI = await ApiClient().dio.get('/incidents');
      if (resI.data['success'] == true) {
        final raw = resI.data['data'] as List;
        _incidents = raw.map((i) => IncidentModel.fromJson(i)).toList();
      }

      // Check zone proximity
      final checkRes = await ApiClient().dio.post('/zones/check', data: {
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
      });
      if (checkRes.data['data']?['is_inside'] == true) {
        _activeZoneWarning = checkRes.data['data']['warning'];
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _centerOnUser() {
    _mapController.move(_currentLocation, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Safety & Geospatial Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMapData,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vigilai.mobile',
              ),

              // Circle layers for Safety Zones
              CircleLayer(
                circles: _zones.map((z) {
                  Color c = AppColors.safeGreen;
                  if (z.zoneType == 'HIGH_RISK') c = AppColors.sosRed;
                  else if (z.zoneType == 'CAUTION') c = AppColors.cautionYellow;

                  return CircleMarker(
                    point: LatLng(z.latitude, z.longitude),
                    radius: z.radiusMeters,
                    useRadiusInMeter: true,
                    color: c.withOpacity(0.2),
                    borderColor: c,
                    borderStrokeWidth: 2,
                  );
                }).toList(),
              ),

              // Markers layer for current location, zones, and incidents
              MarkerLayer(
                markers: [
                  // User Location Pin
                  Marker(
                    point: _currentLocation,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryIndigo,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: AppColors.primaryIndigo.withOpacity(0.5), blurRadius: 10),
                        ],
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                  ),

                  // Zone Center Markers
                  ..._zones.map((z) {
                    Color c = z.zoneType == 'HIGH_RISK'
                        ? AppColors.sosRed
                        : (z.zoneType == 'CAUTION' ? AppColors.cautionYellow : AppColors.safeGreen);

                    return Marker(
                      point: LatLng(z.latitude, z.longitude),
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${z.name} (${z.zoneType})')),
                          );
                        },
                        child: Icon(Icons.shield, color: c, size: 32),
                      ),
                    );
                  }),

                  // Community Incident Markers
                  ..._incidents.map((inc) {
                    return Marker(
                      point: LatLng(inc.latitude, inc.longitude),
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Incident: ${inc.category} - ${inc.description}')),
                          );
                        },
                        child: const Icon(Icons.warning, color: AppColors.highRiskOrange, size: 28),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Zone Warning Overlay if inside high risk zone
          if (_activeZoneWarning != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.sosRed,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _activeZoneWarning!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Center on User FAB
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton.small(
              backgroundColor: AppColors.card,
              onPressed: _centerOnUser,
              child: const Icon(Icons.my_location, color: AppColors.primaryLight),
            ),
          ),
        ],
      ),
    );
  }
}
