import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';
import 'package:lanka_bus/features/seat_booking/data/models/seat_model.dart';
import 'package:lanka_bus/features/seat_booking/presentation/bloc/seat_booking_bloc.dart';
import 'package:lanka_bus/features/seat_booking/presentation/widgets/seat_grid.dart';
import 'package:lanka_bus/features/seat_booking/presentation/widgets/seat_legend.dart';

class SeatLayoutScreen extends StatefulWidget {
  const SeatLayoutScreen({
    super.key,
    required this.scheduleId,
    this.schedule,
  });

  final String scheduleId;
  final BusScheduleModel? schedule;

  @override
  State<SeatLayoutScreen> createState() => _SeatLayoutScreenState();
}

class _SeatLayoutScreenState extends State<SeatLayoutScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SeatBookingBloc>().add(
          SeatBookingStarted(
            scheduleId: widget.scheduleId,
            schedule: widget.schedule,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SeatBookingBloc, SeatBookingState>(
      listenWhen: (p, n) =>
          p.status != n.status || p.errorMessage != n.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null &&
            state.status == SeatBookingStatus.selectingSeats) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.status == SeatBookingStatus.selectingPoints) {
          context.push(AppRouter.boardingDropping);
        }
      },
      builder: (context, state) {
        final schedule = state.schedule;
        final locking = state.status == SeatBookingStatus.locking;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              schedule == null
                  ? 'Select seats'
                  : '${schedule.route.originCity} → ${schedule.route.destinationCity}',
            ),
          ),
          body: () {
            switch (state.status) {
              case SeatBookingStatus.loadingMap:
              case SeatBookingStatus.initial:
                return const Center(child: CircularProgressIndicator());
              case SeatBookingStatus.failure:
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.errorMessage ?? 'Failed to load seats'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              context.read<SeatBookingBloc>().add(
                                    SeatBookingStarted(
                                      scheduleId: widget.scheduleId,
                                      schedule: widget.schedule,
                                    ),
                                  ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              default:
                return Column(
                  children: [
                    if (schedule != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${schedule.operatorName} · ${schedule.busType.badgeLabel}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Text(Formatters.priceLkr(schedule.basePriceLkr)),
                          ],
                        ),
                      ),
                    if (state.hasUpperDeck)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: SegmentedButton<SeatDeck>(
                          segments: const [
                            ButtonSegment(
                              value: SeatDeck.lower,
                              label: Text('Lower deck'),
                              icon: Icon(Icons.airline_seat_flat),
                            ),
                            ButtonSegment(
                              value: SeatDeck.upper,
                              label: Text('Upper deck'),
                              icon: Icon(Icons.airline_seat_flat_angled),
                            ),
                          ],
                          selected: {state.selectedDeck},
                          onSelectionChanged: (value) {
                            context
                                .read<SeatBookingBloc>()
                                .add(SeatBookingDeckChanged(value.first));
                          },
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: SeatLegend(),
                    ),
                    Expanded(
                      child: SeatGrid(
                        seats: state.seatsForDeck(state.selectedDeck),
                        selectedSeatNumbers: state.selectedSeatNumbers,
                        onSeatTap: (seatNumber) {
                          context
                              .read<SeatBookingBloc>()
                              .add(SeatBookingSeatToggled(seatNumber));
                        },
                      ),
                    ),
                    _SeatSummaryBar(
                      selectedCount: state.selectedSeats.length,
                      total: state.selectedTotal,
                      loading: locking,
                      onContinue: state.selectedSeats.isEmpty || locking
                          ? null
                          : () {
                              final user =
                                  context.read<AuthBloc>().state.user;
                              context.read<SeatBookingBloc>().add(
                                    SeatBookingContinueFromSeats(user: user),
                                  );
                            },
                    ),
                  ],
                );
            }
          }(),
        );
      },
    );
  }
}

class _SeatSummaryBar extends StatelessWidget {
  const _SeatSummaryBar({
    required this.selectedCount,
    required this.total,
    required this.loading,
    required this.onContinue,
  });

  final int selectedCount;
  final double total;
  final bool loading;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedCount == 0
                      ? 'Select seats to continue'
                      : '$selectedCount Seat${selectedCount == 1 ? '' : 's'} Selected | Total ${Formatters.priceLkr(total)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onContinue,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
