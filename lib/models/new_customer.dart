// lib/models/new_customer.dart - NEW FILE

class NewCustomer {
  final int id;
  final String bisanCode;
  final String businessName;
  final String ownerName;
  final String? responsiblePerson;
  final String? taxId;
  final String? idNumber;
  final String mobile;
  final String? telephone;
  final String? email;
  final String? city;
  final String? state;
  final String? stateType;
  final String? street;
  final String? beside;
  final String? businessType;
  final String? businessTypeName;
  final String? visitDays;
  final String? paymentMethod;
  final String? creditLimit;
  final DateTime createdDate;
  final String salesman;
  final String username;
  final String status;
  final String? pdfUrl;
  final String? createdBy;
  final String? checkedBy;
  final DateTime? checkedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NewCustomerImage> images;

  NewCustomer({
    required this.id,
    required this.bisanCode,
    required this.businessName,
    required this.ownerName,
    this.responsiblePerson,
    this.taxId,
    this.idNumber,
    required this.mobile,
    this.telephone,
    this.email,
    this.city,
    this.state,
    this.stateType,
    this.street,
    this.beside,
    this.businessType,
    this.businessTypeName,
    this.visitDays,
    this.paymentMethod,
    this.creditLimit,
    required this.createdDate,
    required this.salesman,
    required this.username,
    required this.status,
    this.pdfUrl,
    this.createdBy,
    this.checkedBy,
    this.checkedAt,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
  });

  bool get isChecked => status == 'checked';
  bool get isUnchecked => status == 'unchecked';

  factory NewCustomer.fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'] as List?;
    final imagesList = imagesJson
            ?.map(
                (img) => NewCustomerImage.fromJson(img as Map<String, dynamic>))
            .toList() ??
        [];

    return NewCustomer(
      id: json['id'] as int,
      bisanCode: json['bisan_code'] as String,
      businessName: json['business_name'] as String,
      ownerName: json['owner_name'] as String,
      responsiblePerson: json['responsible_person'] as String?,
      taxId: json['tax_id'] as String?,
      idNumber: json['id_number'] as String?,
      mobile: json['mobile'] as String,
      telephone: json['telephone'] as String?,
      email: json['email'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      stateType: json['state_type'] as String?,
      street: json['street'] as String?,
      beside: json['beside'] as String?,
      businessType: json['business_type'] as String?,
      businessTypeName: json['business_type_name'] as String?,
      visitDays: json['visit_days'] as String?,
      paymentMethod: json['payment_method'] as String?,
      creditLimit: json['credit_limit'] as String?,
      createdDate: DateTime.parse(json['created_date'] as String),
      salesman: json['salesman'] as String,
      username: json['username'] as String,
      status: json['status'] as String,
      pdfUrl: json['pdf_url'] as String?,
      createdBy: json['created_by'] as String?,
      checkedBy: json['checked_by'] as String?,
      checkedAt: json['checked_at'] != null
          ? DateTime.parse(json['checked_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      images: imagesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bisan_code': bisanCode,
      'business_name': businessName,
      'owner_name': ownerName,
      'responsible_person': responsiblePerson,
      'tax_id': taxId,
      'id_number': idNumber,
      'mobile': mobile,
      'telephone': telephone,
      'email': email,
      'city': city,
      'state': state,
      'state_type': stateType,
      'street': street,
      'beside': beside,
      'business_type': businessType,
      'business_type_name': businessTypeName,
      'visit_days': visitDays,
      'payment_method': paymentMethod,
      'credit_limit': creditLimit,
      'created_date': createdDate.toIso8601String(),
      'salesman': salesman,
      'username': username,
      'status': status,
      'pdf_url': pdfUrl,
      'created_by': createdBy,
      'checked_by': checkedBy,
      'checked_at': checkedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'images': images.map((img) => img.toJson()).toList(),
    };
  }
}

class NewCustomerImage {
  final int id;
  final String imageUrl;
  final String imageName;
  final int? imageSize;
  final String? mimeType;
  final DateTime uploadedAt;

  NewCustomerImage({
    required this.id,
    required this.imageUrl,
    required this.imageName,
    this.imageSize,
    this.mimeType,
    required this.uploadedAt,
  });

  factory NewCustomerImage.fromJson(Map<String, dynamic> json) {
    return NewCustomerImage(
      id: json['id'] as int,
      imageUrl: json['image_url'] as String,
      imageName: json['image_name'] as String,
      imageSize: json['image_size'] as int?,
      mimeType: json['mime_type'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'image_name': imageName,
      'image_size': imageSize,
      'mime_type': mimeType,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}
