// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jala_as/models/aging_report.dart';
import 'package:jala_as/models/area.dart';
import 'package:jala_as/models/salesman.dart';
import '../models/contact.dart';
import '../models/account_statement.dart';

class ApiService {
  static const String _powerAutomateUrl =
      'https://prod-245.westeurope.logic.azure.com:443/workflows/7027d0574e584e088fe34c5a2a4ddae7/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=nAcu6QCYe2i9KGcb8qHyqVjBbe-3nSs3AHm0mpkFikI';

  static const String _tokenUrl =
      'https://script.google.com/macros/s/AKfycby7q0QHLM9YZ8zCOGpgQGXtSPSTdtWrXJe_v5Nls1tYG2NZAws-ezDZ1U9Q1XA-sa25/exec';

  static Future<String> _getToken() async {
    try {
      final response = await http.get(Uri.parse(_tokenUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tokens = data['data'] as List;

        if (tokens.isNotEmpty) {
          // Get the last token (most recent)
          return tokens.last['token'] as String;
        }
      }

      throw Exception('Failed to get token');
    } catch (e) {
      throw Exception('Failed to get token: $e');
    }
  }

  static Future<Map<String, dynamic>> _makeApiRequest({
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      final token = await _getToken();

      final requestBody = {
        'url': url,
        'token': token,
        'method': method,
        if (headers != null) 'headers': headers,
        if (body != null) 'body': body,
      };

      final response = await http.post(
        Uri.parse(_powerAutomateUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('API request failed: $e');
    }
  }

  static Future<List<Contact>> getContacts() async {
    const String contactsUrl =
        'https://gw.bisan.com/api/v2/jalaf/contact?fields=code,nameAR,area,area.name,salesman,streetAddress,taxId,phone&search=enabled:yes';

    final response = await _makeApiRequest(
      url: contactsUrl,
      method: 'GET',
    );

    final rows = response['rows'] as List;
    return rows.map((row) => Contact.fromBisanJson(row)).toList();
  }

// Updated getAgingReport method to handle admin users with salesman range
  static Future<List<AgingReport>> getAgingReport({
    required String salesman,
    String? area,
    String? specificArea, // New parameter for admin area selection
    String? salesmanFrom, // New parameter for admin salesman from
    String? salesmanTo, // New parameter for admin salesman to
  }) async {
    // Get the last day of current month
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final asOfDate =
        '${lastDayOfMonth.year}-${lastDayOfMonth.month.toString().padLeft(2, '0')}-${lastDayOfMonth.day.toString().padLeft(2, '0')}';

    String agingUrl;

    // Check if user is admin (salesman=00 and area=00)
    if (salesman == '00' && area == '00') {
      // Get available salesmen for default values
      final availableSalesmen = getAvailableSalesmen();
      final firstSalesman = availableSalesmen.first.code; // "001"
      final lastSalesman = availableSalesmen.last.code; // "835"

      // Handle salesman range selection with auto-completion
      String? finalSalesmanFrom = salesmanFrom;
      String? finalSalesmanTo = salesmanTo;

      // Auto-complete missing salesman values
      if (salesmanFrom != null && salesmanTo == null) {
        finalSalesmanTo = lastSalesman; // Use last salesman (835)
      } else if (salesmanFrom == null && salesmanTo != null) {
        finalSalesmanFrom = firstSalesman; // Use first salesman (001)
      }

      // Build URL based on provided parameters
      if (finalSalesmanFrom != null && finalSalesmanTo != null) {
        // Case 1 & 2: Salesman range with or without area
        String baseUrl =
            'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?search=asOfDate:$asOfDate,groupType:دليل,fromContactType:001,toContactType:006,fromSalesman:$finalSalesmanFrom,toSalesman:$finalSalesmanTo';

        // Add area if specified
        if (specificArea != null && specificArea.isNotEmpty) {
          baseUrl += ',area:$specificArea';
        }

        baseUrl +=
            ',branch:00,numPeriods:3,daysPerPeriod:26,isCustomer:true,useContactSalesman:true,lg_status:مرحل';
        agingUrl = baseUrl;
      } else if (specificArea != null && specificArea.isNotEmpty) {
        // Case 3: Area only
        agingUrl =
            'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?search=asOfDate:$asOfDate,groupType:دليل,fromContactType:001,toContactType:006,area:$specificArea,branch:00,numPeriods:3,daysPerPeriod:26,isCustomer:true,useContactSalesman:true,lg_status:مرحل';
      } else {
        // No valid parameters provided, return empty list
        return [];
      }
    } else {
      // Regular user - use existing logic
      if (area != null && area.isNotEmpty) {
        agingUrl =
            'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?search=asOfDate:$asOfDate,groupType:دليل,fromContactType:001,toContactType:006,fromSalesman:$salesman,toSalesman:$salesman,area:$area,branch:00,numPeriods:3,daysPerPeriod:26,isCustomer:true,useContactSalesman:true,lg_status:مرحل';
      } else {
        agingUrl =
            'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?search=asOfDate:$asOfDate,groupType:دليل,fromContactType:001,toContactType:006,fromSalesman:$salesman,toSalesman:$salesman,branch:00,numPeriods:3,daysPerPeriod:26,isCustomer:true,useContactSalesman:true,lg_status:مرحل';
      }
    }

    final response = await _makeApiRequest(
      url: agingUrl,
      method: 'GET',
    );
    print(agingUrl);

    final rows = response['rows'] as List;
    return rows.map((row) => AgingReport.fromJson(row)).toList();
  }

// New method to get available areas
  static List<Area> getAvailableAreas() {
    return [
      Area(code: "008", name: "رام الله  -  فرع  الالبان"),
      Area(code: "009", name: "رام الله - فرع الالبان 2"),
      Area(code: "010", name: "مدينة الخليل"),
      Area(code: "011", name: "قرى الخليل"),
      Area(code: "012", name: "الخليل - مبرد"),
      Area(code: "013", name: "قرى الخليل - مبرد"),
      Area(code: "014", name: "العبيدية"),
      Area(code: "015", name: "العبيدية - مبرد"),
      Area(code: "016", name: "بيت لحم"),
      Area(code: "017", name: "بيت لحم - مبرد"),
      Area(code: "018", name: "بيت ساحور"),
      Area(code: "019", name: "بيت ساحور - مبرد"),
      Area(code: "020", name: "بيت جالا"),
      Area(code: "021", name: "بيت جالا - مبرد"),
      Area(code: "022", name: "شارع القدس الخليل"),
      Area(code: "023", name: "شارع القدس الخليل - مبرد"),
      Area(code: "024", name: "ابوديس، العيزرية"),
      Area(code: "025", name: "ابوديس، العيزرية - مبرد"),
      Area(code: "027", name: "قرى بيت لحم الشرقية - مبرد"),
      Area(code: "029", name: "قرى بيت لحم الغربية - مبرد"),
      Area(code: "030", name: "اريحا"),
      Area(code: "035", name: "خط فؤاد غنيم"),
      Area(code: "048", name: "مطاعم بيت لحم M"),
      Area(code: "049", name: "مطاعم بيت لحم J"),
      Area(code: "050", name: "رام الله"),
      Area(code: "051", name: "رام الله - مبرد"),
      Area(code: "052", name: "قرى رام الله - مبرد"),
      Area(code: "053", name: "قرى رام الله"),
      Area(code: "054", name: "عناتا، حزما ،الرام"),
      Area(code: "055", name: "عناتا، حزما ،الرام - مبرد"),
      Area(code: "056", name: "اريحا - مبرد"),
      Area(code: "059", name: "نابلس"),
      Area(code: "060", name: "طولكرم"),
      Area(code: "070", name: "قلقيلية"),
      Area(code: "080", name: "جنين"),
      Area(code: "090", name: "القدس عيدن"),
      Area(code: "100", name: "القدس"),
      Area(code: "997", name: "عالق"),
      Area(code: "998", name: "قضايا"),
      Area(code: "999", name: "موظفين"),
    ];
  }

// Updated methods for lib/services/api_service.dart

  // Add this new method to get available salesmen
  static List<Salesman> getAvailableSalesmen() {
    return [
      Salesman(code: "001", name: "سليمان فؤاد سليمان دياب"),
      Salesman(code: "002", name: "معتز خالد ابراهيم الحموري"),
      Salesman(code: "003", name: "فراس منير فتحي سليمان"),
      Salesman(code: "005", name: "محمد عطية عبد  عطيه"),
      Salesman(code: "007", name: "شركة جالا فود"),
      Salesman(code: "015", name: "مايك الياس باسيل غنيم"),
      Salesman(code: "030", name: "جوني خالد باسيل المصو"),
      Salesman(code: "031", name: "احمد علي حسن عكيله"),
      Salesman(code: "045", name: "اسماعيل يعقوب احمد الهودلي"),
      Salesman(code: "046", name: "فؤاد سهيل فؤاد غنيم"),
      Salesman(code: "047", name: "مهند زياد عبد الحميد العيسه"),
      Salesman(code: "048", name: "اياد عزيز سليمان عبد"),
      Salesman(code: "050", name: "ايليا ماهر  ابراهيم  زيدان")
    ];
  }

  static Future<List<AccountStatement>> getAccountStatements({
    required String contactCode,
    required String fromDate,
    required String toDate,
  }) async {
    final String statementsUrl =
        'https://gw.bisan.com/api/v2/jalaf/REPORT/customerStatement.json?search=fromDate:$fromDate,toDate:$toDate,reference:$contactCode,currency:01,branch:00,showTotalPerAct:true,includeCashMov:true,showSettledAmounts:false,lg_status:مرحل';

    final response = await _makeApiRequest(
      url: statementsUrl,
      method: 'GET',
    );

    final rows = response['rows'] as List;
    return rows.map((row) => AccountStatement.fromJson(row)).toList();
  }

  static Future<List<AccountStatementDetail>> getAccountStatementDetails({
    required String contactCode,
    required String fromDate,
    required String toDate,
  }) async {
    final String detailsUrl =
        'https://gw.bisan.com/api/v2/jalaf/REPORT/customerStatementDetail.json?search=fromDate:$fromDate,toDate:$toDate,reference:$contactCode,includeCashMov:true,priceIncludeTax:true,showCashInfo:true,showItemInfo:true,selectAll:true,lg_status:مرحل';

    final response = await _makeApiRequest(
      url: detailsUrl,
      method: 'GET',
    );

    final rows = response['rows'] as List;
    return rows.map((row) => AccountStatementDetail.fromJson(row)).toList();
  }
}
