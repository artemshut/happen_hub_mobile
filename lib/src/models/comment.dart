import 'user.dart';

class Comment {
  final String id;
  final String content;
  final User? user;
  final DateTime? createdAt;
  final String? userId;

  Comment({
    required this.id,
    required this.content,
    this.user,
    this.createdAt,
    this.userId,
  });

  factory Comment.fromJson(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? included,
  }) {
    final attrs = (json['attributes'] ?? json) as Map<String, dynamic>;

    User? u;
    String? userId;
    final userRef = json['relationships']?['user']?['data'];
    if (userRef != null && included != null) {
      userId = userRef['id']?.toString();
      final maybe = included[userRef['type']]?[userRef['id']];
      if (maybe != null) {
        u = User.fromJson({'id': maybe['id'], 'attributes': maybe['attributes']});
      }
    } else if (json['user'] != null) {
      final userJson = json['user'] as Map<String, dynamic>;
      userId = (userJson['id'] ?? userJson['attributes']?['id'])?.toString();
      u = User.fromJson(userJson);
    } else if (attrs['user'] != null) {
      final map = (attrs['user'] as Map).cast<String, dynamic>();
      userId = (map['id'] ?? map['attributes']?['id'])?.toString();
      u = User.fromJson(map);
    }
    userId ??= attrs['user_id']?.toString();

    final createdAtStr = attrs['created_at']?.toString();
    return Comment(
      id: json['id']?.toString() ?? '',
      content: (attrs['content'] ?? '').toString(),
      user: u,
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
      userId: userId,
    );
  }
}
