import 'package:bus_app/features/passenger/data/models/route_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> busLeg(String route, String from, String to) => {
      'mode': 'bus',
      'route_name': route,
      'from_stop': {'name': from, 'lat': 36.2, 'lng': 37.1},
      'to_stop': {'name': to, 'lat': 36.21, 'lng': 37.15},
      'stop_count': 4,
      'duration_minutes': 12,
      'active_buses': 2,
    };

void main() {
  group('parseRouteSuggestions', () {
    test('keeps more than one direct suggestion', () {
      final result = parseRouteSuggestions([
        {
          'type': 'direct',
          'total_duration_minutes': 28,
          'walking_distance_meters': 320,
          'walking_time_minutes': 5,
          'legs': [busLeg('الأول', 'أ', 'ب')],
        },
        {
          'type': 'direct',
          'total_duration': '31',
          'legs': [busLeg('الثاني', 'ج', 'د')],
        },
      ]);

      expect(result, hasLength(2));
      expect(result.first.walkingTimeMinutes, 5);
      expect(result.last.totalDurationMinutes, 31);
    });

    test('parses transfer and preserves ordered bus legs and transfer stop', () {
      final result = parseRouteSuggestions([
        {
          'type': 'transfer',
          'transit_type': 'transfer',
          'transfer_stop': {
            'from_stop': {'name': 'موقف التحويل'},
            'to_stop': {'name': 'الموقف المقابل'},
            'walking_distance_meters': 80,
          },
          'legs': [
            busLeg('الخط الأول', 'البداية', 'موقف التحويل'),
            {
              'mode': 'walking',
              'purpose': 'transfer',
              'from': {'name': 'موقف التحويل'},
              'to': {'name': 'الموقف المقابل'},
              'distance_meters': 80,
              'duration_minutes': 2,
            },
            busLeg('الخط الثاني', 'الموقف المقابل', 'النهاية'),
          ],
        },
      ]).single;

      expect(result.transitType, 'transfer');
      expect(result.transferStopName, 'موقف التحويل');
      expect(result.legs.map((leg) => leg.routeName),
          ['الخط الأول', null, 'الخط الثاني']);
    });

    test('parses walking_required and calculates missing walking totals', () {
      final result = parseRouteSuggestions([
        {
          'type': 'walking_required',
          'transit_type': 'direct',
          'legs': [
            busLeg('الخط', 'أ', 'ب'),
            {
              'mode': 'walking',
              'purpose': 'last_mile',
              'from': {'name': 'ب'},
              'to': 'destination',
              'distance_meters': '450',
              'duration_minutes': '7',
            },
          ],
        },
      ]).single;

      expect(result.type, 'walking_required');
      expect(result.transitType, 'direct');
      expect(result.walkingDistanceMeters, 450);
      expect(result.walkingTimeMinutes, 7);
      expect(result.lastMileWalkingMeters, 450);
    });

    test('parses empty arrays from both endpoints', () {
      expect(parseRouteSuggestions([]), isEmpty);
      expect(parseRouteSuggestions({'plans': []}), isEmpty);
      expect(parseRouteSuggestions(null), isEmpty);
    });
  });
}
