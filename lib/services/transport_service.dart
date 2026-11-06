import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/transport_model.dart';
import '../config/config.dart'; // ✅ IMPORTANT
import '../utils/teacher_id_resolver.dart';

class TransportService {
  Future<Transport?> getTransportDetails(int staffId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final resolvedStaffId = staffId > 0
        ? staffId
        : TeacherIdResolver.resolveFromPrefs(prefs);

    if (resolvedStaffId == null) {
      throw Exception('Teacher ID not found');
    }

    final academicYear = AppConfig.academicYear; // ✅ GLOBAL

    print("StaffId: $resolvedStaffId");
    print("AcademicYear: $academicYear");

    final url = Uri.parse(
      '${AppConfig.baseUrl}/transport/staff/$resolvedStaffId/$academicYear',
    );

    print("API URL: $url");

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    print("Status Code: ${response.statusCode}");
    print("Response: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is! Map) {
        throw Exception('Invalid transport response');
      }

      final data = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : Map<String, dynamic>.from(decoded);
      return Transport.fromJson(data);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load transport details');
    }
  }
}
