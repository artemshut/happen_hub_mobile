import '../models/plan.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/json_api_parser.dart';

class PlanRepository {
  final ApiClient _client = ApiClient();
  final AuthService _auth = AuthService();

  /// Fetch available plans. If user is logged in, token is included so the
  /// backend can mark the current plan via `is_current_plan`.
  Future<List<Plan>> fetchPlans() async {
    final token = await _auth.getToken();
    final res = await _client.get("/plans", token: token);

    if (res.statusCode == 200) {
      return JsonApiParser.parsePlans(res.body);
    } else {
      throw Exception("Failed to load plans (${res.statusCode})");
    }
  }
}

