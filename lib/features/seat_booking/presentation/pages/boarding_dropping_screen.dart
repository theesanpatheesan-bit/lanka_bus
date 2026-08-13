import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/features/seat_booking/data/models/passenger_model.dart';
import 'package:lanka_bus/features/seat_booking/presentation/bloc/seat_booking_bloc.dart';

class BoardingDroppingScreen extends StatelessWidget {
  const BoardingDroppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: BlocConsumer<SeatBookingBloc, SeatBookingState>(
        listenWhen: (p, n) =>
            p.status != n.status || p.errorMessage != n.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null &&
              state.status == SeatBookingStatus.selectingPoints) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          if (state.status == SeatBookingStatus.passengerDetails) {
            context.push(AppRouter.passengerDetails);
          }
        },
        builder: (context, state) {
          final departure = state.schedule?.departureAt;
          final arrival = state.schedule?.arrivalAt;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Boarding & dropping'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Boarding points'),
                  Tab(text: 'Dropping points'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _PointsList(
                  points: state.boardingPoints,
                  selectedId: state.boardingPointId,
                  anchor: departure,
                  isBoarding: true,
                  onSelected: (id) => context
                      .read<SeatBookingBloc>()
                      .add(SeatBookingBoardingSelected(id)),
                ),
                _PointsList(
                  points: state.droppingPoints,
                  selectedId: state.droppingPointId,
                  anchor: arrival,
                  isBoarding: false,
                  onSelected: (id) => context
                      .read<SeatBookingBloc>()
                      .add(SeatBookingDroppingSelected(id)),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => context
                      .read<SeatBookingBloc>()
                      .add(const SeatBookingContinueFromPoints()),
                  child: const Text('Continue to passenger details'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PointsList extends StatelessWidget {
  const _PointsList({
    required this.points,
    required this.selectedId,
    required this.anchor,
    required this.isBoarding,
    required this.onSelected,
  });

  final List<RoutePointModel> points;
  final String? selectedId;
  final DateTime? anchor;
  final bool isBoarding;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('No points available for this route'));
    }

    final timeFmt = DateFormat('hh:mm a');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: points.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final point = points[index];
        final selected = point.id == selectedId;
        DateTime? stamp;
        if (anchor != null) {
          stamp = isBoarding
              ? anchor!.add(Duration(minutes: point.offsetMinutes))
              : anchor!.add(Duration(minutes: point.offsetMinutes));
        }

        return Material(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(point.id),
            child: ListTile(
              leading: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                point.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                stamp == null ? point.name : timeFmt.format(stamp),
              ),
            ),
          ),
        );
      },
    );
  }
}
