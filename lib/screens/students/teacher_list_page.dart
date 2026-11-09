import 'package:flutter/material.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'student_menu_drawer.dart';
import '/models/teacher_model.dart';
import '/services/teacher_service.dart';
import 'teacher_contact_page.dart';

class StudentTeacherPage extends StatefulWidget {
  final String studentId; // Pass student ID here

  const StudentTeacherPage({super.key, required this.studentId});

  @override
  State<StudentTeacherPage> createState() => _StudentTeacherPageState();
}

class _StudentTeacherPageState extends State<StudentTeacherPage> {
  late Future<List<Teacher>> _teachersFuture;

  @override
  void initState() {
    super.initState();
    _teachersFuture = TeacherService().fetchTeachers(widget.studentId);
  }

  void _retry() {
    setState(() {
      _teachersFuture = TeacherService().fetchTeachers(widget.studentId);
    });
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD596),
      appBar: StudentAppBar(),
      drawer: const StudentMenuDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Row(
                children: [
                  SizedBox(width: 5),
                  Text("< Back", style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E3192),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(Icons.group, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Teachers",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3192),
                  ),
                ),
              ],
            ),
          ),
          // Teachers list container
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 35),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Tap to get contact details",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<List<Teacher>>(
                      future: _teachersFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (snapshot.hasError) {
                          return _buildMessage(
                            snapshot.error is TeacherListException
                                ? (snapshot.error as TeacherListException)
                                      .message
                                : 'Unable to load teachers. Please try again.',
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return _buildMessage(
                            'No teachers are available for this student yet. '
                            'Please contact the school to check the class timetable and teacher assignments.',
                          );
                        }

                        final teachers = snapshot.data!;
                        return ListView.builder(
                          itemCount: teachers.length,
                          itemBuilder: (context, index) {
                            final teacher = teachers[index];
                            return TeacherTile(teacher: teacher);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherTile extends StatelessWidget {
  final Teacher teacher;

  // Non-const constructor because teacher is dynamic
  TeacherTile({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      ),
      title: Text(
        teacher.fullName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(teacher.subjectName),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherContactPage(
              name: teacher.fullName,
              subject: teacher.subjectName,
              phone: '', // Add if API provides later
              email: '', // Add if API provides later
            ),
          ),
        );
      },
    );
  }
}
