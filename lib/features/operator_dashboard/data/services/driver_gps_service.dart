import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lanka_bus/features/operator_dashboard/domain/repositories/operator_repository.dart';

/// Streams device GPS and upserts into `bus_locations` while a trip is active.
class DriverGpsService extends ChangeNotifier {
  DriverGpsService(this._repository);

  final OperatorRepository _repository;

  StreamSubscription<Position>? _subscription;
  Timer? _heartbeat;
  bool _active = false;
  String? _busId;
  String? _scheduleId;
  String? _routeLabel;
  String? _lastError;
  DateTime? _lastUpdateAt;
  Position? _lastPosition;

  bool get isActive => _active;
  String? get routeLabel => _routeLabel;
  String? get lastError => _lastError;
  DateTime? get lastUpdateAt => _lastUpdateAt;
  Position? get lastPosition => _lastPosition;
  String? get activeScheduleId => _scheduleId;

  Future<bool> ensurePermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _lastError = 'Location services are disabled.';
      notifyListeners();
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _lastError = 'Location permission denied.';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> startTrip({
    required String busId,
    required String scheduleId,
    required String routeLabel,
  }) async {
    if (_active) {
      await stopTrip();
    }

    final ok = await ensurePermissions();
    if (!ok) return;

    _busId = busId;
    _scheduleId = scheduleId;
    _routeLabel = routeLabel;
    _active = true;
    _lastError = null;
    notifyListeners();

    // Immediate fix then periodic stream (~12s).
    await _publishCurrent();

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen(
      _onPosition,
      onError: (Object error) {
        _lastError = error.toString();
        notifyListeners();
      },
    );

    _heartbeat = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_publishCurrent());
    });
  }

  Future<void> stopTrip() async {
    await _subscription?.cancel();
    _subscription = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _active = false;
    _busId = null;
    _scheduleId = null;
    _routeLabel = null;
    notifyListeners();
  }

  Future<void> _onPosition(Position position) async {
    _lastPosition = position;
    await _upsert(position);
  }

  Future<void> _publishCurrent() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _lastPosition = position;
      await _upsert(position);
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
    }
  }

  Future<void> _upsert(Position position) async {
    final busId = _busId;
    final scheduleId = _scheduleId;
    if (!_active || busId == null || scheduleId == null) return;

    try {
      await _repository.upsertBusLocation(
        busId: busId,
        scheduleId: scheduleId,
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: position.speed * 3.6,
        heading: position.heading >= 0 ? position.heading : null,
      );
      _lastUpdateAt = DateTime.now();
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(stopTrip());
    super.dispose();
  }
}
