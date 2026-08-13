import 'package:lanka_bus/core/constants/sri_lanka_cities.dart';
import 'package:lanka_bus/features/bus_search/data/datasources/bus_search_remote_datasource.dart';
import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';
import 'package:lanka_bus/features/bus_search/domain/entities/bus_search_query.dart';
import 'package:lanka_bus/features/bus_search/domain/repositories/bus_search_repository.dart';

class BusSearchRepositoryImpl implements BusSearchRepository {
  BusSearchRepositoryImpl(this._remote);

  final BusSearchRemoteDataSource _remote;

  @override
  Future<List<BusScheduleModel>> searchSchedules(BusSearchQuery query) async {
    if (!query.isValid) {
      throw ArgumentError('Origin and destination must be different cities.');
    }

    final rows = await _remote.searchSchedules(
      originCity: query.originCity.trim(),
      destinationCity: query.destinationCity.trim(),
      dayStart: query.dayStart,
      dayEnd: query.dayEnd,
    );

    return rows.map(BusScheduleModel.fromJoinedJson).toList();
  }

  @override
  Future<List<String>> fetchCities() async {
    try {
      final fromDb = await _remote.fetchDistinctCities();
      if (fromDb.isEmpty) return SriLankaCities.all;
      final merged = {...SriLankaCities.all, ...fromDb}.toList()..sort();
      return merged;
    } catch (_) {
      return SriLankaCities.all;
    }
  }
}
