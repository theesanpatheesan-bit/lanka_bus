import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lanka_bus/features/operator_dashboard/data/models/operator_trip_model.dart';
import 'package:lanka_bus/features/operator_dashboard/data/services/driver_gps_service.dart';
import 'package:lanka_bus/features/operator_dashboard/domain/repositories/operator_repository.dart';

class OperatorDashboardScreen extends StatefulWidget {
  const OperatorDashboardScreen({super.key});

  @override
  State<OperatorDashboardScreen> createState() =>
      _OperatorDashboardScreenState();
}

class _OperatorDashboardScreenState extends State<OperatorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<OperatorTripModel> _today = [];
  List<OperatorTripModel> _upcoming = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = context.read<OperatorRepository>();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrow = todayStart.add(const Duration(days: 1));
      final upcomingEnd = todayStart.add(const Duration(days: 14));

      final today = await repo.fetchTrips(from: todayStart, to: tomorrow);
      final upcoming = await repo.fetchTrips(from: tomorrow, to: upcomingEnd);

      if (!mounted) return;
      setState(() {
        _today = today;
        _upcoming = upcoming;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final gps = context.watch<DriverGpsService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operator Dashboard'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (gps.isActive)
            MaterialBanner(
              content: Text(
                'Live GPS Tracking Active'
                '${gps.routeLabel != null ? ' · ${gps.routeLabel}' : ''}',
              ),
              leading: const Icon(Icons.gps_fixed, color: Colors.green),
              actions: [
                TextButton(
                  onPressed: () async {
                    await gps.stopTrip();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Trip tracking stopped')),
                      );
                    }
                  },
                  child: const Text('Stop Trip'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Welcome, ${user?.fullName ?? 'Partner'} · ${user?.role.label ?? ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _TripList(
                            trips: _today,
                            emptyLabel: 'No trips scheduled for today.',
                            gps: gps,
                            onChanged: _load,
                          ),
                          _TripList(
                            trips: _upcoming,
                            emptyLabel: 'No upcoming trips in the next 2 weeks.',
                            gps: gps,
                            onChanged: _load,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({
    required this.trips,
    required this.emptyLabel,
    required this.gps,
    required this.onChanged,
  });

  final List<OperatorTripModel> trips;
  final String emptyLabel;
  final DriverGpsService gps;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          return _TripCard(trip: trip, gps: gps);
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.gps});

  final OperatorTripModel trip;
  final DriverGpsService gps;

  @override
  Widget build(BuildContext context) {
    final trackingThis = gps.isActive && gps.activeScheduleId == trip.scheduleId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trip.routeLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${Formatters.date(trip.departureAt)} · ${Formatters.time(trip.departureAt)}',
            ),
            Text('Bus ${trip.busRegistration} (${trip.busNumber})'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trip.bookedSeats}/${trip.totalSeats} Seats Booked',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: trip.occupancy.clamp(0, 1),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  Formatters.priceLkr(trip.revenueLkr),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => context.push(
                    '${AppRouter.seatChart}?scheduleId=${trip.scheduleId}',
                    extra: trip,
                  ),
                  child: const Text('View Seat Chart'),
                ),
                FilledButton.tonal(
                  onPressed: () => context.push(
                    '${AppRouter.qrScanner}?scheduleId=${trip.scheduleId}',
                    extra: trip,
                  ),
                  child: const Text('Scan Tickets'),
                ),
                FilledButton(
                  onPressed: trackingThis
                      ? () => gps.stopTrip()
                      : () async {
                          await gps.startTrip(
                            busId: trip.busId,
                            scheduleId: trip.scheduleId,
                            routeLabel: trip.routeLabel,
                          );
                          if (context.mounted && gps.lastError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(gps.lastError!)),
                            );
                          }
                        },
                  child: Text(
                    trackingThis ? 'Stop Trip' : 'Start Trip (Live GPS)',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
