// lib/models/price_list_report.dart
class PriceListItem {
  final String itemCode;
  final String itemName;
  final String itemBrand;
  final String unit;
  final String partNumber;
  final String packVolume;

  // P Price List
  final String pCurrency;
  final String pRawPrice;
  final String pTaxPrice;

  // S Price List
  final String sCurrency;
  final String sRawPrice;
  final String sTaxPrice;

  PriceListItem({
    required this.itemCode,
    required this.itemName,
    required this.itemBrand,
    required this.unit,
    required this.partNumber,
    required this.packVolume,
    required this.pCurrency,
    required this.pRawPrice,
    required this.pTaxPrice,
    required this.sCurrency,
    required this.sRawPrice,
    required this.sTaxPrice,
  });

  factory PriceListItem.fromJson(Map<String, dynamic> json) {
    return PriceListItem(
      itemCode: json['item']?.toString() ?? '',
      itemName: json['item.name']?.toString() ?? '',
      itemBrand: json['item.brand']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      partNumber: json['partNumber']?.toString() ?? '',
      packVolume: json['packVolume']?.toString() ?? '',
      pCurrency: json['P_currency']?.toString() ?? '',
      pRawPrice: json['P_rawPrice']?.toString() ?? '',
      pTaxPrice: json['P_taxPrice']?.toString() ?? '',
      sCurrency: json['S_currency']?.toString() ?? '',
      sRawPrice: json['S_rawPrice']?.toString() ?? '',
      sTaxPrice: json['S_taxPrice']?.toString() ?? '',
    );
  }

  // Helper method to check if item matches search query
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;

    final lowerQuery = query.toLowerCase();
    return itemCode.toLowerCase().contains(lowerQuery) ||
        itemName.toLowerCase().contains(lowerQuery) ||
        itemBrand.toLowerCase().contains(lowerQuery) ||
        unit.toLowerCase().contains(lowerQuery) ||
        partNumber.toLowerCase().contains(lowerQuery) ||
        packVolume.toLowerCase().contains(lowerQuery);
  }
}

class PriceListReport {
  final List<PriceListItem> items;
  final Map<String, String> fieldLabels;

  PriceListReport({
    required this.items,
    required this.fieldLabels,
  });

  factory PriceListReport.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'] as List? ?? [];
    final fieldLabels = json['fieldLabels'] as Map<String, dynamic>? ?? {};

    return PriceListReport(
      items: rows.map((row) => PriceListItem.fromJson(row)).toList(),
      fieldLabels:
          fieldLabels.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  bool get hasData => items.isNotEmpty;
}
