import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'models/route_suggestion.dart';

class RouteSuggestionsService {
  RouteSuggestionsService({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  Future<List<Map<String, dynamic>>> searchDestinations(String query) async {
    final response = await _dio.get(
      '/stations/hybrid-suggestions',
      queryParameters: {'q': query},
    );
    final data = response.data;
    if (data is! List) return [];
    return data.map<Map<String, dynamic>>((item) {
      if (item is String) return {'name': item, 'type': 'station'};
      return item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    }).where((item) => item.isNotEmpty).toList();
  }

  Future<List<RouteSuggestion>> suggestionsForCoordinates({
    required double userLat,
    required double userLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final response = await _dio.post(
      '/stations/hybrid-suggestions',
      data: {
        'user_location': {'lat': userLat, 'lng': userLng},
        'destination_coords': {'lat': destinationLat, 'lng': destinationLng},
      },
    );
    return parseRouteSuggestions(response.data);
  }

  Future<List<RouteSuggestion>> planForText({
    required String destination,
    required double userLat,
    required double userLng,
  }) async {
    final response = await _dio.get(
      '/stations/plan-route-v2',
      queryParameters: {'destination': destination, 'lat': userLat, 'lng': userLng},
    );
    return parseRouteSuggestions(response.data);
  }
}
