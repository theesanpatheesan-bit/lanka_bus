import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lanka_bus/core/utils/formatters.dart';
import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';
import 'package:lanka_bus/features/bus_search/presentation/bloc/bus_search_bloc.dart';
import 'package:lanka_bus/features/bus_search/presentation/widgets/bus_card_widget.dart';
import 'package:lanka_bus/features/bus_search/presentation/widgets/search_filter_bottom_sheet.dart';

class BusResultsScreen extends StatelessWidget {
  const BusResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BusSearchBloc, BusSearchState>(
      builder: (context, state) {
        final query = state.query;
        final results = state.visibleResults;
        final title = query == null
            ? 'Results'
            : '${query.originCity} → ${query.destinationCity}';

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18)),
                if (query != null)
                  Text(
                    Formatters.date(query.departureDate),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Edit'),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      state.status == BusSearchStatus.empty
                          ? '0 buses'
                          : '${results.length} bus${results.length == 1 ? '' : 'es'}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: state.rawResults.isEmpty
                          ? null
                          : () async {
                              final applied = await showSearchFilterBottomSheet(
                                context: context,
                                initial: state.filters,
                                operators: state.availableOperators,
                              );
                              if (applied != null && context.mounted) {
                                context
                                    .read<BusSearchBloc>()
                                    .add(BusSearchFiltersApplied(applied));
                              }
                            },
                      icon: Badge(
                        isLabelVisible: state.filters.hasActiveFilters,
                        child: const Icon(Icons.tune),
                      ),
                      label: const Text('Sort & filter'),
                    ),
                  ],
                ),
              ),
              Expanded(child: _ResultsBody(state: state, results: results)),
            ],
          ),
        );
      },
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.state, required this.results});

  final BusSearchState state;
  final List<BusScheduleModel> results;

  @override
  Widget build(BuildContext context) {
    if (state.status == BusSearchStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == BusSearchStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage ?? 'Something went wrong'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context
                    .read<BusSearchBloc>()
                    .add(const BusSearchSubmitted()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.status == BusSearchStatus.empty || state.rawResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No buses found for this route/date.\nTry another date or swap cities.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No buses match your filters.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context
                    .read<BusSearchBloc>()
                    .add(const BusSearchFiltersReset()),
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return BusCardWidget(schedule: results[index]);
      },
    );
  }
}
