import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/core/storage/storage_service.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.psychology_outlined,
      'title': 'AI-Assisted Safety',
      'subtitle':
          'Continuous intelligent monitoring analyzing multi-sensor signals, geospatial risk, and contextual hazards to safeguard your journey.',
      'color': AppColors.primaryIndigo,
    },
    {
      'icon': Icons.emergency_outlined,
      'title': 'Instant Emergency SOS',
      'subtitle':
          'One-tap SOS with a 5-second cancelable countdown. Instantly broadcasts your live location and notifies your trusted emergency circle.',
      'color': AppColors.sosRed,
    },
    {
      'icon': Icons.location_on_outlined,
      'title': 'Smart Geofence & Maps',
      'subtitle':
          'Get proactive alerts when entering configured high-risk zones and set personal boundaries for automatic safety alerts.',
      'color': AppColors.cautionYellow,
    },
    {
      'icon': Icons.sensors_outlined,
      'title': 'Fall & Anomaly Detection',
      'subtitle':
          'Machine Learning algorithms detect sudden impact drops or rapid distress movements and prompt verification before escalating.',
      'color': AppColors.safeGreen,
    },
  ];

  Future<void> _requestPermissionsAndProceed() async {
    // Show polite explanation dialog before requesting system permissions
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: AppColors.primaryLight),
            SizedBox(width: 10),
            Text('Permissions Context', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To ensure your protection, VIGIL AI requires:',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text('• Location: For live GPS sharing during SOS & zone warnings.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Sensors: For automatic fall and motion anomaly detection.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Notifications: To deliver high-priority safety warnings.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Allow & Continue'),
          ),
        ],
      ),
    );

    // Request permissions politely
    await [
      Permission.location,
      Permission.notification,
    ].request();

    final storage = StorageService();
    await storage.setOnboardingCompleted(true);
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _requestPermissionsAndProceed,
                child: const Text('Skip', style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemCount: _pages.length,
                itemBuilder: (context, idx) {
                  final p = _pages[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: (p['color'] as Color).withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: p['color'] as Color, width: 2),
                          ),
                          child: Icon(p['icon'], size: 56, color: p['color']),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          p['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p['subtitle'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Page Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? AppColors.primaryIndigo : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentPage < _pages.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _requestPermissionsAndProceed();
                  }
                },
                child: Text(_currentPage == _pages.length - 1 ? 'Get Started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
