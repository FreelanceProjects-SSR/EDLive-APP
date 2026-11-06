import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:school_app/config/config.dart';
import 'package:school_app/utils/class_sorter.dart';
import '../models/class_section.dart';

class ClassService {
  String get baseUrl => AppConfig.serverOrigin;

  Future<List<ClassSection>> fetchClassSections() async {
    final url = Uri.parse('$baseUrl/api/master/classes');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ClassSection.fromJson(json)).toList()..sort(
        (a, b) => compareClassAndSection(
          classA: a.className,
          sectionA: a.section,
          classB: b.className,
          sectionB: b.section,
        ),
      );
    } else {
      throw Exception('Failed to load class sections');
    }
  }
}
