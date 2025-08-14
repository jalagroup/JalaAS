// lib/models/aging_report.dart
class AgingReport {
  final String currency;
  final String contactCode;
  final String contactName;
  final String contactPhone;
  final String total;
  final String balance;
  final String period1To26Days;
  final String period27To52Days;
  final String period53PlusDays;

  AgingReport({
    required this.currency,
    required this.contactCode,
    required this.contactName,
    required this.contactPhone,
    required this.total,
    required this.balance,
    required this.period1To26Days,
    required this.period27To52Days,
    required this.period53PlusDays,
  });

  factory AgingReport.fromJson(Map<String, dynamic> json) {
    return AgingReport(
      currency: json['shownCurr'] as String? ?? '',
      contactCode: json['shownCont'] as String? ?? '',
      contactName: json['shownCont.name'] as String? ?? '',
      contactPhone: json['shownCont.phone'] as String? ?? '',
      total: json['total'] as String? ?? '',
      balance: json['balance'] as String? ?? '',
      period1To26Days: json['1-26days'] as String? ?? '',
      period27To52Days: json['27-52days'] as String? ?? '',
      period53PlusDays: json['53+days'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shownCurr': currency,
      'shownCont': contactCode,
      'shownCont.name': contactName,
      'shownCont.phone': contactPhone,
      'total': total,
      'balance': balance,
      '1-26days': period1To26Days,
      '27-52days': period27To52Days,
      '53+days': period53PlusDays,
    };
  }

  // Helper methods to get numeric values
  double get totalAmount => _parseAmount(total);
  double get balanceAmount => _parseAmount(balance);
  double get period1To26Amount => _parseAmount(period1To26Days);
  double get period27To52Amount => _parseAmount(period27To52Days);
  double get period53PlusAmount => _parseAmount(period53PlusDays);

  double _parseAmount(String amount) {
    if (amount.isEmpty) return 0.0;
    // Remove commas and parse
    return double.tryParse(amount.replaceAll(',', '')) ?? 0.0;
  }

  @override
  String toString() {
    return 'AgingReport(contactCode: $contactCode, contactName: $contactName, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AgingReport && other.contactCode == contactCode;
  }

  @override
  int get hashCode => contactCode.hashCode;
}
