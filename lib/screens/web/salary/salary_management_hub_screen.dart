// lib/screens/web/salary/salary_management_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:jala_as/screens/web/salary/brands_management_screen.dart';
import 'package:jala_as/screens/web/salary/set_targets_screen.dart';
import 'package:jala_as/screens/web/salary/review_report_screen.dart';
import 'package:jala_as/screens/web/salary/calculate_salary_screen.dart';
import 'package:jala_as/utils/constants.dart';
import 'dart:ui' as ui;

class SalaryManagementHubScreen extends StatelessWidget {
  const SalaryManagementHubScreen({super.key});

  static const _primaryColor = Color(AppConstants.primaryColor);
  static const _accentColor = Color(AppConstants.accentColor);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isDesktop = screenWidth >= 1024;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'إدارة رواتب المندوبين والأهداف',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 800 : 600,
              ),
              child: Column(
                children: [
                  // Header
                  _buildHeader(isMobile),
                  SizedBox(height: isMobile ? 24 : 32),

                  // Cards
                  if (isDesktop)
                    _buildDesktopLayout(context, isMobile)
                  else
                    _buildMobileLayout(context, isMobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: isMobile ? 60 : 70,
            height: isMobile ? 60 : 70,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.payments_outlined,
              size: isMobile ? 30 : 36,
              color: _accentColor,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Text(
            'نظام إدارة الرواتب والأهداف',
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'إدارة شاملة للعلامات التجارية والأهداف وحساب الرواتب',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.8,
      children: _buildCards(context, isMobile),
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isMobile) {
    return Column(
      children: _buildCards(context, isMobile)
          .map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card,
              ))
          .toList(),
    );
  }

  List<Widget> _buildCards(BuildContext context, bool isMobile) {
    return [
      _SalaryFeatureCard(
        title: 'إدارة العلامات التجارية',
        subtitle: 'مزامنة وإدارة العلامات التجارية من النظام',
        icon: Icons.category_outlined,
        color: const Color(0xFF3B82F6),
        onTap: () => _navigateTo(context, const BrandsManagementScreen()),
        isMobile: isMobile,
      ),
      _SalaryFeatureCard(
        title: 'إعداد الأهداف',
        subtitle: 'تحديد أهداف المبيعات الشهرية للمندوبين',
        icon: Icons.assignment_outlined,
        color: const Color(0xFF10B981),
        onTap: () => _navigateTo(context, const SetTargetsScreen()),
        isMobile: isMobile,
      ),
      _SalaryFeatureCard(
        title: 'مراجعة التقرير',
        subtitle: 'عرض تقرير الأهداف والمبيعات الفعلية',
        icon: Icons.analytics_outlined,
        color: const Color(0xFF8B5CF6),
        onTap: () => _navigateTo(context, const ReviewReportScreen()),
        isMobile: isMobile,
      ),
      _SalaryFeatureCard(
        title: 'حساب الرواتب',
        subtitle: 'حساب رواتب المندوبين بناءً على الأداء',
        icon: Icons.calculate_outlined,
        color: const Color(0xFFF59E0B),
        onTap: () => _navigateTo(context, const CalculateSalaryScreen()),
        isMobile: isMobile,
      ),
    ];
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}

class _SalaryFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isMobile;

  const _SalaryFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 48 : 56,
                  height: isMobile ? 48 : 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: isMobile ? 24 : 28,
                    color: color,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(AppConstants.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
