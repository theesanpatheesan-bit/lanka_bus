/// App-wide constants for Lanka Bus.
class AppConstants {
  AppConstants._();

  static const String appName = 'Lanka Bus';
  static const String currencyCode = 'LKR';
  static const String currencySymbol = 'Rs.';
  static const String defaultCountryCode = '+94';
  static const String timezone = 'Asia/Colombo';

  /// Soft seat hold duration during checkout.
  static const Duration seatLockDuration = Duration(minutes: 10);

  static const int maxSeatsPerBooking = 6;
}
