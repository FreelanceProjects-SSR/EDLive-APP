import 'package:flutter/material.dart';

import 'package:school_app/widgets/reset_password_section.dart';
import 'package:school_app/services/user_account_service.dart';

class RequiredPasswordChangePage extends StatelessWidget {
  const RequiredPasswordChangePage({super.key, this.service});

  final UserAccountService? service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change your password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set a new password before opening your school account. '
                'Use your current or temporary password below.',
              ),
              const SizedBox(height: 20),
              ResetPasswordSection(
                initiallyExpanded: true,
                service: service,
                onPasswordChanged: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
