import 'dart:convert';

import '../models/event_checklist.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class ChecklistApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  ChecklistApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors,
  });

  @override
  String toString() => message;
}

class ChecklistRepository {
  final ApiClient _client = ApiClient();
  final AuthService _authService = AuthService();
  static const _includeParam = "include=items,items.assignee";
  static const _itemIncludeParam = "include=assignee";

  Future<String> _token() async {
    final token = await _authService.getToken();
    if (token == null) {
      throw ChecklistApiException("Not authenticated");
    }
    return token;
  }

  List<EventChecklist> _parseChecklistList(String body) {
    final decoded = jsonDecode(body);
    final data = decoded is List ? decoded : (decoded['data'] ?? decoded);
    final includedIndex = _indexIncluded(decoded is Map ? decoded['included'] : null);
    final list = data is List ? data : const [];
    return list
        .map(
          (entry) => EventChecklist.fromJson(
            _inflateChecklist(
              (entry as Map).cast<String, dynamic>(),
              includedIndex,
            ),
          ),
        )
        .toList();
  }

  EventChecklist _parseChecklist(String body) {
    final decoded = jsonDecode(body);
    final data = decoded is Map<String, dynamic>
        ? (decoded['data'] ?? decoded)
        : decoded;
    final includedIndex =
        _indexIncluded(decoded is Map ? decoded['included'] : null);
    return EventChecklist.fromJson(
      _inflateChecklist(
        (data as Map).cast<String, dynamic>(),
        includedIndex,
      ),
    );
  }

  EventChecklistItem _parseItem(String body) {
    final decoded = jsonDecode(body);
    final data = decoded is Map<String, dynamic>
        ? (decoded['data'] ?? decoded)
        : decoded;
    final includedIndex =
        _indexIncluded(decoded is Map ? decoded['included'] : null);
    return EventChecklistItem.fromJson(
      _inflateChecklistItem(
        (data as Map).cast<String, dynamic>(),
        includedIndex,
      ),
    );
  }

  List<EventChecklistItem> _parseItemList(String body) {
    final decoded = jsonDecode(body);
    final data = decoded is List ? decoded : (decoded['data'] ?? decoded);
    final includedIndex = _indexIncluded(decoded is Map ? decoded['included'] : null);
    final list = data is List ? data : const [];
    return list
        .map(
          (entry) => EventChecklistItem.fromJson(
            _inflateChecklistItem(
              (entry as Map).cast<String, dynamic>(),
              includedIndex,
            ),
          ),
        )
        .toList();
  }

  Map<String, Map<String, Map<String, dynamic>>> _indexIncluded(
    dynamic included,
  ) {
    final result = <String, Map<String, Map<String, dynamic>>>{};
    if (included is! List) return result;
    for (final entry in included) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final type = map['type']?.toString();
      final id = map['id']?.toString();
      if (type == null || id == null) continue;
      result.putIfAbsent(type, () => {});
      result[type]![id] = map;
    }
    return result;
  }

  Map<String, dynamic> _resourceAttributes(Map<String, dynamic> resource) {
    final attrsRaw = resource['attributes'];
    if (attrsRaw is! Map) {
      return Map<String, dynamic>.from(resource);
    }
    final attrs = attrsRaw.cast<String, dynamic>();
    return {
      ...attrs,
      'id': resource['id'],
    };
  }

  Map<String, dynamic> _inflateChecklist(
    Map<String, dynamic> resource,
    Map<String, Map<String, Map<String, dynamic>>> includedIndex,
  ) {
    final data = _resourceAttributes(resource);
    final relItems =
        (resource['relationships']?['items']?['data'] as List?) ?? const [];
    final items = <Map<String, dynamic>>[];
    for (final ref in relItems) {
      if (ref is! Map) continue;
      final type = ref['type']?.toString();
      final id = ref['id']?.toString();
      if (type == null || id == null) continue;
      final included = includedIndex[type]?[id];
      if (included == null) continue;
      items.add(
        _inflateChecklistItem(
          included.cast<String, dynamic>(),
          includedIndex,
        ),
      );
    }
    data['items'] = items;
    return data;
  }

  Map<String, dynamic> _inflateChecklistItem(
    Map<String, dynamic> resource,
    Map<String, Map<String, Map<String, dynamic>>> includedIndex,
  ) {
    final data = _resourceAttributes(resource);
    final assigneeRef = resource['relationships']?['assignee']?['data'];
    if (assigneeRef is Map) {
      final type = assigneeRef['type']?.toString();
      final id = assigneeRef['id']?.toString();
      final included = type == null || id == null
          ? null
          : includedIndex[type]?[id];
      if (included != null) {
        final attrs = _resourceAttributes(included.cast<String, dynamic>());
        data['assignee'] = {
          'id': attrs['id']?.toString(),
          'name': (attrs['full_name'] ??
                  attrs['name'] ??
                  attrs['username'] ??
                  '')
              .toString(),
          'avatar_url': attrs['avatar_url'],
        };
      }
    } else if (data.containsKey('assignee_id') ||
        data.containsKey('assignee_name')) {
      data['assignee'] = {
        'id': data['assignee_id']?.toString(),
        'name': (data['assignee_name'] ?? '').toString(),
        'avatar_url': data['assignee_avatar_url'],
      };
    }
    return data;
  }

  Map<String, List<String>>? _parseErrors(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'] ?? decoded['error'];
        if (errors is Map) {
          final result = <String, List<String>>{};
          errors.forEach((key, value) {
            if (value is List) {
              result[key.toString()] = value.map((e) => e.toString()).toList();
            } else if (value != null) {
              result[key.toString()] = [value.toString()];
            }
          });
          return result.isEmpty ? null : result;
        } else if (errors is List) {
          return {
            'base': errors.map((e) => e.toString()).toList(),
          };
        } else if (errors is String) {
          return {
            'base': [errors],
          };
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  ChecklistApiException _errorFromResponse(
    String action,
    int status,
    String body,
  ) {
    final errors = _parseErrors(body);
    final message =
        errors?['base']?.join(", ") ?? "Failed to $action ($status)";
    return ChecklistApiException(
      message,
      statusCode: status,
      fieldErrors: errors,
    );
  }

  Future<List<EventChecklist>> fetchChecklists(String eventId) async {
    final token = await _token();
    final res = await _client.get(
      _withInclude("/events/$eventId/checklists"),
      token: token,
    );
    if (res.statusCode == 200) {
      final parsed = _parseChecklistList(res.body);
      final hydrated = await Future.wait(
        parsed.map(
          (checklist) async {
            if (checklist.items.isNotEmpty) return checklist;
            try {
              return await _fetchChecklistItems(
                eventId: eventId,
                checklist: checklist,
                token: token,
              );
            } catch (_) {
              return checklist;
            }
          },
        ),
      );
      return hydrated;
    }
    throw _errorFromResponse("load checklists", res.statusCode, res.body);
  }

  Future<EventChecklist> _fetchChecklistItems({
    required String eventId,
    required EventChecklist checklist,
    required String token,
  }) async {
    final res = await _client.get(
      _withItemInclude(
        "/events/$eventId/checklists/${checklist.id}/items",
      ),
      token: token,
    );
    if (res.statusCode == 200) {
      final items = _parseItemList(res.body);
      final updatedProgress = _progressFromItems(checklist, items);
      return checklist.copyWith(
        items: items,
        progress: updatedProgress,
      );
    }
    throw _errorFromResponse(
      "load checklist items",
      res.statusCode,
      res.body,
    );
  }

  Future<EventChecklist> createChecklist({
    required String eventId,
    required String title,
  }) async {
    final token = await _token();
    final res = await _client.post(
      _withInclude("/events/$eventId/checklists"),
      {
        "event_checklist": {"title": title.trim()},
      },
      token: token,
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      final checklist = _parseChecklist(res.body);
      return checklist;
    }
    throw _errorFromResponse("create checklist", res.statusCode, res.body);
  }

  Future<EventChecklist> updateChecklist({
    required String eventId,
    required int checklistId,
    required String title,
  }) async {
    final token = await _token();
    final res = await _client.patch(
      _withInclude("/events/$eventId/checklists/$checklistId"),
      {
        "event_checklist": {"title": title.trim()},
      },
      token: token,
    );
    if (res.statusCode == 200) {
      final checklist = _parseChecklist(res.body);
      return checklist;
    }
    throw _errorFromResponse("update checklist", res.statusCode, res.body);
  }

  Future<void> reorderChecklist({
    required String eventId,
    required int checklistId,
    required int position,
  }) async {
    final token = await _token();
    final res = await _client.patch(
      "/events/$eventId/checklists/$checklistId/reorder",
      {"position": position},
      token: token,
    );
    if (res.statusCode != 200) {
      throw _errorFromResponse("reorder checklist", res.statusCode, res.body);
    }
  }

  Future<void> deleteChecklist({
    required String eventId,
    required int checklistId,
  }) async {
    final token = await _token();
    final res = await _client.delete(
      "/events/$eventId/checklists/$checklistId",
      token: token,
    );
    if (res.statusCode != 204) {
      throw _errorFromResponse("delete checklist", res.statusCode, res.body);
    }
  }

  Future<EventChecklistItem> createItem({
    required String eventId,
    required int checklistId,
    required String title,
    DateTime? dueAt,
    String? assigneeId,
  }) async {
    final token = await _token();
    final payload = <String, dynamic>{
      "title": title.trim(),
    };
    if (dueAt != null) payload["due_at"] = dueAt.toIso8601String();
    if (assigneeId != null && assigneeId.isNotEmpty) {
      payload["assignee_id"] = assigneeId;
    }

    final res = await _client.post(
      _withItemInclude("/events/$eventId/checklists/$checklistId/items"),
      {"event_checklist_item": payload},
      token: token,
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return _parseItem(res.body);
    }
    throw _errorFromResponse("create item", res.statusCode, res.body);
  }

  Future<EventChecklistItem> updateItem({
    required String eventId,
    required int checklistId,
    required int itemId,
    String? title,
    DateTime? dueAt,
    bool clearDueAt = false,
    String? assigneeId,
    bool clearAssignee = false,
  }) async {
    final token = await _token();
    final payload = <String, dynamic>{};
    if (title != null) payload["title"] = title.trim();
    if (dueAt != null) {
      payload["due_at"] = dueAt.toIso8601String();
    } else if (clearDueAt) {
      payload["due_at"] = null;
    }
    if (assigneeId != null) {
      payload["assignee_id"] = assigneeId.isEmpty ? null : assigneeId;
    } else if (clearAssignee) {
      payload["assignee_id"] = null;
    }

    final res = await _client.patch(
      _withItemInclude(
        "/events/$eventId/checklists/$checklistId/items/$itemId",
      ),
      {"event_checklist_item": payload},
      token: token,
    );
    if (res.statusCode == 200) {
      return _parseItem(res.body);
    }
    throw _errorFromResponse("update item", res.statusCode, res.body);
  }

  Future<void> reorderItem({
    required String eventId,
    required int checklistId,
    required int itemId,
    required int position,
  }) async {
    final token = await _token();
    final res = await _client.patch(
      "/events/$eventId/checklists/$checklistId/items/$itemId/reorder",
      {"position": position},
      token: token,
    );
    if (res.statusCode != 200) {
      throw _errorFromResponse("reorder item", res.statusCode, res.body);
    }
  }

  Future<EventChecklistItem> toggleItem({
    required String eventId,
    required int checklistId,
    required int itemId,
  }) async {
    final token = await _token();
    final res = await _client.patch(
      _withItemInclude(
        "/events/$eventId/checklists/$checklistId/items/$itemId/toggle_complete",
      ),
      {},
      token: token,
    );
    if (res.statusCode == 200) {
      return _parseItem(res.body);
    }
    throw _errorFromResponse("toggle item", res.statusCode, res.body);
  }

  Future<void> deleteItem({
    required String eventId,
    required int checklistId,
    required int itemId,
  }) async {
    final token = await _token();
    final res = await _client.delete(
      "/events/$eventId/checklists/$checklistId/items/$itemId",
      token: token,
    );
    if (res.statusCode != 204) {
      throw _errorFromResponse("delete item", res.statusCode, res.body);
    }
  }

  String _withInclude(String path) {
    if (path.contains('?')) {
      return "$path&$_includeParam";
    }
    return "$path?$_includeParam";
  }

  String _withItemInclude(String path) {
    if (path.contains('?')) {
      return "$path&$_itemIncludeParam";
    }
    return "$path?$_itemIncludeParam";
  }

  ChecklistProgress _progressFromItems(
    EventChecklist checklist,
    List<EventChecklistItem> items,
  ) {
    if (items.isEmpty) return checklist.progress;
    final completed = items.where((item) => item.completed).length;
    return ChecklistProgress(completed: completed, total: items.length);
  }
}
