import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vigil_ai_mobile/views/alerts/alerts_view.dart';
import 'package:vigil_ai_mobile/views/auth/forgot_password_view.dart';
import 'package:vigil_ai_mobile/views/auth/login_view.dart';
import 'package:vigil_ai_mobile/views/auth/register_view.dart';
import 'package:vigil_ai_mobile/views/contacts/contacts_view.dart';
import 'package:vigil_ai_mobile/views/emergency/active_emergency_view.dart';
import 'package:vigil_ai_mobile/views/home/home_view.dart';
import 'package:vigil_ai_mobile/views/incidents/report_incident_view.dart';
import 'package:vigil_ai_mobile/views/map/map_view.dart';
import 'package:vigil_ai_mobile/views/onboarding/onboarding_view.dart';
import 'package:vigil_ai_mobile/views/profile/profile_view.dart';
import 'package:vigil_ai_mobile/views/routes/safe_route_view.dart';
import 'package:vigil_ai_mobile/views/safety/safety_view.dart';
import 'package:vigil_ai_mobile/views/settings/settings_view.dart';
import 'package:vigil_ai_mobile/views/shell/main_nav_shell.dart';
import 'package:vigil_ai_mobile/views/splash/splash_view.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashView(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingView(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginView(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterView(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordView(),
    ),

    // Shell Route containing Bottom Navigation Bar
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainNavShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(child: HomeView()),
        ),
        GoRoute(
          path: '/safety',
          pageBuilder: (context, state) => const NoTransitionPage(child: SafetyView()),
        ),
        GoRoute(
          path: '/map',
          pageBuilder: (context, state) => const NoTransitionPage(child: MapView()),
        ),
        GoRoute(
          path: '/alerts',
          pageBuilder: (context, state) => const NoTransitionPage(child: AlertsView()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(child: ProfileView()),
        ),
      ],
    ),

    // Full-screen dedicated routes
    GoRoute(
      path: '/emergency',
      builder: (context, state) => const ActiveEmergencyView(),
    ),
    GoRoute(
      path: '/contacts',
      builder: (context, state) => const ContactsView(),
    ),
    GoRoute(
      path: '/incidents/report',
      builder: (context, state) => const ReportIncidentView(),
    ),
    GoRoute(
      path: '/routes/safe',
      builder: (context, state) => const SafeRouteView(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsView(),
    ),
  ],
);
