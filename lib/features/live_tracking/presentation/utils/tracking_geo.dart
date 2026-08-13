import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Approximate city coordinates used for route polylines / map framing.
class SriLankaCityCoords {
  SriLankaCityCoords._();

  static const Map<String, LatLng> _coords = {
    'Colombo': LatLng(6.9271, 79.8612),
    'Kandy': LatLng(7.2906, 80.6337),
    'Galle': LatLng(6.0535, 80.2210),
    'Matara': LatLng(5.9549, 80.5550),
    'Jaffna': LatLng(9.6615, 80.0255),
    'Anuradhapura': LatLng(8.3114, 80.4037),
    'Trincomalee': LatLng(8.5874, 81.2152),
    'Kurunegala': LatLng(7.4863, 80.3623),
    'Negombo': LatLng(7.2083, 79.8358),
    'Nuwara Eliya': LatLng(6.9497, 80.7891),
    'Batticaloa': LatLng(7.7102, 81.6924),
    'Badulla': LatLng(6.9934, 81.0550),
    'Ratnapura': LatLng(6.7056, 80.3847),
    'Hambantota': LatLng(6.1244, 81.1185),
  };

  static LatLng? of(String city) {
    final direct = _coords[city];
    if (direct != null) return direct;
    final key = _coords.keys.firstWhere(
      (k) => city.toLowerCase().contains(k.toLowerCase()),
      orElse: () => '',
    );
    return key.isEmpty ? null : _coords[key];
  }

  static double haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  /// ETA minutes using live speed, or scheduled average if speed is too low.
  static int? etaMinutes({
    required LatLng from,
    required LatLng to,
    double? speedKmh,
    int? fallbackDurationMinutes,
    double? routeDistanceKm,
  }) {
    final distance = haversineKm(from, to);
    final speed = speedKmh ?? 0;
    if (speed >= 5) {
      return (distance / speed * 60).ceil().clamp(1, 24 * 60);
    }
    if (routeDistanceKm != null &&
        routeDistanceKm > 0 &&
        fallbackDurationMinutes != null &&
        fallbackDurationMinutes > 0) {
      final remainingRatio = (distance / routeDistanceKm).clamp(0.0, 1.0);
      return (fallbackDurationMinutes * remainingRatio).ceil().clamp(1, 24 * 60);
    }
    // Assume ~40 km/h average for Sri Lanka highways.
    return (distance / 40 * 60).ceil().clamp(1, 24 * 60);
  }
}
