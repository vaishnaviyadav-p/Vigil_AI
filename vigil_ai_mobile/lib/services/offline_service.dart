import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String _offlineQueueKey = 'vigil_offline_emergency_queue';

  Future<void> queueEmergencyEvent(Map<String, dynamic> eventData) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queue = prefs.getStringList(_offlineQueueKey) ?? [];
    queue.add(jsonEncode(eventData));
    await prefs.setStringList(_offlineQueueKey, queue);
  }

  Future<List<Map<String, dynamic>>> getQueuedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queue = prefs.getStringList(_offlineQueueKey) ?? [];
    return queue.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineQueueKey);
  }
}
