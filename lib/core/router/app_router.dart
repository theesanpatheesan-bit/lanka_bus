import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lanka_bus/features/auth/presentation/pages/login_screen.dart';
import 'package:lanka_bus/features/auth/presentation/pages/otp_screen.dart';
import 'package:lanka_bus/features/auth/presentation/pages/splash_screen.dart';
import 'package:lanka_bus/features/auth/presentation/widgets/role_router.dart';
import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';
import 'package:lanka_bus/features/bus_search/presentation/pages/bus_results_screen.dart';
import 'package:lanka_bus/features/bus_search/presentation/pages/bus_search_screen.dart';
import 'package:lanka_bus/features/bus_search/presentation/pages/passenger_home_page.dart';
import 'package:lanka_bus/features/live_tracking/presentation/pages/live_tracking_screen.dart';
import 'package:lanka_bus/features/operator_dashboard/data/models/operator_trip_model.dart';
import 'package:lanka_bus/features/operator_dashboard/presentation/pages/admin_dashboard_page.dart';
import 'package:lanka_bus/features/operator_dashboard/presentation/pages/operator_dashboard_page.dart';
import 'package:lanka_bus/features/operator_dashboard/presentation/pages/qr_scanner_screen.dart';
import 'package:lanka_bus/features/operator_dashboard/presentation/pages/seat_chart_screen.dart';
import 'package:lanka_bus/features/seat_booking/data/models/booking_summary_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/confirmed_booking_model.dart';
import 'package:lanka_bus/features/seat_booking/presentation/pages/boarding_dropping_screen.dart';
import 'package:lanka_bus/features/seat_booking/presentation/pages/m_ticket_screen.dart';
import 'package:lanka_bus/features/seat_booking/presentation/pages/passenger_details_screen.dart';
import 'package:lanka_bus/features/seat_booking/presentation/pages/payment_screen.dart';
import 'package:lanka_bus/features/seat_booking/presentation/pages/seat_layout_screen.dart';

/// Application routes with RBAC redirects.
class AppRouter {
  AppRouter._();

  static const login = '/login';
  static const otp = '/otp';
  static const splash = '/splash';
  static const passengerHome = '/passenger-home';
  static const busSearch = '/bus-search';
  static const busResults = '/bus-results';
  static const seatSelection = '/seat-selection';
  static const boardingDropping = '/boarding-dropping';
  static const passengerDetails = '/passenger-details';
  static const payment = '/payment';
  static const mTicket = '/m-ticket';
  static const liveTracking = '/live-tracking';
  static const operatorDashboard = '/operator-dashboard';
  static const seatChart = '/seat-chart';
  static const qrScanner = '/qr-scanner';
  static const adminDashboard = '/admin-dashboard';

  static bool _isPublicTracking(String loc) => loc == liveTracking;

  static GoRouter create(
    AuthBloc authBloc, {
    required GoRouterAuthRefresh refresh,
  }) {
    return GoRouter(
      initialLocation: splash,
      debugLogDiagnostics: kDebugMode,
      refreshListenable: refresh,
      redirect: (context, state) {
        final auth = authBloc.state;
        final loc = state.matchedLocation;

        final isAuthRoute = loc == login || loc == otp;
        final isSplash = loc == splash;

        switch (auth.status) {
          case AuthStatus.unknown:
          case AuthStatus.loading:
            if (_isPublicTracking(loc)) return null;
            return isSplash ? null : splash;

          case AuthStatus.otpSent:
            return loc == otp ? null : otp;

          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            if (isAuthRoute || _isPublicTracking(loc)) return null;
            return login;

          case AuthStatus.authenticated:
            final user = auth.user;
            if (user == null) return login;

            final home = RoleRouter.homeFor(user.role);

            if (isAuthRoute || isSplash || loc == '/') {
              return home;
            }

            if (_isPublicTracking(loc)) return null;

            if (!RoleRouter.canAccess(user.role, loc)) {
              return home;
            }
            return null;
        }
      },
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: otp,
          builder: (context, state) => const OtpScreen(),
        ),
        GoRoute(
          path: passengerHome,
          builder: (context, state) => const PassengerHomePage(),
        ),
        GoRoute(
          path: busSearch,
          builder: (context, state) => const BusSearchScreen(),
        ),
        GoRoute(
          path: busResults,
          builder: (context, state) => const BusResultsScreen(),
        ),
        GoRoute(
          path: seatSelection,
          builder: (context, state) {
            final scheduleId =
                state.uri.queryParameters['scheduleId'] ?? '';
            final schedule = state.extra is BusScheduleModel
                ? state.extra! as BusScheduleModel
                : null;
            return SeatLayoutScreen(
              scheduleId: scheduleId,
              schedule: schedule,
            );
          },
        ),
        GoRoute(
          path: boardingDropping,
          builder: (context, state) => const BoardingDroppingScreen(),
        ),
        GoRoute(
          path: passengerDetails,
          builder: (context, state) => const PassengerDetailsScreen(),
        ),
        GoRoute(
          path: payment,
          builder: (context, state) {
            final summary = state.extra;
            if (summary is! BookingSummaryModel) {
              return const Scaffold(
                body: Center(child: Text('Missing payment payload')),
              );
            }
            return PaymentScreen(summary: summary);
          },
        ),
        GoRoute(
          path: mTicket,
          builder: (context, state) {
            final ticket = state.extra;
            if (ticket is! ConfirmedBookingModel) {
              return const Scaffold(
                body: Center(child: Text('Ticket not found')),
              );
            }
            return MTicketScreen(ticket: ticket);
          },
        ),
        GoRoute(
          path: liveTracking,
          builder: (context, state) {
            final q = state.uri.queryParameters;
            final boarding = q['boarding'];
            return LiveTrackingScreen(
              scheduleId: q['scheduleId']?.isNotEmpty == true
                  ? q['scheduleId']
                  : null,
              busId: q['busId']?.isNotEmpty == true ? q['busId'] : null,
              boardingPointName: boarding != null && boarding.isNotEmpty
                  ? Uri.decodeComponent(boarding)
                  : null,
            );
          },
        ),
        GoRoute(
          path: operatorDashboard,
          builder: (context, state) => const OperatorDashboardPage(),
        ),
        GoRoute(
          path: seatChart,
          builder: (context, state) {
            final scheduleId =
                state.uri.queryParameters['scheduleId'] ?? '';
            final trip = state.extra is OperatorTripModel
                ? state.extra! as OperatorTripModel
                : null;
            return SeatChartScreen(scheduleId: scheduleId, trip: trip);
          },
        ),
        GoRoute(
          path: qrScanner,
          builder: (context, state) {
            final scheduleId = state.uri.queryParameters['scheduleId'];
            final trip = state.extra is OperatorTripModel
                ? state.extra! as OperatorTripModel
                : null;
            return QrScannerScreen(scheduleId: scheduleId, trip: trip);
          },
        ),
        GoRoute(
          path: adminDashboard,
          builder: (context, state) => const AdminDashboardPage(),
        ),
      ],
    );
  }
}

/// Notifies [GoRouter] when [AuthBloc] emits a new state.
class GoRouterAuthRefresh extends ChangeNotifier {
  GoRouterAuthRefresh(AuthBloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
