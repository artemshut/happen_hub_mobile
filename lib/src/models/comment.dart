import 'user.dart';

class Comment {
  final String id;
  final String content;
  final User? user;
  final DateTime? createdAt;

  Comment({
    required this.id,
    required this.content,
    this.user,
    this.createdAt,
  });

  factory Comment.fromJson(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? included,
  }) {
    final attrs = (json['attributes'] ?? json) as Map<String, dynamic>;

    User? u;
    final userRef = json['relationships']?['user']?['data'];
    if (userRef != null && included != null) {
      final maybe = included[userRef['type']]?[userRef['id']];
      if (maybe != null) {
        u = User.fromJson({'id': maybe['id'], 'attributes': maybe['attributes']});
      }
    } else if (json['user'] != null) {
      u = User.fromJson(json['user']);
    }

    final createdAtStr = attrs['created_at']?.toString();
    return Comment(
      id: json['id']?.toString() ?? '',
      content: (attrs['content'] ?? '').toString(),
      user: u,
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
    );
  }
}
