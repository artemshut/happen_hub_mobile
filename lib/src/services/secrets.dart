import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SecretsService {
  static final _storage = FlutterSecureStorage();

  /// Initialize secrets from .env → secure storage
  static Future<void> init() async {
    await _storage.write(
      key: "GOOGLE_CLIENT_ID",
      value: dotenv.env["GOOGLE_CLIENT_ID"],
    );
    await _storage.write(
      key: "GOOGLE_API_KEY",
      value: dotenv.env["GOOGLE_API_KEY"],
    );
  }

  /// Retrieve secrets
  static Future<String?> getGoogleClientId() =>
      _storage.read(key: "GOOGLE_CLIENT_ID");

  static Future<String?> getGoogleApiKey() =>
      _storage.read(key: "GOOGLE_API_KEY");
}