import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

class VoiceDistressService {
  static final VoiceDistressService _instance = VoiceDistressService._internal();
  factory VoiceDistressService() => _instance;
  VoiceDistressService._internal();

  bool isListening = false;
  final List<String> distressKeywords = [
    'HELP',
    'SAVE ME',
    'EMERGENCY',
    'CALL FOR HELP',
    'DANGER',
  ];

  final StreamController<String> _distressKeywordController =
      StreamController<String>.broadcast();
  Stream<String> get distressKeywordStream => _distressKeywordController.stream;

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startListening() async {
    final granted = await requestMicrophonePermission();
    if (!granted) {
      return false;
    }
    isListening = true;
    return true;
  }

  void stopListening() {
    isListening = false;
  }

  // Trigger simulated speech input for presentation / viva
  void simulateRecognizedText(String phrase) {
    final upper = phrase.toUpperCase();
    for (final kw in distressKeywords) {
      if (upper.contains(kw)) {
        _distressKeywordController.add(kw);
        break;
      }
    }
  }
}
