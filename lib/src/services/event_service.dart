import 'package:flutter/widgets.dart';

import '../services/api_client.dart';
import '../services/json_api_parser.dart';
import '../models/event.dart';
import 'dart:convert';

class EventRepository {
  final ApiClient _client = ApiClient();

  Future<List<Event>> fetchEvents(BuildContext context) async {
    final upcoming = await _client.get("/events");
    if (upcoming.statusCode != 200) {
      throw Exception("Failed to load events (${upcoming.statusCode})");
    }

    final Map<String, Event> events = {};
    for (final event in JsonApiParser.parseEvents(upcoming.body)) {
      events[event.id] = event;
    }

    final past = await _client.get("/events?past=true");
    if (past.statusCode != 200) {
      throw Exception("Failed to load past events (${past.statusCode})");
    }

    for (final event in JsonApiParser.parseEvents(past.body)) {
      events[event.id] = event;
    }

    return events.values.toList();
  }

  Future<Event> fetchEvent(BuildContext context, String id) async {
    final res = await _client.get("/events/$id");
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return JsonApiParser.parseEvent(body);
    } else {
      throw Exception("Failed to load event $id");
    }
  }
}
