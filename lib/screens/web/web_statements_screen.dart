// lib/screens/web/web_statements_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/screens/web/web_welcome_screen.dart';
import '../../models/user.dart';
import 'account_statements/web_contact_selection_screen.dart';

class WebStatementsScreen extends StatelessWidget {
  final AppUser user;

  const WebStatementsScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    // Redirect to the new contact selection screen
    return WebWelcomeScreen();
  }
}
