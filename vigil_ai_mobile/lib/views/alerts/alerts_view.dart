import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';

class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  List<dynamic> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    try {
      final res = await ApiClient().dio.get('/notifications');
      if (res.data['success'] == true) {
        setState(() {
          _alerts = res.data['data'] as List;
          _loading = false;
        });
      }
    } catch (_) {
      // Seed default alerts for demo view
      setState(() {
        _alerts = [
          {
            'id': 1,
            'title': 'High-Risk Zone Entered',
            'body': 'You entered configured Railway Underpass caution boundary.',
            'notification_type': 'ZONE',
            'created_at': DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
          },
          {
            'id': 2,
            'title': 'Emergency SOS Alert',
            'body': 'Emergency alert dispatched to 3 trusted contacts.',
            'notification_type': 'SOS',
            'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
          },
          {
            'id': 3,
            'title': 'Fall Verification Completed',
            'body': 'User confirmed safety following sudden motion shock.',
            'notification_type': 'FALL',
            'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          },
        ];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Safety Alerts & Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAlerts,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? const Center(
                  child: Text('No alerts logged yet.', style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = _alerts[i];
                    final type = a['notification_type'] ?? 'ALERT';
                    Color color = AppColors.primaryLight;
                    IconData icon = Icons.notifications;

                    if (type == 'SOS') {
                      color = AppColors.sosRed;
                      icon = Icons.emergency;
                    } else if (type == 'FALL') {
                      color = AppColors.highRiskOrange;
                      icon = Icons.airline_seat_recline_extra;
                    } else if (type == 'ZONE') {
                      color = AppColors.cautionYellow;
                      icon = Icons.warning_amber_rounded;
                    } else if (type == 'GEOFENCE') {
                      color = AppColors.safeGreen;
                      icon = Icons.fmd_good_outlined;
                    }

                    String timeStr = '';
                    if (a['created_at'] != null) {
                      final dt = DateTime.tryParse(a['created_at']);
                      if (dt != null) timeStr = DateFormat('hh:mm a, dd MMM').format(dt);
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a['title'] ?? 'Alert',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    Text(timeStr, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  a['body'] ?? '',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
