import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';

class BusCardWidget extends StatelessWidget {
  const BusCardWidget({super.key, required this.schedule});

  final BusScheduleModel schedule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final boarding =
        schedule.route.originTerminal ?? schedule.route.originCity;
    final dropping =
        schedule.route.destinationTerminal ?? schedule.route.destinationCity;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schedule.operatorName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    schedule.busType.badgeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _TimeBlock(
                    time: Formatters.time(schedule.departureAt),
                    place: boarding,
                    alignEnd: false,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      schedule.durationLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 72,
                      child: Divider(color: scheme.outline),
                    ),
                  ],
                ),
                Expanded(
                  child: _TimeBlock(
                    time: Formatters.time(schedule.arrivalAt),
                    place: dropping,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '★ ${schedule.rating.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A6A00),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (schedule.isSoldOut)
                  _SeatsTag(
                    label: 'Sold out',
                    color: scheme.error,
                  )
                else if (schedule.isLowSeats)
                  _SeatsTag(
                    label: '${schedule.seatsLeft} Seats Left',
                    color: scheme.error,
                  )
                else
                  _SeatsTag(
                    label: '${schedule.seatsLeft} seats',
                    color: scheme.primary,
                  ),
                const Spacer(),
                Text(
                  Formatters.priceLkr(schedule.basePriceLkr),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: schedule.isSoldOut
                    ? null
                    : () => context.push(
                          '${AppRouter.seatSelection}?scheduleId=${schedule.id}',
                          extra: schedule,
                        ),
                child: const Text('Select Seats'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.time,
    required this.place,
    required this.alignEnd,
  });

  final String time;
  final String place;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          time,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          place,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SeatsTag extends StatelessWidget {
  const _SeatsTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}
