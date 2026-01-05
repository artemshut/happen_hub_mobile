import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_checklist.dart';

class ChecklistPendingOp {
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const ChecklistPendingOp({
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  ChecklistPendingOp copyWith({
    String? type,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
  }) {
    return ChecklistPendingOp(
      type: type ?? this.type,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        "type": type,
        "payload": payload,
        "created_at": createdAt.toIso8601String(),
      };

  factory ChecklistPendingOp.fromJson(Map<String, dynamic> json) {
    return ChecklistPendingOp(
      type: (json["type"] ?? "").toString(),
      payload: (json["payload"] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: DateTime.tryParse(json["created_at"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }
}

class ChecklistStorage {
  static const _cachePrefix = "event_checklists_cache_";
  static const _pendingPrefix = "event_checklists_pending_";

  Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  String _cacheKey(String eventId) => "$_cachePrefix$eventId";
  String _pendingKey(String eventId) => "$_pendingPrefix$eventId";

  Future<void> saveCache(
    String eventId,
    List<EventChecklist> lists,
  ) async {
    final prefs = await _prefs;
    final value = EventChecklist.encodeList(lists);
    await prefs.setString(_cacheKey(eventId), value);
  }

  Future<List<EventChecklist>> readCache(String eventId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_cacheKey(eventId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      return EventChecklist.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearCache(String eventId) async {
    final prefs = await _prefs;
    await prefs.remove(_cacheKey(eventId));
  }

  Future<List<ChecklistPendingOp>> readPendingOps(String eventId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_pendingKey(eventId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .map((item) => ChecklistPendingOp.fromJson(
                  (item as Map).cast<String, dynamic>(),
                ))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePendingOps(
    String eventId,
    List<ChecklistPendingOp> ops,
  ) async {
    final prefs = await _prefs;
    final encoded = jsonEncode(ops.map((e) => e.toJson()).toList());
    await prefs.setString(_pendingKey(eventId), encoded);
  }

  Future<void> enqueueOp(
    String eventId,
    ChecklistPendingOp op,
  ) async {
    final ops = await readPendingOps(eventId);
    final updated = [...ops, op];
    await savePendingOps(eventId, updated);
  }
}
