import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';

/// Maps authenticated roles to home routes and guards deep links.
class RoleRouter {
  RoleRouter._();

  static String homeFor(UserRole role) => role.homeRoute;

  static const _passengerRoutes = {
    AppRouter.passengerHome,
    AppRouter.busSearch,
    AppRouter.busResults,
    AppRouter.seatSelection,
    AppRouter.boardingDropping,
    AppRouter.passengerDetails,
    AppRouter.payment,
    AppRouter.mTicket,
    AppRouter.liveTracking,
  };

  static const _staffRoutes = {
    AppRouter.operatorDashboard,
    AppRouter.seatChart,
    AppRouter.qrScanner,
    AppRouter.liveTracking,
  };

  static bool canAccess(UserRole role, String location) {
    switch (role) {
      case UserRole.passenger:
        return _passengerRoutes.contains(location);
      case UserRole.operator:
      case UserRole.conductor:
        return _staffRoutes.contains(location);
      case UserRole.admin:
        return location == AppRouter.adminDashboard ||
            _staffRoutes.contains(location);
    }
  }
}
