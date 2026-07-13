// lib/screens/web/salary/report_details_screen.dart

import 'package:flutter/material.dart';
import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/utils/helpers.dart';

class ReportDetailsScreen extends StatelessWidget {
  final GroupSalaryReport groupReport;
  final DateTime selectedMonth;

  const ReportDetailsScreen({
    super.key,
    required this.groupReport,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تفاصيل التقرير',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              Text(
                Helpers.formatMonthYear(selectedMonth),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF546E7A),
                ),
              ),
            ],
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: groupReport.salesmenReports.length,
          itemBuilder: (context, index) {
            final salesmanReport = groupReport.salesmenReports[index];
            return _buildSalesmanSection(salesmanReport);
          },
        ),
      ),
    );
  }

  Widget _buildSalesmanSection(SalesmanSalaryReport report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF135467).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF135467),
                  child: Text(
                    report.username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      Text(
                        'مندوب: ${report.salesman}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF546E7A),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getAchievementColor(report.achievementPercentage)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${report.achievementPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getAchievementColor(report.achievementPercentage),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Statistics
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildStatRow('إجمالي الهدف',
                    Helpers.formatCurrency(report.adjustedTotalTarget)),
                const SizedBox(height: 8),
                _buildStatRow('إجمالي المبيعات',
                    Helpers.formatCurrency(report.adjustedTotalSales)),
                if (report.retailSalesTotal > 0) ...[
                  const SizedBox(height: 8),
                  _buildStatRow('مبيعات التجزئة',
                      Helpers.formatCurrency(report.retailSalesTotal)),
                  const SizedBox(height: 8),
                  _buildStatRow('مبيعات الجملة',
                      Helpers.formatCurrency(report.wholesaleSalesTotal)),
                  const SizedBox(height: 8),
                  _buildStatRow('نسبة التجزئة',
                      '${report.retailPercentage.toStringAsFixed(2)}%'),
                ],
                const SizedBox(height: 8),
                _buildStatRow(
                    'إجمالي الذمم', Helpers.formatCurrency(report.agingTotal)),
                const SizedBox(height: 8),
                _buildStatRow('الذمم +53 يوم',
                    Helpers.formatCurrency(report.aging53Plus)),
                const SizedBox(height: 8),
                _buildStatRow(
                  'نسبة الذمم المتأخرة',
                  '${report.agingPercentage.toStringAsFixed(2)}%',
                  valueColor:
                      report.agingPercentage < 4 ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Brands Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                Colors.grey.shade50,
              ),
              columns: const [
                DataColumn(
                    label: Text('العلامة التجارية',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('الهدف',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('النسبة',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('المبيعات',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('الانحراف',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('نسبة الإنحراف',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('الزبائن',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: report.brandData.map((brand) {
                return DataRow(
                  cells: [
                    DataCell(Text('${brand.brandCode} - ${brand.brandName}')),
                    DataCell(
                        Text(Helpers.formatCurrency(brand.adjustedTarget))),
                    DataCell(
                        Text('${brand.targetPercent.toStringAsFixed(2)}%')),
                    DataCell(Text(Helpers.formatCurrency(brand.adjustedSales))),
                    DataCell(
                      Text(
                        Helpers.formatCurrency(brand.adjustedDeviation),
                        style: TextStyle(
                          color: brand.adjustedDeviation > 0
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${brand.adjustedDeviationPercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: brand.adjustedDeviationPercent > 0
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(Text(brand.customerCount.toString())),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF546E7A),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Color _getAchievementColor(double percentage) {
    if (percentage >= 100) return Colors.green;
    if (percentage >= 80) return Colors.orange;
    return Colors.red;
  }
}
