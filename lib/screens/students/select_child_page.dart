import 'package:school_app/widgets/authenticated_profile_image.dart';
import 'package:flutter/material.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/services/parent_children_service.dart';
import 'package:school_app/services/login_profile_service.dart';
import '../login_page.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'student_menu_drawer.dart';
import 'student_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SelectChildPage extends StatefulWidget {
  const SelectChildPage({super.key, this.client});

  final http.Client? client;

  @override
  State<SelectChildPage> createState() => _SelectChildPageState();
}

class _SelectChildPageState extends State<SelectChildPage> {
  List<Map<String, dynamic>> children = [];
  bool isLoading = true;
  bool _selectingProfile = false;
  String? _loadError;
  late final http.Client _client = widget.client ?? http.Client();

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  static const double _profileImageSize = 160;
  static const int _profileImageCacheSize = 320;

  Map<String, dynamic> _buildSelectedChild(Map<String, dynamic> child) {
    final selectedChild = Map<String, dynamic>.from(child);
    final profilePath =
        child['profile_img'] ?? child['profile_image'] ?? child['image'];

    selectedChild['name'] = child['full_name'] ?? child['name'] ?? '';
    selectedChild['image'] =
        profilePath != null && profilePath.toString().trim().isNotEmpty
        ? AppConfig.absoluteUrl(profilePath.toString())
        : '';
    selectedChild['class'] =
        child['class_name'] ?? child['classname'] ?? child['class'] ?? '';
    selectedChild['notification'] = child['notification'] ?? 0;

    return selectedChild;
  }

  Future<void> _openSelectedDashboard(Map<String, dynamic> child) async {
    if (_selectingProfile) return;
    setState(() => _selectingProfile = true);
    try {
      await LoginProfileService(_client).select(child);
      if (!mounted) return;
      final selectedType = (child['user_type'] ?? '').toString().toLowerCase();
      final isTeacher = selectedType == 'staff' || selectedType == 'teacher';
      if (isTeacher) {
        Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentDashboardPage(childData: child),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _selectingProfile = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchChildren();
  }

  Widget _buildProfilePlaceholder() {
    return Container(
      width: _profileImageSize,
      height: _profileImageSize,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 50, color: Colors.white),
    );
  }

  Widget _buildProfileImage(Map<String, dynamic> child) {
    final imageUrl = child['image']?.toString() ?? '';
    if (imageUrl.isEmpty) {
      return _buildProfilePlaceholder();
    }

    return ClipOval(
      child: AuthenticatedProfileImage(
        imageUrl: imageUrl,
        width: _profileImageSize,
        height: _profileImageSize,
        cacheWidth: _profileImageCacheSize,
        cacheHeight: _profileImageCacheSize,
        placeholder: _buildProfilePlaceholder(),
      ),
    );
  }

  Future<void> fetchChildren() async {
    setState(() {
      isLoading = true;
      _loadError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = await ParentChildrenService(
        _client,
      ).fetchProfiles(prefs.getString('auth_token'));
      if (!mounted) return;
      final tempChildren = data.map(_buildSelectedChild).toList();

      // Staff first, then Student
      tempChildren.sort((a, b) {
        final aType = (a['user_type'] ?? '').toString().toLowerCase();
        final bType = (b['user_type'] ?? '').toString().toLowerCase();

        final aIsTeacher = aType == 'staff' || aType == 'teacher';
        final bIsTeacher = bType == 'staff' || bType == 'teacher';
        if (aIsTeacher && !bIsTeacher) return -1;
        if (!aIsTeacher && bIsTeacher) return 1;
        return 0;
      });

      setState(() {
        children = tempChildren;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _loadError = error is ParentChildrenException
            ? error.message
            : 'Unable to load children. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: StudentAppBar(),
      drawer: const StudentMenuDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchChildren,
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (_) => false,
                      ),
                      child: const Text('Back to login'),
                    ),
                  ],
                ),
              ),
            )
          : children.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No teacher or student profiles are linked to this account. '
                      'Please contact the school administrator.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchChildren,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: children.map((child) {
                  final bool isTeacher =
                      (child['user_type'] ?? '').toString().toLowerCase() ==
                          'staff' ||
                      (child['user_type'] ?? '').toString().toLowerCase() ==
                          'teacher';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: GestureDetector(
                      onTap: () => _openSelectedDashboard(child),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    _buildProfileImage(child),
                                    if (child['notification'] > 0)
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.purple,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            child['notification'].toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  child['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E266D),
                                  ),
                                ),
                                if (isTeacher) ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Teacher',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Class: ${child['class']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
