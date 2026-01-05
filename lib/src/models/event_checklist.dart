import 'dart:convert';

int _asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value.toString());
  return parsed ?? fallback;
}

class ChecklistProgress {
  final int completed;
  final int total;

  const ChecklistProgress({required this.completed, required this.total});

  double get percent {
    if (total <= 0) return 0;
    return (completed / total).clamp(0, 1);
  }

  Map<String, dynamic> toJson() => {
        "completed": completed,
        "total": total,
      };

  factory ChecklistProgress.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChecklistProgress(completed: 0, total: 0);
    }
    return ChecklistProgress(
      completed: _asInt(json["completed"]),
      total: _asInt(json["total"]),
    );
  }
}

class ChecklistAssignee {
  final String id;
  final String name;
  final String? avatarUrl;

  const ChecklistAssignee({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "avatar_url": avatarUrl,
      };

  factory ChecklistAssignee.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChecklistAssignee(id: "", name: "");
    final fullName = (json["full_name"] ?? json["name"] ?? "").toString();
    return ChecklistAssignee(
      id: json["id"].toString(),
      name: fullName.isEmpty ? "Unassigned" : fullName,
      avatarUrl: json["avatar_url"]?.toString(),
    );
  }
}

class EventChecklistItem {
  final int id;
  final String title;
  final int position;
  final bool completed;
  final DateTime? dueAt;
  final ChecklistAssignee? assignee;

  const EventChecklistItem({
    required this.id,
    required this.title,
    required this.position,
    required this.completed,
    this.dueAt,
    this.assignee,
  });

  EventChecklistItem copyWith({
    int? id,
    String? title,
    int? position,
    bool? completed,
    DateTime? dueAt,
    ChecklistAssignee? assignee,
  }) {
    return EventChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      position: position ?? this.position,
      completed: completed ?? this.completed,
      dueAt: dueAt ?? this.dueAt,
      assignee: assignee ?? this.assignee,
    );
  }

  bool get isLocal => id < 0;

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "position": position,
        "completed": completed,
        "due_at": dueAt?.toIso8601String(),
        "assignee": assignee?.toJson(),
      };

  factory EventChecklistItem.fromJson(
    Map<String, dynamic> json, {
    Map<String, Map<String, Map<String, dynamic>>>? included,
  }) {
    final dueRaw = json["due_at"];
    final dueAt = dueRaw == null ? null : DateTime.tryParse(dueRaw.toString());
    return EventChecklistItem(
      id: _asInt(json["id"], fallback: -DateTime.now().millisecondsSinceEpoch),
      title: (json["title"] ?? "").toString(),
      position: _asInt(json["position"]),
      completed: json["completed"] == true ||
          json["completed"] == 1 ||
          json["completed"]?.toString() == "true",
      dueAt: dueAt,
      assignee: json["assignee"] == null
          ? null
          : ChecklistAssignee.fromJson(
              (json["assignee"] as Map).cast<String, dynamic>(),
            ),
    );
  }
}

class EventChecklist {
  final int id;
  final String title;
  final int position;
  final ChecklistProgress progress;
  final List<EventChecklistItem> items;
  final DateTime? insertedAt;
  final DateTime? updatedAt;

  const EventChecklist({
    required this.id,
    required this.title,
    required this.position,
    required this.progress,
    required this.items,
    this.insertedAt,
    this.updatedAt,
  });

  EventChecklist copyWith({
    int? id,
    String? title,
    int? position,
    ChecklistProgress? progress,
    List<EventChecklistItem>? items,
    DateTime? insertedAt,
    DateTime? updatedAt,
  }) {
    return EventChecklist(
      id: id ?? this.id,
      title: title ?? this.title,
      position: position ?? this.position,
      progress: progress ?? this.progress,
      items: items ?? this.items,
      insertedAt: insertedAt ?? this.insertedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isLocal => id < 0;

  List<EventChecklistItem> get sortedItems {
    final copy = [...items];
    copy.sort((a, b) => a.position.compareTo(b.position));
    return copy;
  }

  double get completionPercent {
    final total = progress.total > 0 ? progress.total : items.length;
    final completed = progress.total > 0 || progress.completed > 0
        ? progress.completed
        : items.where((item) => item.completed).length;
    if (total == 0) return 0;
    return (completed / total).clamp(0, 1);
  }

  int get completedCount =>
      progress.completed > 0 ? progress.completed : items.where((i) => i.completed).length;

  int get totalCount => progress.total > 0 ? progress.total : items.length;

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "position": position,
        "progress": progress.toJson(),
        "items": items.map((e) => e.toJson()).toList(),
        "inserted_at": insertedAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };

  factory EventChecklist.fromJson(
    Map<String, dynamic> json, {
    Map<String, Map<String, Map<String, dynamic>>>? included,
  }) {
    final insertedRaw = json["inserted_at"];
    final updatedRaw = json["updated_at"];
    final items = (json["items"] as List<dynamic>? ?? const [])
        .map(
          (item) => EventChecklistItem.fromJson(
            (item as Map).cast<String, dynamic>(),
            included: included,
          ),
        )
        .toList();
    return EventChecklist(
      id: _asInt(json["id"], fallback: -DateTime.now().millisecondsSinceEpoch),
      title: (json["title"] ?? "").toString(),
      position: _asInt(json["position"]),
      progress: ChecklistProgress.fromJson(
        (json["progress"] as Map?)?.cast<String, dynamic>(),
      ),
      items: items,
      insertedAt: insertedRaw == null ? null : DateTime.tryParse(insertedRaw.toString()),
      updatedAt: updatedRaw == null ? null : DateTime.tryParse(updatedRaw.toString()),
    );
  }

  static List<EventChecklist> decodeList(String source) {
    final data = jsonDecode(source);
    final list = data is List ? data : (data["data"] as List? ?? const []);
    return list
        .map((item) => EventChecklist.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  static String encodeList(List<EventChecklist> lists) {
    return jsonEncode(lists.map((e) => e.toJson()).toList());
  }
}
