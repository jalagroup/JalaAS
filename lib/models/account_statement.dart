// lib/models/account_statement.dart
class AccountStatement {
  final String shownCurr;
  final String account;
  final String accountName;
  final String docDate;
  final String shownParent;
  final String subAct;
  final String branch;
  final String costCenter;
  final String debit;
  final String credit;
  final String runningBalance;
  final String docComment;

  AccountStatement({
    required this.shownCurr,
    required this.account,
    required this.accountName,
    required this.docDate,
    required this.shownParent,
    required this.subAct,
    required this.branch,
    required this.costCenter,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    required this.docComment,
  });

  factory AccountStatement.fromJson(Map<String, dynamic> json) {
    return AccountStatement(
      shownCurr: json['shownCurr'] ?? '',
      account: json['account'] ?? '',
      accountName: json['account.name'] ?? '',
      docDate: json['docDate'] ?? '',
      shownParent: json['shownParent'] ?? '',
      subAct: json['subAct'] ?? '',
      branch: json['branch'] ?? '',
      costCenter: json['costCenter'] ?? '',
      debit: json['debit'] ?? '',
      credit: json['credit'] ?? '',
      runningBalance: json['runningBalance'] ?? '',
      docComment: json['docComment'] ?? '',
    );
  }

  String get documentType {
    if (shownParent.contains('ف.مبيعات') || shownParent.contains('ف.يدوية')) {
      return 'invoice';
    } else if (shownParent.contains('م. مبيعات') ||
        shownParent.contains('م.مبيعات')) {
      return 'return';
    } else if (shownParent.contains('قبض يدوي') ||
        shownParent.contains('قبض')) {
      return 'payment';
    }
    return 'other';
  }

  String get documentNumber {
    // Extract document number from shownParent
    String cleaned =
        shownParent.replaceAll(RegExp(r'[\u202A\u202C\u202D\u202E]'), '');

    if (documentType == 'invoice') {
      return cleaned.replaceAll(RegExp(r'\s*(ف\.مبيعات|ف\.يدوية)\s*'), '');
    } else if (documentType == 'return') {
      return cleaned.replaceAll(RegExp(r'\s*(م\.\s*مبيعات|م\.مبيعات)\s*'), '');
    } else if (documentType == 'payment') {
      return cleaned.replaceAll(RegExp(r'\s*(قبض يدوي|قبض)\s*'), '');
    }
    return cleaned;
  }

  String get displayName {
    String number = documentNumber.trim();
    switch (documentType) {
      case 'invoice':
        return 'فاتورة $number';
      case 'return':
        return 'مرتجع $number';
      case 'payment':
        return 'قبض $number';
      default:
        return shownParent;
    }
  }

  String get docNumber {
    String number = documentNumber.trim();
    switch (documentType) {
      case 'invoice':
        return number;
      case 'return':
        return number;
      case 'payment':
        return number;
      default:
        return shownParent;
    }
  }
}

class AccountStatementDetail {
  final String shownCurr;
  final String docDate;
  final String shownParent;
  final String item;
  final String name;
  final String unit;
  final String quantity;
  final String price;
  final String discount;
  final String bonus;
  final String comment;
  final String amount;
  final String accountNumber;
  final String currency;
  final String check;
  final String checkNumber;
  final String checkDueDate;
  final String cash;
  final String account;
  final String accountName;
  final String debit;
  final String credit;
  final String balance;
  final String runningBalance;
  final String docDiscount;
  final String tax;
  final String cusReference;
  final String docComment;

  AccountStatementDetail({
    required this.shownCurr,
    required this.docDate,
    required this.shownParent,
    required this.item,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.discount,
    required this.bonus,
    required this.comment,
    required this.amount,
    required this.accountNumber,
    required this.currency,
    required this.check,
    required this.checkNumber,
    required this.checkDueDate,
    required this.cash,
    required this.account,
    required this.accountName,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.runningBalance,
    required this.docDiscount,
    required this.tax,
    required this.cusReference,
    required this.docComment,
  });

  factory AccountStatementDetail.fromJson(Map<String, dynamic> json) {
    return AccountStatementDetail(
      shownCurr: json['shownCurr'] ?? '',
      docDate: json['docDate'] ?? '',
      shownParent: json['shownParent'] ?? '',
      item: json['item'] ?? '',
      name: json['name'] ?? '',
      unit: json['unit'] ?? '',
      quantity: json['quantity'] ?? '',
      price: json['price'] ?? '',
      discount: json['discount'] ?? '',
      bonus: json['bonus'] ?? '',
      comment: json['comment'] ?? '',
      amount: json['amount'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      currency: json['currency'] ?? '',
      check: json['check'] ?? '',
      checkNumber: json['check.checkNumber'] ?? '',
      checkDueDate: json['check.dueDate'] ?? '',
      cash: json['cash'] ?? '',
      account: json['account'] ?? '',
      accountName: json['account.name'] ?? '',
      debit: json['debit'] ?? '',
      credit: json['credit'] ?? '',
      balance: json['balance'] ?? '',
      runningBalance: json['runningBalance'] ?? '',
      docDiscount: json['docDiscount'] ?? '',
      tax: json['tax'] ?? '',
      cusReference: json['cusReference'] ?? '',
      docComment: json['docComment'] ?? '',
    );
  }

  bool get isPayment => check.isEmpty && cash.isNotEmpty;
  bool get isCheck => check.isNotEmpty;
}
