import '../models/event_category.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/json_api_parser.dart';

class EventCategoryRepository {
  final ApiClient _client = ApiClient();
  final AuthService _auth = AuthService();

  Future<List<EventCategory>> fetchCategories() async {
    final token = await _auth.getToken();
    final res = await _client.get("/event_categories", token: token);

    if (res.statusCode == 200) {
      return JsonApiParser.parseEventCategories(res.body);
    } else if (res.statusCode == 401) {
      throw Exception("Unauthorized. Please log in again.");
    } else {
      throw Exception("Failed to load event categories (${res.statusCode})");
    }
  }
}
