import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/permission_service.dart';
import '../../utils/constants.dart';
import 'web_login_screen.dart';

/// Shown when a user is authenticated but has no role assigned.
class NoRoleScreen extends StatelessWidget {
  const NoRoleScreen({super.key});

  static const _primary = Color(AppConstants.primaryColor);
  static const _accent = Color(AppConstants.accentColor);

  Future<void> _signOut(BuildContext context) async {
    PermissionService.clear();
    await SupabaseService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WebLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_person_outlined,
                        size: 40, color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'لا يوجد دور مُعيَّن',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'حسابك لا يملك دوراً في النظام بعد.\nتواصل مع مدير النظام لتعيين دور لك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _signOut(context),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('تسجيل الخروج'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
