import 'package:lanka_bus/features/bus_search/data/models/bus_schedule_model.dart';
import 'package:lanka_bus/features/bus_search/domain/entities/bus_search_query.dart';

abstract class BusSearchRepository {
  Future<List<BusScheduleModel>> searchSchedules(BusSearchQuery query);

  Future<List<String>> fetchCities();
}
