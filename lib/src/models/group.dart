import 'user.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final String? creatorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<User> members;

  Group({
    required this.id,
    required this.name,
    this.description,
    this.creatorId,
    this.createdAt,
    this.updatedAt,
    this.members = const [],
  });

  factory Group.fromJson(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? included,
  }) {
    final attrs = (json['attributes'] ?? const {}) as Map<String, dynamic>;
    final relationships =
        (json['relationships'] ?? const {}) as Map<String, dynamic>;

    final members = <User>[];
    final membersData =
        (relationships['members']?['data'] as List<dynamic>?) ?? const [];
    if (included != null) {
      for (final rel in membersData) {
        final type = rel['type']?.toString();
        final id = rel['id']?.toString();
        if (type == null || id == null) continue;
        final inc = included[type]?[id];
        if (inc != null) {
          members.add(
            User.fromJson({
              'id': inc['id'],
              'attributes': inc['attributes'],
            }),
          );
        }
      }
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return Group(
      id: json['id'].toString(),
      name: (attrs['name'] ?? '').toString(),
      description: attrs['description']?.toString(),
      creatorId: attrs['creator_id']?.toString(),
      createdAt: parseDate(attrs['created_at']),
      updatedAt: parseDate(attrs['updated_at']),
      members: members,
    );
  }

  int get memberCount => members.length;
}
