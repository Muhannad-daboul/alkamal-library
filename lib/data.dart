import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ── Static UI models ──────────────────────────────────────
class CategoryItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData? faIcon;
  final String? svgAsset;
  final Color color;
  final List<String> years;

  CategoryItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.faIcon,
    this.svgAsset,
    required this.color,
    required this.years,
  });
}

// ── Lecture categories ────────────────────────────────────
final lectureCategories = <CategoryItem>[
  CategoryItem(
    title: 'كلية الطب البشري',
    subtitle: 'محاضرات كلية الطب البشري',
    icon: Icons.medical_services_outlined,
    faIcon: FontAwesomeIcons.stethoscope,
    svgAsset: 'assets/illustrations/medicine.svg',
    color: const Color(0xFF1E88E5),
    years: ['السنة الثانية', 'السنة الثالثة', 'السنة الرابعة', 'السنة الخامسة'],
  ),
  CategoryItem(
    title: 'كلية الصيدلة',
    subtitle: 'محاضرات كلية الصيدلة',
    icon: Icons.science_outlined,
    faIcon: FontAwesomeIcons.pills,
    svgAsset: 'assets/illustrations/pharmacy.svg',
    color: const Color(0xFF43A047),
    years: ['السنة الثانية', 'السنة الثالثة', 'السنة الرابعة', 'السنة الخامسة'],
  ),
  CategoryItem(
    title: 'كلية طب الأسنان',
    subtitle: 'محاضرات طب الأسنان',
    icon: Icons.health_and_safety_outlined,
    faIcon: FontAwesomeIcons.tooth,
    svgAsset: 'assets/illustrations/dentistry.svg',
    color: const Color(0xFF8E24AA),
    years: ['السنة الثانية', 'السنة الثالثة', 'السنة الرابعة', 'السنة الخامسة'],
  ),
  CategoryItem(
    title: 'السنة التحضيرية',
    subtitle: 'محاضرات السنة التحضيرية',
    icon: Icons.school_outlined,
    faIcon: FontAwesomeIcons.graduationCap,
    svgAsset: 'assets/illustrations/preparatory.svg',
    color: const Color(0xFFF4511E),
    years: ['السنة التحضيرية'],
  ),
];

class SupplyCategory {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  SupplyCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class PromoBanner {
  final String title;
  final String subtitle;
  final Color background;

  PromoBanner({
    required this.title,
    required this.subtitle,
    required this.background,
  });
}

// ── Firestore models ──────────────────────────────────────
class ArchiveSection {
  final String name;
  final bool hidden;

  const ArchiveSection({required this.name, this.hidden = false});

  Map<String, dynamic> toMap() => {'name': name, 'hidden': hidden};
}

class Product {
  final String id;
  final String category;
  final String year;
  final String semester;
  final String title;
  final String description;
  final int pages;
  final int stock;
  final bool available;
  final String imageUrl;
  final double? customPrice; // سعر مخصص يتجاوز pages × pricePerPage إذا ضُبط
  final String pageSize; // A4 / A5 / B5

  Product({
    this.id = '',
    required this.category,
    required this.year,
    this.semester = 'الفصل الأول',
    required this.title,
    required this.description,
    required this.pages,
    this.stock = 0,
    this.available = true,
    this.imageUrl = '',
    this.customPrice,
    this.pageSize = 'A4',
  });

  factory Product.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      category: d['category'] ?? '',
      year: d['year'] ?? '',
      semester: d['semester'] ?? 'الفصل الأول',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      pages: (d['pages'] as num?)?.toInt() ?? 0,
      stock: (d['stock'] as num?)?.toInt() ?? 0,
      available: d['available'] ?? true,
      imageUrl: d['imageUrl'] ?? '',
      customPrice: (d['customPrice'] as num?)?.toDouble(),
      pageSize: (d['pageSize'] as String?) ?? 'A4',
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'category': category,
      'year': year,
      'semester': semester,
      'title': title,
      'description': description,
      'pages': pages,
      'stock': stock,
      'available': available,
      'imageUrl': imageUrl,
      'pageSize': pageSize,
    };
    if (customPrice != null) m['customPrice'] = customPrice;
    return m;
  }

  Product copyWith({
    int? pages,
    int? stock,
    bool? available,
    String? imageUrl,
    String? pageSize,
    Object? customPrice = _sentinel,
  }) => Product(
    id: id,
    category: category,
    year: year,
    semester: semester,
    title: title,
    description: description,
    pages: pages ?? this.pages,
    stock: stock ?? this.stock,
    available: available ?? this.available,
    imageUrl: imageUrl ?? this.imageUrl,
    customPrice: customPrice == _sentinel ? this.customPrice : customPrice as double?,
    pageSize: pageSize ?? this.pageSize,
  );
}

const _sentinel = Object();

class SupplyProduct {
  final String id;
  final String category;
  final String title;
  final String description;
  final double price;
  final int stock;
  final bool available;
  final String imageUrl;

  SupplyProduct({
    this.id = '',
    required this.category,
    required this.title,
    required this.description,
    required this.price,
    this.stock = 0,
    this.available = true,
    this.imageUrl = '',
  });

  factory SupplyProduct.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SupplyProduct(
      id: doc.id,
      category: d['category'] ?? '',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0.0,
      stock: (d['stock'] as num?)?.toInt() ?? 0,
      available: d['available'] ?? true,
      imageUrl: d['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'category': category,
    'title': title,
    'description': description,
    'price': price,
    'stock': stock,
    'available': available,
    'imageUrl': imageUrl,
  };

  SupplyProduct copyWith({
    double? price,
    int? stock,
    bool? available,
    String? imageUrl,
  }) => SupplyProduct(
    id: id,
    category: category,
    title: title,
    description: description,
    price: price ?? this.price,
    stock: stock ?? this.stock,
    available: available ?? this.available,
    imageUrl: imageUrl ?? this.imageUrl,
  );
}

class Lecture {
  final String id;
  final String category;
  final String year;
  final String semester;
  final String archiveSection; // أرشيف 2023-2024 | أرشيف 2024-2025 | السنة الحالية
  final String subject;        // اسم المادة (تشريح رأس وعنق، فيزيو، ...)
  final String title;
  final int lectureNumber;
  final String doctorName;
  final int pages;
  final String pageSize; // A4 / A5 / B5
  final int stock;
  final bool available;
  final String previewImageUrl; // صورة الصفحة الأولى فقط
  final double? customPrice;

  Lecture({
    this.id = '',
    required this.category,
    required this.year,
    this.semester = 'الفصل الأول',
    this.archiveSection = 'السنة الحالية',
    this.subject = '',
    required this.title,
    required this.lectureNumber,
    this.doctorName = '',
    required this.pages,
    this.pageSize = 'A4',
    this.stock = 0,
    this.available = true,
    this.previewImageUrl = '',
    this.customPrice,
  });

  factory Lecture.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Lecture(
      id: doc.id,
      category: d['category'] ?? '',
      year: d['year'] ?? '',
      semester: d['semester'] ?? 'الفصل الأول',
      archiveSection: d['archiveSection'] ?? 'السنة الحالية',
      subject: d['subject'] ?? '',
      title: d['title'] ?? '',
      lectureNumber: (d['lectureNumber'] as num?)?.toInt() ?? 0,
      doctorName: d['doctorName'] ?? '',
      pages: (d['pages'] as num?)?.toInt() ?? 0,
      pageSize: (d['pageSize'] as String?) ?? 'A4',
      stock: (d['stock'] as num?)?.toInt() ?? 0,
      available: d['available'] ?? true,
      previewImageUrl: d['previewImageUrl'] ?? '',
      customPrice: (d['customPrice'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'category': category,
      'year': year,
      'semester': semester,
      'archiveSection': archiveSection,
      'subject': subject,
      'title': title,
      'lectureNumber': lectureNumber,
      'doctorName': doctorName,
      'pages': pages,
      'pageSize': pageSize,
      'stock': stock,
      'available': available,
      'previewImageUrl': previewImageUrl,
    };
    if (customPrice != null) m['customPrice'] = customPrice;
    return m;
  }
}

class OrderItem {
  final String title;
  final double price;
  final int quantity;
  final bool isSupply;
  final String imageUrl;
  final bool isPrintJob;
  final String printJobStoragePath;
  final String? bindingType;

  OrderItem({
    required this.title,
    required this.price,
    required this.quantity,
    required this.isSupply,
    required this.imageUrl,
    this.isPrintJob = false,
    this.printJobStoragePath = '',
    this.bindingType,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      title: data['title'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      isSupply: data['isSupply'] ?? false,
      imageUrl: data['imageUrl'] ?? '',
      isPrintJob: data['isPrintJob'] ?? false,
      printJobStoragePath: data['printJobStoragePath'] ?? '',
      bindingType: data['bindingType'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'title': title,
      'price': price,
      'quantity': quantity,
      'isSupply': isSupply,
      'imageUrl': imageUrl,
    };
    if (isPrintJob) m['isPrintJob'] = isPrintJob;
    if (printJobStoragePath.isNotEmpty) m['printJobStoragePath'] = printJobStoragePath;
    if (bindingType != null) m['bindingType'] = bindingType;
    return m;
  }
}

class Order {
  final String id;
  final String userName;
  final String phone;
  final String address;
  final String notes;
  final double total;
  final String status;
  final DateTime createdAt;
  final double deliveryLat;
  final double deliveryLng;
  final List<OrderItem> items;
  final String fcmToken;
  final String assignedAgent;
  final String zone;
  final String deliveryMethod; // 'delivery' | 'pickup'
  final String pickupCode;     // رمز التسليم للاستلام الشخصي
  final int rating;            // 0 = لم يُقيَّم, 1-5 = التقييم
  final String ratingFeedback; // ملاحظة عند التقييم السيئ

  Order({
    this.id = '',
    required this.userName,
    required this.phone,
    required this.address,
    required this.notes,
    required this.total,
    this.status = 'قيد التجهيز',
    required this.createdAt,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.items,
    this.fcmToken = '',
    this.assignedAgent = '',
    this.zone = '',
    this.deliveryMethod = 'delivery',
    this.pickupCode = '',
    this.rating = 0,
    this.ratingFeedback = '',
  });

  factory Order.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      userName: d['userName'] ?? '',
      phone: d['phone'] ?? '',
      address: d['address'] ?? '',
      notes: d['notes'] ?? '',
      total: (d['total'] as num?)?.toDouble() ?? 0,
      status: d['status'] ?? 'قيد التجهيز',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveryLat: (d['deliveryLat'] as num?)?.toDouble() ?? 0,
      deliveryLng: (d['deliveryLng'] as num?)?.toDouble() ?? 0,
      items: (d['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      fcmToken: d['fcmToken'] ?? '',
      assignedAgent: d['assignedAgent'] ?? '',
      zone: d['zone'] ?? '',
      deliveryMethod: d['deliveryMethod'] ?? 'delivery',
      pickupCode: d['pickupCode'] ?? '',
      rating: (d['rating'] as num?)?.toInt() ?? 0,
      ratingFeedback: d['ratingFeedback'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'userName': userName,
    'phone': phone,
    'address': address,
    'notes': notes,
    'total': total,
    'status': status,
    'createdAt': createdAt,
    'deliveryLat': deliveryLat,
    'deliveryLng': deliveryLng,
    'items': items.map((i) => i.toMap()).toList(),
    'fcmToken': fcmToken,
    'assignedAgent': assignedAgent,
    'zone': zone,
    'deliveryMethod': deliveryMethod,
    'pickupCode': pickupCode,
    'rating': rating,
    'ratingFeedback': ratingFeedback,
  };
}

// الفروع الثابتة
const kBranches = [
  _Branch('فرع المزة',     33.507639, 36.266222),
  _Branch('فرع البرامكة', 33.510040, 36.280667),
];

class _Branch {
  final String name;
  final double lat;
  final double lng;
  const _Branch(this.name, this.lat, this.lng);
}

class DeliverySettings {
  final int    activeBranch; // 0 = المزة، 1 = البرامكة
  final double baseFee;
  final double feePerKm;
  final double freeAbove;

  const DeliverySettings({
    this.activeBranch = 0,
    this.baseFee      = 500,
    this.feePerKm     = 200,
    this.freeAbove    = 0,
  });

  double get storeLat => kBranches[activeBranch].lat;
  double get storeLng => kBranches[activeBranch].lng;
  String get branchName => kBranches[activeBranch].name;

  factory DeliverySettings.fromMap(Map<String, dynamic> d) => DeliverySettings(
    activeBranch: (d['activeBranch'] as num?)?.toInt() ?? 0,
    baseFee:      (d['baseFee']      as num?)?.toDouble() ?? 500,
    feePerKm:     (d['feePerKm']     as num?)?.toDouble() ?? 200,
    freeAbove:    (d['freeAbove']    as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'activeBranch': activeBranch,
    'baseFee':      baseFee,
    'feePerKm':     feePerKm,
    'freeAbove':    freeAbove,
  };

  double calcFee(double userLat, double userLng, double orderTotal) {
    if (freeAbove > 0 && orderTotal >= freeAbove) return 0;
    const earthR = 6371.0;
    final dLat = _toRad(userLat - storeLat);
    final dLng = _toRad(userLng - storeLng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(storeLat)) *
            math.cos(_toRad(userLat)) *
            math.pow(math.sin(dLng / 2), 2);
    final km = earthR * 2 * math.asin(math.sqrt(a));
    return baseFee + (km * feePerKm);
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}

class PromoCode {
  final String id;
  final String code;
  final double discount;
  final String type; // 'percent' | 'fixed'
  final bool active;
  final DateTime? expiresAt;
  final int usageLimit; // 0 = unlimited
  final int usedCount;
  final DateTime? createdAt;

  PromoCode({
    this.id = '',
    required this.code,
    required this.discount,
    this.type = 'percent',
    this.active = true,
    this.expiresAt,
    this.usageLimit = 0,
    this.usedCount = 0,
    this.createdAt,
  });

  factory PromoCode.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PromoCode(
      id: doc.id,
      code: d['code'] ?? '',
      discount: (d['discount'] as num?)?.toDouble() ?? 0,
      type: d['type'] ?? 'percent',
      active: d['active'] ?? true,
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      usageLimit: (d['usageLimit'] as num?)?.toInt() ?? 0,
      usedCount: (d['usedCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'code': code,
    'discount': discount,
    'type': type,
    'active': active,
    'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    'usageLimit': usageLimit,
    'usedCount': usedCount,
  };
}

class AdBanner {
  final String id;
  final String imageUrl;
  final bool active;
  final int order;
  final DateTime? createdAt;

  AdBanner({
    this.id = '',
    required this.imageUrl,
    this.active = true,
    this.order = 0,
    this.createdAt,
  });

  factory AdBanner.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AdBanner(
      id: doc.id,
      imageUrl: d['imageUrl'] ?? '',
      active: d['active'] ?? true,
      order: (d['order'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'imageUrl': imageUrl,
    'active': active,
    'order': order,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };
}

class PagePricing {
  final double priceA4;
  final double priceA5;
  final double priceB5;
  final double bindingPrice;

  const PagePricing({
    this.priceA4 = 100.0,
    this.priceA5 = 80.0,
    this.priceB5 = 90.0,
    this.bindingPrice = 3000.0,
  });

  factory PagePricing.fromMap(Map<String, dynamic> d) => PagePricing(
    priceA4: (d['priceA4'] as num?)?.toDouble() ??
        (d['pricePerPage'] as num?)?.toDouble() ?? 100.0,
    priceA5: (d['priceA5'] as num?)?.toDouble() ?? 80.0,
    priceB5: (d['priceB5'] as num?)?.toDouble() ?? 90.0,
    bindingPrice: (d['bindingPrice'] as num?)?.toDouble() ?? 3000.0,
  );

  Map<String, dynamic> toMap() => {
    'priceA4': priceA4,
    'priceA5': priceA5,
    'priceB5': priceB5,
    'bindingPrice': bindingPrice,
  };

  double priceForSize(String size) {
    switch (size) {
      case 'A5': return priceA5;
      case 'B5': return priceB5;
      default:   return priceA4;
    }
  }
}

class LectureDraft {
  final String id;
  final String fileName;
  final String previewImageUrl;
  final DateTime uploadedAt;
  final int pageCount;

  LectureDraft({
    this.id = '',
    required this.fileName,
    this.previewImageUrl = '',
    required this.uploadedAt,
    this.pageCount = 0,
  });

  factory LectureDraft.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LectureDraft(
      id: doc.id,
      fileName: d['fileName'] ?? '',
      previewImageUrl: d['previewImageUrl'] ?? '',
      uploadedAt: (d['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pageCount: (d['pageCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'fileName': fileName,
    'previewImageUrl': previewImageUrl,
    'uploadedAt': Timestamp.fromDate(uploadedAt),
    'pageCount': pageCount,
  };
}

class PrintPricing {
  final double bwSinglePage;
  final double bwDoublePage;
  final double colorSinglePage;
  final double colorDoublePage;
  final double bindingStaple;
  final double bindingSpiral;

  const PrintPricing({
    this.bwSinglePage = 25.0,
    this.bwDoublePage = 20.0,
    this.colorSinglePage = 100.0,
    this.colorDoublePage = 80.0,
    this.bindingStaple = 500.0,
    this.bindingSpiral = 1500.0,
  });

  factory PrintPricing.fromMap(Map<String, dynamic> d) => PrintPricing(
    bwSinglePage: (d['bwSinglePage'] as num?)?.toDouble() ?? 25.0,
    bwDoublePage: (d['bwDoublePage'] as num?)?.toDouble() ?? 20.0,
    colorSinglePage: (d['colorSinglePage'] as num?)?.toDouble() ?? 100.0,
    colorDoublePage: (d['colorDoublePage'] as num?)?.toDouble() ?? 80.0,
    bindingStaple: (d['bindingStaple'] as num?)?.toDouble() ?? 500.0,
    bindingSpiral: (d['bindingSpiral'] as num?)?.toDouble() ?? 1500.0,
  );

  Map<String, dynamic> toMap() => {
    'bwSinglePage': bwSinglePage,
    'bwDoublePage': bwDoublePage,
    'colorSinglePage': colorSinglePage,
    'colorDoublePage': colorDoublePage,
    'bindingStaple': bindingStaple,
    'bindingSpiral': bindingSpiral,
  };
}

// ── Static data ───────────────────────────────────────────
final banners = <PromoBanner>[
  PromoBanner(
    title: 'عروض الكمال',
    subtitle: 'خصومات على النوطات الجامعية والأدوات الطبية',
    background: const Color(0xFF009688),
  ),
  PromoBanner(
    title: 'نوطة اليوم',
    subtitle: 'نوطات مُصممة لطلاب الكليات الطبية',
    background: const Color(0xFF4DB3B1),
  ),
  PromoBanner(
    title: 'سريع وسهل',
    subtitle: 'اختيار منتجاتك بلمسة واحدة وإضافتها للسلة',
    background: const Color(0xFF00A896),
  ),
];

final categories = <CategoryItem>[
  CategoryItem(
    title: 'كلية الطب البشري',
    subtitle: 'محاضرات ونوطات طبية',
    icon: Icons.medical_services,
    svgAsset: 'assets/illustrations/medicine.svg',
    color: const Color(0xFF1E88E5),
    years: ['السنة الثانية', 'السنة الثالثة', 'السنة الرابعة', 'السنة الخامسة'],
  ),
  CategoryItem(
    title: 'كلية الصيدلة',
    subtitle: 'محاضرات وكتب صيدلانية',
    icon: Icons.local_pharmacy,
    svgAsset: 'assets/illustrations/pharmacy.svg',
    color: const Color(0xFF43A047),
    years: ['السنة الثانية', 'السنة الثالثة', 'السنة الرابعة', 'السنة الخامسة'],
  ),
  CategoryItem(
    title: 'كلية طب الأسنان',
    subtitle: 'محاضرات ونوطات طب الأسنان',
    icon: Icons.health_and_safety,
    svgAsset: 'assets/illustrations/dentistry.svg',
    color: const Color(0xFF8E24AA),
    years: ['السنة الثانية', 'السنة الثالثة', 'السنة الرابعة', 'السنة الخامسة'],
  ),
  CategoryItem(
    title: 'السنة التحضيرية',
    subtitle: 'محاضرات السنة التحضيرية',
    icon: Icons.school,
    svgAsset: 'assets/illustrations/preparatory.svg',
    color: const Color(0xFFF4511E),
    years: ['السنة التحضيرية'],
  ),
];

final supplyCategories = <SupplyCategory>[
  SupplyCategory(
    title: 'أدوات طب الأسنان',
    subtitle: 'مرايا، مجاسّ، ملاقط وأكثر',
    icon: Icons.health_and_safety,
    color: const Color(0xFF4EA8FF),
  ),
  SupplyCategory(
    title: 'أدوات الصيدلة',
    subtitle: 'أدوات مختبرية وصيدلانية',
    icon: Icons.science,
    color: const Color(0xFF7AC7C4),
  ),
  SupplyCategory(
    title: 'أدوات التحضيري',
    subtitle: 'أدوات عامة للسنة التحضيرية',
    icon: Icons.biotech,
    color: const Color(0xFF8BC34A),
  ),
  SupplyCategory(
    title: 'أدوات الطب',
    subtitle: 'سماعة، مشرط، أدوات فحص',
    icon: Icons.medical_services,
    color: const Color(0xFF4DB3B1),
  ),
];
