import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/core/storage/storage_service.dart';
import 'package:vigil_ai_mobile/core/theme/app_theme.dart';
import 'package:vigil_ai_mobile/routes/app_router.dart';
import 'package:vigil_ai_mobile/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent secure storage & shared preferences
  final storage = StorageService();
  await storage.init();

  // Initialize local notifications service
  final notifications = NotificationService();
  await notifications.init();

  runApp(
    const ProviderScope(
      child: VigilAiApp(),
    ),
  );
}

class VigilAiApp extends StatelessWidget {
  const VigilAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
