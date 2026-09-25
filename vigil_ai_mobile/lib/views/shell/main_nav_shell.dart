import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/providers/demo_mode_provider.dart';
import 'package:vigil_ai_mobile/providers/sensor_provider.dart';
import 'package:vigil_ai_mobile/views/demo/demo_controls_sheet.dart';
import 'package:vigil_ai_mobile/views/emergency/sos_countdown_dialog.dart';

class MainNavShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainNavShell({super.key, required this.child});

  @override
  ConsumerState<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends ConsumerState<MainNavShell> {
  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/safety')) return 1;
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/alerts')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/safety');
        break;
      case 2:
        context.go('/map');
        break;
      case 3:
        context.go('/alerts');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  void _showSosDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const SosCountdownDialog(),
    );
  }

  void _showDemoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DemoControlsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final demoState = ref.watch(demoModeProvider);

    // Listen to fall detection events
    ref.listen<SensorState>(sensorProvider, (previous, next) {
      if (next.possibleFallDetected && !(previous?.possibleFallDetected ?? false)) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.sosRed, size: 28),
                SizedBox(width: 10),
                Text('Possible Fall Detected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: const Text(
              'A sudden impact drop was detected by your device sensors. Are you okay?',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            actions: [
              OutlinedButton(
                onPressed: () {
                  ref.read(sensorProvider.notifier).dismissFallAlert();
                  Navigator.pop(ctx);
                },
                child: const Text("I'M OKAY"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
                onPressed: () {
                  ref.read(sensorProvider.notifier).dismissFallAlert();
                  Navigator.pop(ctx);
                  _showSosDialog();
                },
                child: const Text('SEND SOS NOW'),
              ),
            ],
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          widget.child,
          if (demoState.isDemoModeActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _showDemoSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    color: AppColors.cautionYellow.withOpacity(0.92),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.science_outlined, size: 14, color: Colors.black),
                        const SizedBox(width: 6),
                        Text(
                          'DEMO MODE / SIMULATED DATA (Tap for triggers)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 64,
        width: 64,
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.sosRed.withOpacity(0.5),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showSosDialog,
          backgroundColor: AppColors.sosRed,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, color: Colors.white, size: 24),
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _navItem(icon: Icons.home_filled, label: 'Home', index: 0, selectedIndex: selectedIndex),
                  _navItem(icon: Icons.health_and_safety_outlined, label: 'Safety', index: 1, selectedIndex: selectedIndex),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _navItem(icon: Icons.map_outlined, label: 'Map', index: 2, selectedIndex: selectedIndex),
                  _navItem(icon: Icons.notifications_none, label: 'Alerts', index: 3, selectedIndex: selectedIndex),
                  _navItem(icon: Icons.person_outline, label: 'Profile', index: 4, selectedIndex: selectedIndex),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required int selectedIndex,
  }) {
    final isSelected = index == selectedIndex;
    return MaterialButton(
      minWidth: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      onPressed: () => _onItemTapped(index, context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
