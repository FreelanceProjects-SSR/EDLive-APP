import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:school_app/config/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileImageService {
  const ProfileImageService({this.client});

  final http.Client? client;

  Future<Uint8List> load(String imageUrl) async {
    final uri = Uri.parse(AppConfig.absoluteUrl(imageUrl));
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const FormatException('Unsupported profile image URL');
    }
    final headers = <String, String>{};
    // Only send the session token to the configured backend, never to external
    // image hosts (including public or signed storage URLs).
    if (uri.origin == Uri.parse(AppConfig.serverOrigin).origin ||
        uri.origin == Uri.parse(AppConfig.baseUrl).origin) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token')?.trim() ?? '';
      if (token.isEmpty) throw StateError('No authenticated image session');
      headers['Authorization'] = 'Bearer $token';
    }
    final response =
        await (client == null
                ? http.get(uri, headers: headers)
                : client!.get(uri, headers: headers))
            .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Profile image failed (${response.statusCode})',
      );
    }
    return response.bodyBytes;
  }
}
