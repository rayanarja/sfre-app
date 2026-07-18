

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_app/features/passenger/data/models/route_suggestion.dart';

void main() {
  test('route parser ignores invalid payloads safely', () {
    expect(parseRouteSuggestions({'unexpected': true}), isEmpty);
  });
}
