// lib/utils/json_api_parser.dart
import 'dart:convert';
import '../models/event.dart';
import '../models/group.dart';

class JsonApiParser {
  /// Parse a list of events from a JSON:API response
  static List<Event> parseEvents(String responseBody) {
    try {
      final Map<String, dynamic> json = jsonDecode(responseBody);

      final Map<String, Map<String, dynamic>> includedByType = {};
      if (json['included'] != null) {
        for (var inc in json['included']) {
          includedByType.putIfAbsent(inc['type'], () => {});
          includedByType[inc['type']]![inc['id']] = inc;
        }
      }

      final data = json['data'] as List<dynamic>;
      return data
          .map((e) => Event.fromJson(e, included: includedByType))
          .toList();
    } catch (e, stack) {
      print("❌ JSON parse error: $e");
      print(stack);
      rethrow;
    }
  }

  /// Parse a single event from a JSON:API response
  static Event parseEvent(String responseBody) {
    final Map<String, dynamic> json = jsonDecode(responseBody);

    final Map<String, Map<String, dynamic>> includedByType = {};
    if (json['included'] != null) {
      for (var inc in json['included']) {
        includedByType.putIfAbsent(inc['type'], () => {});
        includedByType[inc['type']]![inc['id']] = inc;
      }
    }

    final data = json['data'];
    return Event.fromJson(data, included: includedByType);
  }

  /// Parse a list of groups from a JSON:API response
  static List<Group> parseGroups(String responseBody) {
    final Map<String, dynamic> json = jsonDecode(responseBody);

    final Map<String, Map<String, dynamic>> includedByType = {};
    if (json['included'] != null) {
      for (final inc in json['included']) {
        includedByType.putIfAbsent(inc['type'], () => {});
        includedByType[inc['type']]![inc['id']] = inc;
      }
    }

    final data = (json['data'] as List<dynamic>? ?? const [])
        .map((item) => Group.fromJson(item, included: includedByType))
        .toList();
    return data;
  }
}
