import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';
import 'package:vigil_ai_mobile/models/incident_model.dart';
import 'package:vigil_ai_mobile/models/zone_model.dart';
import 'package:vigil_ai_mobile/services/location_service.dart';
import 'dart:math' as math;


class SafeRouteView extends StatefulWidget {
  const SafeRouteView({super.key});

  @override
  State<SafeRouteView> createState() => _SafeRouteViewState();
}

class _SafeRouteViewState extends State<SafeRouteView> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _currentLocation;
  String _startAddress = 'Acquiring GPS fix...';
  bool _gpsLocked = false;

  LatLng? _destinationLocation;
  String? _destinationName;

  bool _loadingLocation = true;
  bool _loadingRoutes = false;
  bool _searchingPlaces = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;

  List<ZoneModel> _zones = [];
  List<IncidentModel> _incidents = [];

  Map<String, dynamic>? _routesData;
  int _selectedRouteIndex = 0; // 0: Recommended Safe Route, 1: Shortest Direct Route
  String _selectedTravelMode = 'foot'; // 'foot' (Walking) or 'driving' (Car)

  // Preset quick-pick landmarks for convenient 1-tap testing
  final List<Map<String, dynamic>> _quickDestinations = [
    {
      'name': 'Metro Station Crossing',
      'subtitle': 'Subway Transit Terminal',
      'lat': 12.9754,
      'lon': 77.6065,
      'icon': Icons.subway_rounded,
    },
    {
      'name': 'City General Hospital',
      'subtitle': 'Emergency Healthcare Center',
      'lat': 12.9820,
      'lon': 77.6090,
      'icon': Icons.local_hospital_rounded,
    },
    {
      'name': 'Central Police Station',
      'subtitle': '24/7 Security & Dispatch',
      'lat': 12.9690,
      'lon': 77.5980,
      'icon': Icons.local_police_rounded,
    },
    {
      'name': 'Commercial Shopping Hub',
      'subtitle': 'Main Retail & Pedestrian Plaza',
      'lat': 12.9818,
      'lon': 77.6083,
      'icon': Icons.storefront_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initDataAndLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initDataAndLocation() async {
    setState(() {
      _loadingLocation = true;
      _errorMessage = null;
    });

    // 1. Fetch safety zones and incidents from backend
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
    } catch (_) {
      // Backend zones optional for display
    }

    // 2. Acquire REAL GPS position via LocationService & geolocator
    final locationResult = await _locationService.getRealPosition();
    if (!mounted) return;

    if (locationResult.isSuccess && locationResult.position != null) {
      final pos = locationResult.position!;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _startAddress = 'GPS Fix: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        _gpsLocked = true;
        _loadingLocation = false;
      });
      _mapController.move(_currentLocation!, 15.0);
    } else {
      // Graceful fallback for emulator or indoors with clear label
      setState(() {
        _currentLocation = const LatLng(12.9716, 77.5946);
        _startAddress = 'Default Reference Point (GPS unavailable indoors)';
        _gpsLocked = false;
        _loadingLocation = false;
        _errorMessage = locationResult.errorMessage ?? 'Could not acquire live GPS fix.';
      });
      _mapController.move(_currentLocation!, 14.5);
    }

    // Automatically set default destination if none selected
    if (_destinationLocation == null && _quickDestinations.isNotEmpty) {
      _selectPresetDestination(_quickDestinations[0]);
    }
  }

  Future<void> _refreshGPS() async {
    setState(() {
      _loadingLocation = true;
      _errorMessage = null;
    });

    final locationResult = await _locationService.getRealPosition();
    if (!mounted) return;

    if (locationResult.isSuccess && locationResult.position != null) {
      final pos = locationResult.position!;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _startAddress = 'GPS Fix: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        _gpsLocked = true;
        _loadingLocation = false;
      });
      _mapController.move(_currentLocation!, 15.0);

      if (_destinationLocation != null) {
        _fetchRoutes();
      }
    } else {
      setState(() {
        _loadingLocation = false;
        _errorMessage = locationResult.errorMessage ?? 'GPS signal could not be acquired.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: AppColors.sosRed,
        ),
      );
    }
  }

  Future<void> _searchPlaces(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _searchingPlaces = true;
      _showSearchResults = true;
      _searchResults = [];
    });

    try {
      final res = await ApiClient().dio.get(
        '/analytics/geocode',
        queryParameters: {'q': clean},
      );

      if (res.data['success'] == true) {
        final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
        if (mounted) {
          setState(() {
            _searchResults = list;
            _searchingPlaces = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _searchingPlaces = false;
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> place) {
    final lat = (place['latitude'] as num).toDouble();
    final lon = (place['longitude'] as num).toDouble();
    final name = place['name'] ?? place['display_name'] ?? 'Selected Destination';

    setState(() {
      _destinationLocation = LatLng(lat, lon);
      _destinationName = name;
      _searchController.text = name;
      _showSearchResults = false;
      _searchResults = [];
    });

    _fetchRoutes();
  }

  void _selectPresetDestination(Map<String, dynamic> dest) {
    setState(() {
      _destinationLocation = LatLng(dest['lat'], dest['lon']);
      _destinationName = dest['name'];
      _searchController.text = dest['name'];
      _showSearchResults = false;
    });

    _fetchRoutes();
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    setState(() {
      _destinationLocation = point;
      _destinationName = 'Pinned: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      _searchController.text = _destinationName!;
      _showSearchResults = false;
    });

    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    if (_currentLocation == null || _destinationLocation == null) return;

    setState(() {
      _loadingRoutes = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().dio.post('/analytics/routes', data: {
        'start_lat': _currentLocation!.latitude,
        'start_lon': _currentLocation!.longitude,
        'dest_lat': _destinationLocation!.latitude,
        'dest_lon': _destinationLocation!.longitude,
        'mode': _selectedTravelMode,
      });

      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>;
        setState(() {
          _routesData = data;
          _loadingRoutes = false;
        });

        _fitCameraToRoute();
        return;
      }
    } catch (e) {
      // If network fails, compute real direct distance using LatLng geometry
      final directDistanceMeters = const Distance().as(
        LengthUnit.Meter,
        _currentLocation!,
        _destinationLocation!,
      );
      final distKm = (directDistanceMeters / 1000.0);
      final walkTimeMins = math.max(1, (directDistanceMeters / 1.25 / 60.0).round());
      final driveTimeMins = math.max(1, (directDistanceMeters / 9.7 / 60.0).round());

      final isDriving = _selectedTravelMode == 'driving';
      final activeTimeMins = isDriving ? driveTimeMins : walkTimeMins;

      setState(() {
        _routesData = {
          'start_location': {
            'latitude': _currentLocation!.latitude,
            'longitude': _currentLocation!.longitude,
          },
          'destination': {
            'latitude': _destinationLocation!.latitude,
            'longitude': _destinationLocation!.longitude,
          },
          'travel_mode': _selectedTravelMode,
          'recommended_safe_route': {
            'name': 'Direct Geospatial Path (Fallback)',
            'safety_score': 85,
            'risk_level': 'SAFE',
            'distance_km': double.parse(distKm.toStringAsFixed(2)),
            'estimated_time_mins': activeTimeMins,
            'estimated_walking_time_mins': walkTimeMins,
            'estimated_driving_time_mins': driveTimeMins,
            'walking_time_text': '$walkTimeMins mins',
            'driving_time_text': '$driveTimeMins mins',
            'risk_exposure': 'Offline mode: calculated via direct device GPS distance.',
            'waypoints': [
              {'lat': _currentLocation!.latitude, 'lon': _currentLocation!.longitude},
              {'lat': _destinationLocation!.latitude, 'lon': _destinationLocation!.longitude},
            ],
            'is_recommended': true,
            'is_fallback': true,
            'supporting_data': {
              'hazards_intersected': [],
              'incidents_nearby': [],
              'safe_zones_covered': [],
              'hazards_avoided': [],
            }
          },
          'shortest_route': {
            'name': 'Direct Vector Path',
            'safety_score': 85,
            'risk_level': 'SAFE',
            'distance_km': double.parse(distKm.toStringAsFixed(2)),
            'estimated_time_mins': activeTimeMins,
            'estimated_walking_time_mins': walkTimeMins,
            'estimated_driving_time_mins': driveTimeMins,
            'walking_time_text': '$walkTimeMins mins',
            'driving_time_text': '$driveTimeMins mins',
            'risk_exposure': 'Calculated via device coordinates.',
            'waypoints': [
              {'lat': _currentLocation!.latitude, 'lon': _currentLocation!.longitude},
              {'lat': _destinationLocation!.latitude, 'lon': _destinationLocation!.longitude},
            ],
            'is_recommended': false,
            'is_fallback': true,
            'supporting_data': {
              'hazards_intersected': [],
              'incidents_nearby': [],
              'safe_zones_covered': [],
            }
          },
          'comparison': {
            'distance_diff_km': 0.0,
            'time_diff_mins': 0,
            'walking_time_diff_mins': 0,
            'driving_time_diff_mins': 0,
            'safety_score_diff': 0,
            'summary': 'Offline calculation based on device coordinates.',
          },
          'is_fallback': true,
        };
        _loadingRoutes = false;
      });

      _fitCameraToRoute();
    }
  }

  void _switchTravelMode(String mode) {
    if (_selectedTravelMode == mode) return;

    setState(() {
      _selectedTravelMode = mode;
    });

    // Check if the backend already delivered both profiles for instantaneous UI response
    final profileKey = mode == 'driving' ? 'driving_profile' : 'walking_profile';
    if (_routesData != null && _routesData![profileKey] != null) {
      final profile = _routesData![profileKey] as Map<String, dynamic>;
      setState(() {
        _routesData!['recommended_safe_route'] = profile['recommended_safe_route'];
        _routesData!['shortest_route'] = profile['shortest_route'];
        _routesData!['travel_mode'] = mode;
      });
      _fitCameraToRoute();
    } else {
      _fetchRoutes();
    }
  }

  void _fitCameraToRoute() {
    final points = <LatLng>[];
    if (_currentLocation != null) points.add(_currentLocation!);
    if (_destinationLocation != null) points.add(_destinationLocation!);

    final activeRoute = _getActiveRoute();
    if (activeRoute != null) {
      final wps = _extractRouteCoordinates(activeRoute);
      points.addAll(wps);
    }

    if (points.isEmpty) return;

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.only(top: 90, bottom: 270, left: 40, right: 40),
        ),
      );
    } catch (_) {
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 14.0);
      }
    }
  }

  Map<String, dynamic>? _getActiveRoute() {
    if (_routesData == null) return null;
    // Check if travel mode specific profiles are present
    final profileKey = _selectedTravelMode == 'driving' ? 'driving_profile' : 'walking_profile';
    if (_routesData![profileKey] != null) {
      final prof = _routesData![profileKey] as Map<String, dynamic>;
      return _selectedRouteIndex == 0
          ? prof['recommended_safe_route']
          : prof['shortest_route'];
    }
    return _selectedRouteIndex == 0
        ? _routesData!['recommended_safe_route']
        : (_routesData!['shortest_route'] ?? _routesData!['alternative_route']);
  }

  Map<String, dynamic>? _getSafeRoute() {
    if (_routesData == null) return null;
    final profileKey = _selectedTravelMode == 'driving' ? 'driving_profile' : 'walking_profile';
    if (_routesData![profileKey] != null) {
      return _routesData![profileKey]['recommended_safe_route'];
    }
    return _routesData!['recommended_safe_route'];
  }

  Map<String, dynamic>? _getShortestRoute() {
    if (_routesData == null) return null;
    final profileKey = _selectedTravelMode == 'driving' ? 'driving_profile' : 'walking_profile';
    if (_routesData![profileKey] != null) {
      return _routesData![profileKey]['shortest_route'];
    }
    return _routesData!['shortest_route'] ?? _routesData!['alternative_route'];
  }

  List<LatLng> _extractRouteCoordinates(Map<String, dynamic>? route) {
    if (route == null) return [];
    final waypoints = route['waypoints'] as List?;
    if (waypoints != null && waypoints.isNotEmpty) {
      return waypoints
          .map((w) => LatLng((w['lat'] as num).toDouble(), (w['lon'] as num).toDouble()))
          .toList();
    }
    final coords = route['coordinates'] as List?;
    if (coords != null && coords.isNotEmpty) {
      return coords
          .map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final safeRoute = _getSafeRoute();
    final shortestRoute = _getShortestRoute();
    final comparison = _routesData?['comparison'];
    final isFallback = _routesData?['is_fallback'] == true;

    final safePoints = _extractRouteCoordinates(safeRoute);
    final shortestPoints = _extractRouteCoordinates(shortestRoute);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Safe Route Recommendations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Re-acquire GPS',
            onPressed: _refreshGPS,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recalculate Routes',
            onPressed: _fetchRoutes,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. FlutterMap (Map View with polylines, start/dest markers, and hazards)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? const LatLng(12.9716, 77.5946),
                initialZoom: 14.5,
                onTap: _onMapTapped,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.vigilai.mobile',
                ),

                // Safety Zone Circles from Database
                CircleLayer(
                  circles: _zones.map((z) {
                    Color c = AppColors.safeGreen;
                    if (z.zoneType == 'HIGH_RISK') {
                      c = AppColors.sosRed;
                    } else if (z.zoneType == 'CAUTION') {
                      c = AppColors.cautionYellow;
                    }

                    return CircleMarker(
                      point: LatLng(z.latitude, z.longitude),
                      radius: z.radiusMeters,
                      useRadiusInMeter: true,
                      color: c.withValues(alpha: 0.18),
                      borderColor: c,
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),

                // Route Polylines
                PolylineLayer(
                  polylines: [
                    // Shortest / Direct Route
                    if (shortestPoints.isNotEmpty)
                      Polyline(
                        points: shortestPoints,
                        strokeWidth: _selectedRouteIndex == 1 ? 5.5 : 3.5,
                        color: _selectedRouteIndex == 1
                            ? AppColors.cautionYellow
                            : Colors.blueGrey.withValues(alpha: 0.6),
                      ),

                    // AI Recommended Safe Route
                    if (safePoints.isNotEmpty)
                      Polyline(
                        points: safePoints,
                        strokeWidth: _selectedRouteIndex == 0 ? 5.5 : 3.5,
                        color: _selectedRouteIndex == 0
                            ? AppColors.safeGreen
                            : AppColors.safeGreen.withValues(alpha: 0.4),
                      ),
                  ],
                ),

                // Markers (Start, Destination, Incidents, Safety Zones)
                MarkerLayer(
                  markers: [
                    // Safety Zone Center Icons
                    ..._zones.map((z) {
                      Color c = z.zoneType == 'HIGH_RISK'
                          ? AppColors.sosRed
                          : (z.zoneType == 'CAUTION' ? AppColors.cautionYellow : AppColors.safeGreen);
                      return Marker(
                        point: LatLng(z.latitude, z.longitude),
                        width: 32,
                        height: 32,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${z.name} (${z.zoneType} Zone, radius: ${z.radiusMeters.round()}m)')),
                            );
                          },
                          child: Icon(Icons.shield, color: c, size: 28),
                        ),
                      );
                    }),

                    // Incident Warning Icons
                    ..._incidents.map((inc) {
                      return Marker(
                        point: LatLng(inc.latitude, inc.longitude),
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Reported Incident: ${inc.category} (${inc.severity} severity)')),
                            );
                          },
                          child: const Icon(Icons.warning_amber_rounded, color: AppColors.highRiskOrange, size: 26),
                        ),
                      );
                    }),

                    // START Pin (Current GPS Location)
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        width: 140,
                        height: 64,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryIndigo,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                              ),
                              child: const Text(
                                'START (YOU)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryIndigo,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryIndigo.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),

                    // DESTINATION Pin
                    if (_destinationLocation != null)
                      Marker(
                        point: _destinationLocation!,
                        width: 160,
                        height: 64,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.sosRed,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                              ),
                              child: Text(
                                _destinationName != null && _destinationName!.length > 18
                                    ? '${_destinationName!.substring(0, 16)}...'
                                    : (_destinationName ?? 'DESTINATION'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.sosRed,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.sosRed.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.flag, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Top Search & Controls Floating Card
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Input Card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      // Current Location Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              _gpsLocked ? Icons.gps_fixed : Icons.gps_not_fixed,
                              color: _gpsLocked ? AppColors.safeGreen : AppColors.cautionYellow,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _startAddress,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_loadingLocation)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),

                      // Destination Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 6),
                            const Icon(Icons.search, color: AppColors.primaryLight, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Search place, address, or tap on map...',
                                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onSubmitted: _searchPlaces,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _showSearchResults = false;
                                  });
                                },
                              ),
                            IconButton(
                              icon: _searchingPlaces
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryLight, size: 20),
                              onPressed: () => _searchPlaces(_searchController.text),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Geocode Search Results Dropdown List
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, idx) {
                        final p = _searchResults[idx];
                        final isInternal = p['is_internal'] == true;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isInternal ? Icons.shield : Icons.place,
                            color: isInternal ? AppColors.cautionYellow : AppColors.primaryLight,
                            size: 18,
                          ),
                          title: Text(
                            p['name'] ?? '',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            p['display_name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          onTap: () => _selectSearchResult(p),
                        );
                      },
                    ),
                  ),

                // Preset Quick-Select Chips (Horizontal Scroll)
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickDestinations.map((qd) {
                      final isSelected = _destinationName == qd['name'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: Icon(qd['icon'] as IconData, size: 14, color: isSelected ? Colors.white : AppColors.primaryLight),
                          label: Text(qd['name'] as String),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                          backgroundColor: isSelected ? AppColors.primaryIndigo : AppColors.card.withValues(alpha: 0.9),
                          side: BorderSide(color: isSelected ? AppColors.primaryLight : AppColors.border),
                          onPressed: () => _selectPresetDestination(qd),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 3. Map Floating Action Buttons (Right Side)
          Positioned(
            right: 16,
            bottom: 275,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_center_user',
                  backgroundColor: AppColors.card,
                  onPressed: () {
                    if (_currentLocation != null) {
                      _mapController.move(_currentLocation!, 15.0);
                    }
                  },
                  child: const Icon(Icons.my_location, color: AppColors.primaryLight),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fab_fit_route',
                  backgroundColor: AppColors.card,
                  onPressed: _fitCameraToRoute,
                  child: const Icon(Icons.crop_free, color: AppColors.safeGreen),
                ),
              ],
            ),
          ),

          // 4. Bottom Route Details and Comparison Card (Guaranteed Zero Overflow)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: _loadingRoutes
                  ? const SizedBox(
                      height: 180,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Evaluating walking & driving routes against safety data...',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _routesData == null
                      ? const SizedBox(
                          height: 140,
                          child: Center(
                            child: Text(
                              'Select a destination above or tap on the map to evaluate routes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.48,
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Fallback Warning Banner if applicable
                                if (isFallback)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.cautionYellow.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.cautionYellow.withValues(alpha: 0.5)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline, color: AppColors.cautionYellow, size: 16),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'GEOSPATIAL FALLBACK: Direct vector distances calculated from device GPS coordinates.',
                                            style: TextStyle(color: AppColors.cautionYellow, fontSize: 10.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Travel Mode Switcher: Walking vs Car Driving
                                Row(
                                  children: [
                                    Expanded(
                                      child: _travelModeButton(
                                        icon: Icons.directions_walk_rounded,
                                        label: 'Walking Mode',
                                        isSelected: _selectedTravelMode == 'foot',
                                        onTap: () => _switchTravelMode('foot'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _travelModeButton(
                                        icon: Icons.directions_car_rounded,
                                        label: 'Car Driving',
                                        isSelected: _selectedTravelMode == 'driving',
                                        onTap: () => _switchTravelMode('driving'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Segmented Route Selector Tabs (Safe vs Direct)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _routeTabButton(
                                        title: 'AI RECOMMENDED',
                                        score: safeRoute?['safety_score'] ?? 0,
                                        color: AppColors.safeGreen,
                                        isSelected: _selectedRouteIndex == 0,
                                        onTap: () {
                                          setState(() => _selectedRouteIndex = 0);
                                          _fitCameraToRoute();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _routeTabButton(
                                        title: 'SHORTEST DIRECT',
                                        score: shortestRoute?['safety_score'] ?? 0,
                                        color: AppColors.cautionYellow,
                                        isSelected: _selectedRouteIndex == 1,
                                        onTap: () {
                                          setState(() => _selectedRouteIndex = 1);
                                          _fitCameraToRoute();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Active Route Stats Card (Zero Overflow 2x2 Grid)
                                _activeRouteCard(
                                  _selectedRouteIndex == 0 ? safeRoute : shortestRoute,
                                  isRecommended: _selectedRouteIndex == 0,
                                ),

                                // Comparison Insight Pill
                                if (comparison != null && comparison['summary'] != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryIndigo.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.primaryIndigo.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.insights, color: AppColors.primaryLight, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            comparison['summary'] as String,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _travelModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryIndigo.withValues(alpha: 0.25) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeTabButton({
    required String title,
    required int score,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$score/100',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeRouteCard(Map<String, dynamic>? route, {required bool isRecommended}) {
    if (route == null) return const SizedBox();

    final score = route['safety_score'] ?? 0;
    final distKm = route['distance_km'] ?? 0.0;
    final walkText = route['walking_time_text'] ?? (route['estimated_walking_time_mins'] != null ? '${route['estimated_walking_time_mins']} mins' : 'Unavailable');
    final driveText = route['driving_time_text'] ?? (route['estimated_driving_time_mins'] != null ? '${route['estimated_driving_time_mins']} mins' : 'Unavailable');
    final riskExposure = route['risk_exposure'] ?? 'N/A';
    final supporting = route['supporting_data'] as Map<String, dynamic>?;

    final hazardsIntersected = supporting?['hazards_intersected'] as List? ?? [];
    final incidentsNearby = supporting?['incidents_nearby'] as List? ?? [];
    final safeZonesCovered = supporting?['safe_zones_covered'] as List? ?? [];
    final hazardsAvoided = supporting?['hazards_avoided'] as List? ?? [];

    final statusColor = isRecommended ? AppColors.safeGreen : AppColors.cautionYellow;
    final isDriving = _selectedTravelMode == 'driving';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                route['name'] ?? 'Route',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  isRecommended ? '★ AI RECOMMENDED' : 'DIRECT PATH',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2x2 Metric Grid (Guaranteed Zero RenderFlex Overflow)
          // Row 1: Route Distance & Safety Score
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  icon: Icons.straighten_rounded,
                  label: 'Route Distance',
                  value: '$distKm km',
                  sublabel: isDriving ? 'Vehicular Road' : 'Pedestrian Path',
                  valueColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBox(
                  icon: Icons.shield_rounded,
                  label: 'Safety Score',
                  value: '$score/100',
                  sublabel: route['risk_level'] ?? 'N/A',
                  valueColor: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Walking Duration & Car Driving Duration
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  icon: Icons.directions_walk_rounded,
                  label: 'Walking Time',
                  value: walkText,
                  isActive: !isDriving,
                  activeColor: AppColors.safeGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBox(
                  icon: Icons.directions_car_rounded,
                  label: 'Car Driving Time',
                  value: driveText,
                  isActive: isDriving,
                  activeColor: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Risk Exposure and Supporting Data
          Text(
            'Risk Exposure: $riskExposure',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isRecommended ? AppColors.safeGreen : AppColors.cautionYellow,
            ),
          ),

          // Supporting details tags
          if (hazardsAvoided.isNotEmpty || hazardsIntersected.isNotEmpty || safeZonesCovered.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                ...hazardsAvoided.map((ha) => _badgeTag('$ha', AppColors.safeGreen)),
                ...hazardsIntersected.map((hi) => _badgeTag('Traverses ${hi['name']}', AppColors.sosRed)),
                ...incidentsNearby.map((inNearby) => _badgeTag('${inNearby['category']} nearby (${inNearby['distance_meters']}m)', AppColors.highRiskOrange)),
                ...safeZonesCovered.map((sz) => _badgeTag('Covered by ${sz['name']}', AppColors.primaryLight)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricBox({
    required IconData icon,
    required String label,
    required String value,
    String? sublabel,
    Color? valueColor,
    bool isActive = false,
    Color? activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? (activeColor ?? AppColors.primaryIndigo).withValues(alpha: 0.12) : AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? (activeColor ?? AppColors.primaryLight) : AppColors.border,
          width: isActive ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isActive ? (activeColor ?? AppColors.primaryLight) : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? (isActive ? (activeColor ?? Colors.white) : AppColors.textPrimary),
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sublabel != null)
                  Text(
                    sublabel,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 8),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}
