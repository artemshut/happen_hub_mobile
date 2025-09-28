import 'user.dart';

class Comment {
  final String id;
  final String content;
  final User? user;

  Comment({
    required this.id,
    required this.content,
    this.user,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] ?? json;

    User? u;
    if (json['relationships']?['user']?['data'] != null) {
      // We expect the full user object to be resolved by parser & passed in `included`
      u = User.fromJson(json); 
    }

    return Comment(
      id: json['id']?.toString() ?? '',
      content: attrs['content'] ?? '',
      user: u,
    );
  }
}