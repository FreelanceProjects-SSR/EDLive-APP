import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/services/user_account_service.dart';

class FirstLoginPasswordResetPage extends StatefulWidget {
  const FirstLoginPasswordResetPage({super.key});

  @override
  State<FirstLoginPasswordResetPage> createState() =>
      _FirstLoginPasswordResetPageState();
}

class _FirstLoginPasswordResetPageState
    extends State<FirstLoginPasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = UserAccountService();
  final _temporaryPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  bool _obscureTemporary = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _temporaryPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _service.changePassword(
        currentPassword: _temporaryPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('password_reset_required', false);
      final userType = prefs.getString('user_type')?.toLowerCase() ?? '';

      if (!mounted) {
        return;
      }

      if (userType == 'teacher') {
        Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      }

      Navigator.pushReplacementNamed(context, '/select-child');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = error is UserAccountException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You must set a new password before opening your dashboard.',
                      style: TextStyle(color: Color(0xFF667085)),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F3),
                          border: Border.all(color: const Color(0xFFFDA4AF)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _passwordField(
                      controller: _temporaryPasswordController,
                      label: 'Temporary password',
                      obscureText: _obscureTemporary,
                      onToggle: () {
                        setState(() {
                          _obscureTemporary = !_obscureTemporary;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _passwordField(
                      controller: _newPasswordController,
                      label: 'New password',
                      obscureText: _obscureNew,
                      onToggle: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                      validator: (value) {
                        final required = _required(value, 'New password');
                        if (required != null) {
                          return required;
                        }
                        if (value!.trim().length < 6) {
                          return 'Password must be at least 6 characters.';
                        }
                        if (value.trim() ==
                            _temporaryPasswordController.text.trim()) {
                          return 'New password must be different from temporary password.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _passwordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm new password',
                      obscureText: _obscureConfirm,
                      onToggle: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                      validator: (value) {
                        final required = _required(
                          value,
                          'Confirm new password',
                        );
                        if (required != null) {
                          return required;
                        }
                        if (value!.trim() !=
                            _newPasswordController.text.trim()) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Change Password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
        ),
      ),
      validator: validator ?? (value) => _required(value, label),
    );
  }

  String? _required(String? value, String label) {
    if (value?.trim().isEmpty ?? true) {
      return '$label is required.';
    }
    return null;
  }
}
