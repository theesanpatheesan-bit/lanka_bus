import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/live_tracking/data/models/live_tracking_snapshot.dart';
import 'package:lanka_bus/features/live_tracking/domain/repositories/live_tracking_repository.dart';
import 'package:lanka_bus/features/live_tracking/presentation/utils/tracking_geo.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({
    super.key,
    this.scheduleId,
    this.busId,
    this.boardingPointName,
  });

  final String? scheduleId;
  final String? busId;
  final String? boardingPointName;

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _map;
  StreamSubscription<LiveTrackingSnapshot>? _sub;
  LiveTrackingSnapshot? _snap;
  String? _error;
  bool _loading = true;
  bool _followBus = true;

  static const _sriLanka = CameraPosition(
    target: LatLng(7.8731, 80.7718),
    zoom: 7.2,
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = context.read<LiveTrackingRepository>();
    try {
      final snap = await repo.fetchSnapshot(
        scheduleId: widget.scheduleId,
        busId: widget.busId,
      );
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _loading = false;
      });
      await _sub?.cancel();
      _sub = repo
          .watchBusLocation(busId: snap.busId, seed: snap)
          .listen((next) {
        if (!mounted) return;
        setState(() => _snap = next);
        if (_followBus && next.hasPosition) {
          _animateToBus(next);
        }
      });
      if (snap.hasPosition) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animateToBus(snap, zoom: 12.5);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _animateToBus(LiveTrackingSnapshot snap, {double zoom = 13}) async {
    final map = _map;
    if (map == null || !snap.hasPosition) return;
    await map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(snap.latitude!, snap.longitude!),
          zoom: zoom,
          bearing: snap.headingDegrees ?? 0,
          tilt: 25,
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _share() async {
    final snap = _snap;
    if (snap == null) return;
    final sid = snap.scheduleId ?? widget.scheduleId ?? '';
    final link = 'lankabus://live-tracking?scheduleId=$sid';
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Track ${snap.busNumber} live on Lanka Bus (${snap.routeLabel}):\n$link',
        subject: 'Live bus tracking',
      ),
    );
  }

  Set<Marker> _markers(LiveTrackingSnapshot snap) {
    final markers = <Marker>{};
    final origin = SriLankaCityCoords.of(snap.originCity);
    final dest = SriLankaCityCoords.of(snap.destinationCity);
    if (origin != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: origin,
          infoWindow: InfoWindow(title: snap.originCity, snippet: 'Origin'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    if (dest != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: dest,
          infoWindow:
              InfoWindow(title: snap.destinationCity, snippet: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }
    if (snap.hasPosition) {
      markers.add(
        Marker(
          markerId: const MarkerId('bus'),
          position: LatLng(snap.latitude!, snap.longitude!),
          rotation: snap.headingDegrees ?? 0,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: snap.busNumber,
            snippet: snap.isOnline ? 'Live' : 'Last known',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _polylines(LiveTrackingSnapshot snap) {
    final origin = SriLankaCityCoords.of(snap.originCity);
    final dest = SriLankaCityCoords.of(snap.destinationCity);
    if (origin == null || dest == null) return {};
    final points = <LatLng>[origin];
    if (snap.hasPosition) {
      points.add(LatLng(snap.latitude!, snap.longitude!));
    }
    points.add(dest);
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        color: const Color(0xFF0B6E4F),
        width: 5,
        points: points,
        patterns: snap.isOnline ? const [] : [PatternItem.dash(18), PatternItem.gap(10)],
      ),
    };
  }

  String? _nextStopName(LiveTrackingSnapshot snap) {
    if (widget.boardingPointName != null &&
        widget.boardingPointName!.trim().isNotEmpty) {
      return widget.boardingPointName;
    }
    if (snap.boardingPoints.isNotEmpty) return snap.boardingPoints.first.name;
    return snap.originTerminal ?? snap.originCity;
  }

  String _etaLabel(LiveTrackingSnapshot snap) {
    final stopName = _nextStopName(snap);
    final stopCityGuess = SriLankaCityCoords.of(stopName ?? '') ??
        SriLankaCityCoords.of(snap.originCity);
    if (!snap.hasPosition || stopCityGuess == null) {
      if (snap.departureAt != null) {
        return 'Scheduled boarding ${Formatters.time(snap.departureAt!)}';
      }
      return 'ETA unavailable';
    }
    final mins = SriLankaCityCoords.etaMinutes(
      from: LatLng(snap.latitude!, snap.longitude!),
      to: stopCityGuess,
      speedKmh: snap.speedKmh,
      fallbackDurationMinutes: snap.estimatedDurationMinutes,
      routeDistanceKm: snap.distanceKm,
    );
    if (mins == null) return 'ETA unavailable';
    if (mins < 60) return 'ETA $mins min to $stopName';
    final h = mins ~/ 60;
    final m = mins % 60;
    return 'ETA ${h}h ${m}m to $stopName';
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(snap?.busNumber.isNotEmpty == true
            ? 'Track ${snap!.busNumber}'
            : 'Live Tracking'),
        actions: [
          IconButton(
            tooltip: _followBus ? 'Following bus' : 'Follow bus',
            onPressed: () => setState(() => _followBus = !_followBus),
            icon: Icon(_followBus ? Icons.gps_fixed : Icons.gps_not_fixed),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _bootstrap,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: snap?.hasPosition == true
                          ? CameraPosition(
                              target:
                                  LatLng(snap!.latitude!, snap.longitude!),
                              zoom: 12.5,
                            )
                          : _sriLanka,
                      myLocationButtonEnabled: false,
                      compassEnabled: true,
                      markers: snap == null ? {} : _markers(snap),
                      polylines: snap == null ? {} : _polylines(snap),
                      onMapCreated: (c) => _map = c,
                      onCameraMoveStarted: () {
                        // User interaction pauses follow until they re-enable.
                      },
                    ),
                    if (snap != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(12),
                          color: snap.isOnline
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEF3C7),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  snap.isOnline
                                      ? Icons.sensors
                                      : Icons.sensors_off,
                                  color: snap.isOnline
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF92400E),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    snap.connectionLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: snap.isOnline
                                          ? const Color(0xFF166534)
                                          : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (snap != null)
                      DraggableScrollableSheet(
                        initialChildSize: 0.34,
                        minChildSize: 0.22,
                        maxChildSize: 0.55,
                        builder: (context, controller) {
                          return Material(
                            elevation: 8,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            color: scheme.surface,
                            child: ListView(
                              controller: controller,
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                              children: [
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: scheme.outlineVariant,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                Text(
                                  snap.routeLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${snap.busNumber}'
                                  '${snap.busRegistration != null ? ' · ${snap.busRegistration}' : ''}',
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _InfoChip(
                                        icon: Icons.flag_outlined,
                                        label: 'Next stop',
                                        value: _nextStopName(snap) ?? '—',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _InfoChip(
                                        icon: Icons.speed,
                                        label: 'Speed',
                                        value: snap.speedKmh == null
                                            ? '—'
                                            : '${snap.speedKmh!.toStringAsFixed(0)} km/h',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _InfoChip(
                                  icon: Icons.schedule,
                                  label: 'Arrival',
                                  value: _etaLabel(snap),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: snap.contactPhone.isEmpty
                                            ? null
                                            : () => _call(snap.contactPhone),
                                        icon: const Icon(Icons.call),
                                        label: const Text('Call crew'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _share,
                                        icon: const Icon(Icons.share_outlined),
                                        label: const Text('Share live'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
