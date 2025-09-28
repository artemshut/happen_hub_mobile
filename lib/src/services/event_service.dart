import 'dart:convert';
import '../services/api_client.dart';
import '../services/json_api_parser.dart';
import '../models/event.dart';
import 'package:flutter/material.dart';

class EventRepository {
  final ApiClient _client = ApiClient();

  Future<List<Event>> fetchEvents(BuildContext context) async {
    final res = await _client.get("/events");
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return JsonApiParser.parseEvents(body);
    } else {
      throw Exception("Failed to load events");
    }
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