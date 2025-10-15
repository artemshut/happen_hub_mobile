import '../models/comment.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/json_api_parser.dart';

class CommentRepository {
  final ApiClient _client = ApiClient();
  final AuthService _authService = AuthService();

  Future<List<Comment>> fetchComments(String eventId) async {
    final token = await _authService.getToken();
    final res = await _client.get("/events/$eventId/comments", token: token);

    if (res.statusCode == 200) {
      return JsonApiParser.parseComments(res.body);
    }
    throw Exception("Failed to load comments (${res.statusCode})");
  }

  Future<Comment> createComment(String eventId, String content) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception("Please sign in to comment.");

    final res = await _client.post(
      "/events/$eventId/comments",
      {
        "comment": {"content": content},
      },
      token: token,
    );

    if (res.statusCode == 201) {
      final comments = JsonApiParser.parseComments(res.body);
      if (comments.isNotEmpty) return comments.first;
      throw Exception("Unexpected response from server");
    }
    throw Exception("Failed to post comment (${res.statusCode})");
  }

  Future<void> deleteComment(String eventId, String commentId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception("Please sign in to manage comments.");

    final res =
        await _client.delete("/events/$eventId/comments/$commentId", token: token);
    if (res.statusCode != 204) {
      throw Exception("Failed to delete comment (${res.statusCode})");
    }
  }
}
