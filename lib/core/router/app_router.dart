import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/passenger/presentation/screens/passenger_home_screen.dart';
import '../../features/passenger/presentation/screens/subscription_screen.dart';
import '../../features/passenger/presentation/screens/report_screen.dart';
import '../../features/passenger/presentation/screens/search_screen.dart';
import '../../features/passenger/presentation/screens/lost_item_screen.dart';
import '../../features/driver/presentation/screens/driver_home_screen.dart';
import '../../features/passenger/presentation/screens/notifications_screen.dart';
import '../../features/passenger/presentation/screens/edit_profile_screen.dart';
import '../../features/passenger/presentation/screens/qr_scanner_screen.dart';
import '../../features/passenger/presentation/screens/map_screen.dart';
import '../../features/passenger/presentation/screens/route_details_screen.dart';
import '../../features/passenger/presentation/screens/favorites_screen.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/passenger/presentation/screens/trip_history_screen.dart';
import '../../features/passenger/presentation/screens/pos_map_screen.dart';
import '../../features/passenger/presentation/screens/route_planner_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(path: '/passenger', builder: (context, state) => const PassengerHomeScreen()),
      GoRoute(path: '/driver', builder: (context, state) => const DriverHomeScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/search', builder: (context, state) => const RoutePlannerScreen()),
      GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
      GoRoute(path: '/subscription', builder: (context, state) => const SubscriptionScreen()),
      GoRoute(path: '/report', builder: (context, state) => const ReportScreen()),
      GoRoute(path: '/lost-item', builder: (context, state) => const LostItemScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/edit-profile', builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: '/qr-scanner', builder: (context, state) => const QRScannerScreen()),
      GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
      GoRoute(path: '/trip-history', builder: (context, state) => const TripHistoryScreen()),
      GoRoute(path: '/pos-map', builder: (context, state) => const POSMapScreen()),
      GoRoute(path: '/route-planner', builder: (context, state) => const RoutePlannerScreen()),
      GoRoute(
        path: '/route-details',
        builder: (context, state) {
          final route = state.extra as Map<String, dynamic>;
          return RouteDetailsScreen(route: route);
        },
      ),
    ],
  );
});
