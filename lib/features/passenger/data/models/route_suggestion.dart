double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _integer(dynamic value) => _number(value).round();

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class RoutePoint {
  const RoutePoint({this.id, required this.name, this.lat, this.lng});

  final int? id;
  final String name;
  final double? lat;
  final double? lng;

  factory RoutePoint.fromJson(dynamic value) {
    if (value is String) {
      return RoutePoint(
        name: value == 'user_location'
            ? 'موقعك الحالي'
            : value == 'destination'
                ? 'وجهتك'
                : value,
      );
    }
    final json = _map(value);
    return RoutePoint(
      id: json['station_id'] is num ? (json['station_id'] as num).toInt() : null,
      name: (json['name'] ?? json['station_name'] ?? '—').toString(),
      lat: json['lat'] == null ? null : _number(json['lat']),
      lng: json['lng'] == null ? null : _number(json['lng']),
    );
  }
}

enum RouteLegMode { walking, waiting, bus, unknown }

class RouteLeg {
  const RouteLeg({
    required this.mode,
    this.purpose,
    required this.from,
    required this.to,
    required this.durationMinutes,
    required this.distanceMeters,
    this.routeId,
    this.routeName,
    this.direction,
    required this.stopCount,
    required this.activeBuses,
    this.busEta,
  });

  final RouteLegMode mode;
  final String? purpose;
  final RoutePoint from;
  final RoutePoint to;
  final int durationMinutes;
  final int distanceMeters;
  final int? routeId;
  final String? routeName;
  final String? direction;
  final int stopCount;
  final int activeBuses;
  final int? busEta;

  factory RouteLeg.fromJson(dynamic value) {
    final json = _map(value);
    final mode = switch (json['mode'] ?? json['action']) {
      'walking' || 'walk' => RouteLegMode.walking,
      'waiting' || 'wait' => RouteLegMode.waiting,
      'bus' => RouteLegMode.bus,
      _ => RouteLegMode.unknown,
    };
    final isBus = mode == RouteLegMode.bus;
    return RouteLeg(
      mode: mode,
      purpose: json['purpose']?.toString(),
      from: RoutePoint.fromJson(isBus ? json['from_stop'] ?? json['from'] : json['from']),
      to: RoutePoint.fromJson(isBus ? json['to_stop'] ?? json['to'] : json['to']),
      durationMinutes: _integer(json['duration_minutes'] ?? json['minutes']),
      distanceMeters: _integer(json['distance_meters'] ?? json['meters']),
      routeId: json['route_id'] is num ? (json['route_id'] as num).toInt() : null,
      routeName: json['route_name']?.toString(),
      direction: json['direction']?.toString(),
      stopCount: _integer(json['stop_count'] ?? json['stations']),
      activeBuses: _integer(json['active_buses'] ?? json['buses']),
      busEta: json['bus_eta'] == null ? null : _integer(json['bus_eta']),
    );
  }

  Map<String, dynamic> toViewMap() => {
        'action': switch (mode) {
          RouteLegMode.walking => 'walk',
          RouteLegMode.waiting => 'wait',
          RouteLegMode.bus => 'bus',
          RouteLegMode.unknown => 'unknown',
        },
        'purpose': purpose,
        'from': from.name,
        'to': to.name,
        'from_lat': from.lat,
        'from_lng': from.lng,
        'to_lat': to.lat,
        'to_lng': to.lng,
        'minutes': durationMinutes,
        'meters': distanceMeters,
        'route_id': routeId,
        'route_name': routeName,
        'direction': direction,
        'stations': stopCount,
        'buses': activeBuses,
        'bus_eta': busEta,
      };
}

class RouteSuggestion {
  const RouteSuggestion({
    required this.type,
    required this.transitType,
    required this.totalDurationMinutes,
    required this.walkingDistanceMeters,
    required this.walkingTimeMinutes,
    required this.legs,
    this.transferStopName,
    required this.lastMileWalkingMeters,
    this.tag,
    this.legacyWalkToStation = 0,
    this.legacyFromStationLat,
    this.legacyFromStationLng,
  });

  final String type;
  final String transitType;
  final int totalDurationMinutes;
  final int walkingDistanceMeters;
  final int walkingTimeMinutes;
  final List<RouteLeg> legs;
  final String? transferStopName;
  final int lastMileWalkingMeters;
  final String? tag;
  final int legacyWalkToStation;
  final double? legacyFromStationLat;
  final double? legacyFromStationLng;

  factory RouteSuggestion.fromJson(dynamic value) {
    final json = _map(value);
    final legs = (json['legs'] is List ? json['legs'] as List : const <dynamic>[])
        .map(RouteLeg.fromJson)
        .toList(growable: false);
    final walkingLegs = legs.where((leg) => leg.mode == RouteLegMode.walking);
    final transfer = _map(json['transfer_stop']);
    final transferFrom = RoutePoint.fromJson(transfer['from_stop']);
    final transferTo = RoutePoint.fromJson(transfer['to_stop']);
    final inferredTransitType =
        legs.where((leg) => leg.mode == RouteLegMode.bus).length > 1 ? 'transfer' : 'direct';
    final type = (json['type'] ?? 'direct').toString();
    final walkingDistance = json['walking_distance_meters'] != null
        ? _integer(json['walking_distance_meters'])
        : json['total_walking'] != null
            ? _integer(json['total_walking'])
            : walkingLegs.fold(0, (sum, leg) => sum + leg.distanceMeters);
    final walkingLegMinutes =
        walkingLegs.fold(0, (sum, leg) => sum + leg.durationMinutes);
    final reportedWalkingTime = _integer(json['walking_time_minutes']);
    final walkingTime = reportedWalkingTime > 0
        ? reportedWalkingTime
        : walkingLegMinutes > 0
            ? walkingLegMinutes
            : walkingDistance > 0
                ? (walkingDistance / 80).ceil()
                : 0;
    return RouteSuggestion(
      type: type,
      transitType: (json['transit_type'] ?? (type == 'walking_required' ? inferredTransitType : type)).toString(),
      totalDurationMinutes: _integer(
        json['total_duration_minutes'] ?? json['total_duration'] ?? json['total_minutes'],
      ),
      walkingDistanceMeters: walkingDistance,
      walkingTimeMinutes: walkingTime,
      legs: legs,
      transferStopName: transferFrom.name != '—'
          ? transferFrom.name
          : transferTo.name != '—'
              ? transferTo.name
              : null,
      lastMileWalkingMeters: legs
          .where((leg) => leg.mode == RouteLegMode.walking && leg.purpose == 'last_mile')
          .fold(0, (sum, leg) => sum + leg.distanceMeters),
      tag: json['tag']?.toString(),
      legacyWalkToStation: _integer(json['walk_to_station']),
      legacyFromStationLat: json['from_station_lat'] == null
          ? null
          : _number(json['from_station_lat']),
      legacyFromStationLng: json['from_station_lng'] == null
          ? null
          : _number(json['from_station_lng']),
    );
  }

  Map<String, dynamic> toViewMap() {
    final viewLegs = legs.map((leg) => leg.toViewMap()).toList();
    final access = legs.where((leg) => leg.mode == RouteLegMode.walking && leg.purpose == 'access');
    final firstAccess = access.isEmpty ? null : access.first;
    return {
      'type': type,
      'transit_type': transitType,
      'total_minutes': totalDurationMinutes,
      'total_walking': walkingDistanceMeters,
      'walking_time_minutes': walkingTimeMinutes,
      'walk_to_station': firstAccess?.distanceMeters ?? legacyWalkToStation,
      'from_station_lat': firstAccess?.to.lat ?? legacyFromStationLat,
      'from_station_lng': firstAccess?.to.lng ?? legacyFromStationLng,
      'transfer_stop_name': transferStopName,
      'last_mile_walking': lastMileWalkingMeters,
      'tag': tag,
      'legs': viewLegs,
    };
  }
}

List<RouteSuggestion> parseRouteSuggestions(dynamic data) {
  final raw = data is List
      ? data
      : data is Map && data['plans'] is List
          ? data['plans'] as List
          : const <dynamic>[];
  return raw.map(RouteSuggestion.fromJson).toList(growable: false);
}
