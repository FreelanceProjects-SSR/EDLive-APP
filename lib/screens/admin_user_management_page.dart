import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:school_app/services/admin_user_management_service.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() =>
      _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage>
    with SingleTickerProviderStateMixin {
  final _service = AdminUserManagementService();
  late final TabController _tabController;

  UserManagementTab _selectedTab = UserManagementTab.admin;
  bool _isLoading = true;
  String? _loadError;
  List<AdminManagedUser> _users = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: UserManagementTab.values.length,
      vsync: this,
    )..addListener(_handleTabChange);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    final tab = UserManagementTab.values[_tabController.index];
    if (tab == _selectedTab) {
      return;
    }
    setState(() {
      _selectedTab = tab;
    });
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final users = await _service.fetchUsers(_selectedTab);
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = _messageFromError(error);
        _users = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddUserDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _AddManagedUserDialog(tab: _selectedTab, service: _service),
    );

    if (created == true) {
      await _loadUsers();
    }
  }

  Future<void> _showResendWelcomeDialog(AdminManagedUser user) async {
    bool isSending = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Resend Welcome Email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will reset the temporary password and send new login credentials to ${user.email}.',
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: errorMessage!),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSending
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSending
                    ? null
                    : () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() {
                          isSending = true;
                          errorMessage = null;
                        });

                        try {
                          final message = await _service.resendWelcomeEmail(
                            user,
                          );
                          if (!mounted) {
                            return;
                          }
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        } catch (error) {
                          setDialogState(() {
                            isSending = false;
                            errorMessage = _messageFromError(error);
                          });
                        }
                      },
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _bulkUploadStudents() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls'],
      );
      final file = result?.files.single;
      if (file == null) {
        return;
      }

      final message = await _service.bulkUploadStudents(file);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _loadUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Bulk Upload Students'),
          content: _ErrorBanner(message: _messageFromError(error)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String _messageFromError(Object error) {
    if (error is AdminUserManagementException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF101828),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D47A1),
          unselectedLabelColor: const Color(0xFF667085),
          indicatorColor: const Color(0xFF29ABE2),
          tabs: UserManagementTab.values
              .map((tab) => Tab(text: tab.label))
              .toList(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedTab.label,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828),
                    ),
                  ),
                ),
                if (_selectedTab == UserManagementTab.student) ...[
                  OutlinedButton.icon(
                    onPressed: _bulkUploadStudents,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Bulk Upload Students'),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton.icon(
                  onPressed: _showAddUserDialog,
                  icon: const Icon(Icons.add),
                  label: Text(_selectedTab.addButtonLabel),
                ),
              ],
            ),
            if (_selectedTab == UserManagementTab.student) ...[
              const SizedBox(height: 10),
              const Text(
                'Bulk upload supports First Name, Last Name, Student ID, Class, optional Division, Parent/Guardian Name, Parent/Guardian Phone, and optional Email.',
                style: TextStyle(color: Color(0xFF667085)),
              ),
            ],
            const SizedBox(height: 18),
            Expanded(child: _buildTableArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildTableArea() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _ErrorBanner(message: _loadError!),
        ),
      );
    }
    if (_users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: _columnsFor(_selectedTab),
            rows: _users.map((user) => _rowFor(user, _selectedTab)).toList(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _columnsFor(UserManagementTab tab) {
    switch (tab) {
      case UserManagementTab.admin:
        return const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Status')),
        ];
      case UserManagementTab.staff:
        return const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Login')),
          DataColumn(label: Text('Actions')),
        ];
      case UserManagementTab.student:
        return const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Student ID')),
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('Division')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Login')),
          DataColumn(label: Text('Actions')),
        ];
    }
  }

  DataRow _rowFor(AdminManagedUser user, UserManagementTab tab) {
    switch (tab) {
      case UserManagementTab.admin:
        return DataRow(
          cells: [
            DataCell(Text(user.fullName)),
            DataCell(Text(user.role.isEmpty ? 'Admin' : user.role)),
            DataCell(Text(user.email.isEmpty ? '-' : user.email)),
            DataCell(Text(user.status.isEmpty ? '-' : user.status)),
          ],
        );
      case UserManagementTab.staff:
        return DataRow(
          cells: [
            DataCell(Text(user.fullName)),
            DataCell(Text(user.role.isEmpty ? '-' : user.role)),
            DataCell(Text(user.email.isEmpty ? '-' : user.email)),
            DataCell(_LoginStatusChip(enabled: user.loginEnabled)),
            DataCell(_resendButton(user)),
          ],
        );
      case UserManagementTab.student:
        return DataRow(
          cells: [
            DataCell(Text(user.fullName)),
            DataCell(Text(user.studentId.isEmpty ? '-' : user.studentId)),
            DataCell(Text(user.className.isEmpty ? '-' : user.className)),
            DataCell(_DivisionText(value: user.division)),
            DataCell(Text(user.email.isEmpty ? '-' : user.email)),
            DataCell(_LoginStatusChip(enabled: user.loginEnabled)),
            DataCell(_resendButton(user)),
          ],
        );
    }
  }

  Widget _resendButton(AdminManagedUser user) {
    final canResend = user.loginEnabled && user.email.trim().isNotEmpty;
    return TextButton.icon(
      onPressed: canResend ? () => _showResendWelcomeDialog(user) : null,
      icon: const Icon(Icons.mail_outline, size: 18),
      label: const Text('Resend Welcome Email'),
    );
  }
}

class _AddManagedUserDialog extends StatefulWidget {
  final UserManagementTab tab;
  final AdminUserManagementService service;

  const _AddManagedUserDialog({required this.tab, required this.service});

  @override
  State<_AddManagedUserDialog> createState() => _AddManagedUserDialogState();
}

class _AddManagedUserDialogState extends State<_AddManagedUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _classController = TextEditingController();
  final _divisionController = TextEditingController(text: 'Unassigned');
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();

  String? _role;
  bool _studentLoginEnabled = false;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  static const List<String> _adminRoles = ['Admin'];
  static const List<String> _staffRoles = [
    'Teacher',
    'Accountant',
    'Librarian',
    'Receptionist',
    'Nurse',
    'Transport Coordinator',
    'Office Staff',
  ];

  @override
  void initState() {
    super.initState();
    _role = widget.tab == UserManagementTab.staff
        ? _staffRoles.first
        : widget.tab == UserManagementTab.admin
        ? _adminRoles.first
        : 'Student';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _classController.dispose();
    _divisionController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  bool get _isTeacher =>
      widget.tab == UserManagementTab.staff && _role == 'Teacher';

  bool get _emailRequired =>
      _isTeacher ||
      (widget.tab == UserManagementTab.student && _studentLoginEnabled);

  Future<void> _save() async {
    setState(() {
      _errorMessage = null;
      _fieldErrors = const {};
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final normalizedEmail = AdminUserManagementService.normalizeEmail(
      _emailController.text,
    );
    final formData = <String, dynamic>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': normalizedEmail,
      'role': _role,
      if (widget.tab == UserManagementTab.student) ...{
        'student_id': _studentIdController.text.trim(),
        'class': _classController.text.trim(),
        'division': _divisionController.text.trim().isEmpty
            ? 'Unassigned'
            : _divisionController.text.trim(),
        'parent_guardian_name': _guardianNameController.text.trim(),
        'parent_guardian_phone': _guardianPhoneController.text.trim(),
        'login_enabled': _studentLoginEnabled && normalizedEmail.isNotEmpty,
        'profile_status': normalizedEmail.isEmpty && !_studentLoginEnabled
            ? 'Profile Incomplete'
            : 'Active',
      },
    };

    try {
      final message = await widget.service.createUser(
        tab: widget.tab,
        formData: formData,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = error is AdminUserManagementException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '').trim();
        _fieldErrors = error is AdminUserManagementException
            ? error.fieldErrors
            : const {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tab.addButtonLabel),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  _ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 12),
                ],
                _textField(
                  controller: _firstNameController,
                  label: 'First Name',
                  fieldKey: 'first_name',
                  required: true,
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  fieldKey: 'last_name',
                  required: true,
                ),
                const SizedBox(height: 12),
                if (widget.tab != UserManagementTab.student)
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        (widget.tab == UserManagementTab.admin
                                ? _adminRoles
                                : _staffRoles)
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              ),
                            )
                            .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _role = value;
                            });
                          },
                  ),
                if (widget.tab != UserManagementTab.student)
                  const SizedBox(height: 12),
                _emailField(),
                if (widget.tab == UserManagementTab.staff && !_isTeacher) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Only Teacher staff accounts are login-enabled. This staff record will be saved for management only.',
                    style: TextStyle(color: Color(0xFF667085), fontSize: 12),
                  ),
                ],
                if (widget.tab == UserManagementTab.student) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _studentLoginEnabled,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _studentLoginEnabled = value ?? false;
                            });
                          },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable app login'),
                    subtitle: const Text(
                      'Requires email. Email will be used as the username.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _studentIdController,
                    label: 'Student ID',
                    fieldKey: 'student_id',
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _classController,
                    label: 'Class',
                    fieldKey: 'class',
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _divisionController,
                    label: 'Division',
                    fieldKey: 'division',
                    required: false,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _guardianNameController,
                    label: 'Parent/Guardian Name',
                    fieldKey: 'parent_guardian_name',
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _guardianPhoneController,
                    label: 'Parent/Guardian Phone',
                    fieldKey: 'parent_guardian_phone',
                    required: true,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.tab.addButtonLabel),
        ),
      ],
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      enabled: !_isSaving,
      decoration: InputDecoration(
        labelText: _emailRequired ? 'Email' : 'Email (optional)',
        helperText: _emailRequired || _emailController.text.trim().isNotEmpty
            ? 'This email will be used as the login username.'
            : null,
        border: const OutlineInputBorder(),
        errorText: _fieldErrors['email'],
      ),
      onChanged: (value) {
        final normalized = AdminUserManagementService.normalizeEmail(value);
        if (value != normalized) {
          _emailController.value = TextEditingValue(
            text: normalized,
            selection: TextSelection.collapsed(offset: normalized.length),
          );
        }
      },
      validator: (value) => AdminUserManagementService.validateEmail(
        value ?? '',
        required: _emailRequired,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    required bool required,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSaving,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: _fieldErrors[fieldKey],
      ),
      validator: (value) {
        if (required && (value?.trim().isEmpty ?? true)) {
          return '$label is required.';
        }
        return null;
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        border: Border.all(color: const Color(0xFFFDA4AF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFB42318))),
    );
  }
}

class _LoginStatusChip extends StatelessWidget {
  final bool enabled;

  const _LoginStatusChip({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(enabled ? 'Login Enabled' : 'Login Not Enabled'),
      backgroundColor: enabled
          ? const Color(0xFFE7F8EE)
          : const Color(0xFFF2F4F7),
      labelStyle: TextStyle(
        color: enabled ? const Color(0xFF067647) : const Color(0xFF475467),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DivisionText extends StatelessWidget {
  final String value;

  const _DivisionText({required this.value});

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? 'Unassigned' : value.trim();
    final isUnassigned = display.toLowerCase() == 'unassigned';
    return Text(
      display,
      style: TextStyle(
        color: isUnassigned ? const Color(0xFFB42318) : null,
        fontWeight: isUnassigned ? FontWeight.w700 : FontWeight.normal,
      ),
    );
  }
}
