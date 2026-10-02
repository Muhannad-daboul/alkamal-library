import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../data.dart';

class FirestoreService {
  static final _db = fs.FirebaseFirestore.instance;

  static fs.CollectionReference get _products => _db.collection('products');
  static fs.CollectionReference get _supplyProducts =>
      _db.collection('supply_products');
  static fs.CollectionReference get _lectures => _db.collection('lectures');
  static fs.CollectionReference get _orders => _db.collection('orders');
  static fs.DocumentReference get _pricing =>
      _db.collection('settings').doc('pricing');
  static fs.DocumentReference get _printPricing =>
      _db.collection('settings').doc('print_pricing');
  static fs.DocumentReference get _deliveryZonesDoc =>
      _db.collection('settings').doc('delivery_zones');
  static fs.DocumentReference get _archiveSectionsDoc =>
      _db.collection('settings').doc('archive_sections');

  // ── Archive Sections ──────────────────────────────────
  static const defaultArchiveSections = [
    'السنة الحالية',
    'أرشيف 2024-2025',
    'أرشيف 2023-2024',
  ];

  /// Parses the stored section list (supports legacy `List<String>` and the
  /// new `[{name, hidden}]` format) into a list of [ArchiveSection].
  static List<ArchiveSection> _parseSectionsField(dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      return defaultArchiveSections
          .map((n) => ArchiveSection(name: n))
          .toList();
    }
    final out = <ArchiveSection>[];
    for (final e in raw) {
      if (e is String) {
        out.add(ArchiveSection(name: e));
      } else if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final name = (m['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        out.add(ArchiveSection(name: name, hidden: m['hidden'] == true));
      }
    }
    return out.isEmpty
        ? defaultArchiveSections.map((n) => ArchiveSection(name: n)).toList()
        : out;
  }

  /// Visible section names (used by students and forms that need a
  /// dropdown of currently active sections).
  static Stream<List<String>> getArchiveSections() {
    return getArchiveSectionsAll().map(
      (list) => list.where((s) => !s.hidden).map((s) => s.name).toList(),
    );
  }

  /// Full list — includes hidden sections. Used by the admin editor so
  /// the admin can toggle visibility per section.
  static Stream<List<ArchiveSection>> getArchiveSectionsAll() {
    return _archiveSectionsDoc.snapshots().map((doc) {
      if (!doc.exists) {
        return defaultArchiveSections
            .map((n) => ArchiveSection(name: n))
            .toList();
      }
      final d = doc.data() as Map<String, dynamic>;
      return _parseSectionsField(d['sections']);
    });
  }

  /// Set the hidden flag for [name]. Creates the section entry if it
  /// doesn't exist yet (e.g. first-ever write).
  static Future<void> setArchiveSectionHidden(String name, bool hidden) async {
    final doc = await _archiveSectionsDoc.get();
    List<ArchiveSection> list;
    if (doc.exists) {
      final d = doc.data() as Map<String, dynamic>;
      list = _parseSectionsField(d['sections']);
    } else {
      list = defaultArchiveSections.map((n) => ArchiveSection(name: n)).toList();
    }
    var found = false;
    list = list.map((s) {
      if (s.name == name) {
        found = true;
        return ArchiveSection(name: s.name, hidden: hidden);
      }
      return s;
    }).toList();
    if (!found) list.add(ArchiveSection(name: name, hidden: hidden));
    await _archiveSectionsDoc
        .set({'sections': list.map((s) => s.toMap()).toList()});
  }

  // ── Delivery Zones ────────────────────────────────────
  static Stream<List<String>> getDeliveryZones() {
    return _deliveryZonesDoc.snapshots().map((doc) {
      if (!doc.exists) return <String>[];
      final d = doc.data() as Map<String, dynamic>;
      return List<String>.from(d['zones'] as List? ?? []);
    });
  }

  // merge:true حتى لا يمسح zoneFees عند تعديل قائمة المناطق
  static Future<void> setDeliveryZones(List<String> zones) =>
      _deliveryZonesDoc.set({'zones': zones}, fs.SetOptions(merge: true));

  // ── أجار التوصيل لكل منطقة {zone: fee} ─────────────────
  static Stream<Map<String, double>> getZoneFees() {
    return _deliveryZonesDoc.snapshots().map((doc) {
      if (!doc.exists) return <String, double>{};
      final d = doc.data() as Map<String, dynamic>;
      final raw = d['zoneFees'] as Map<String, dynamic>? ?? {};
      return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
    });
  }

  static Future<void> setZoneFee(String zone, double fee) => _deliveryZonesDoc
      .set({'zoneFees': {zone: fee}}, fs.SetOptions(merge: true));

  // ── Page Pricing (A4 / A5 / B5) ──────────────────────
  static Stream<PagePricing> getPagePricing() {
    return _pricing.snapshots().map((doc) {
      if (!doc.exists) return const PagePricing();
      return PagePricing.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  static Future<void> setPagePricing(PagePricing pricing) =>
      _pricing.set(pricing.toMap(), fs.SetOptions(merge: true));

  // kept for backward compat — returns priceA4
  static Stream<double> getPricePerPage() {
    return getPagePricing().map((p) => p.priceA4);
  }

  static Future<double> fetchPricePerPage() async {
    final doc = await _pricing.get();
    if (!doc.exists) return 100.0;
    final d = doc.data() as Map<String, dynamic>;
    return (d['priceA4'] as num?)?.toDouble() ??
        (d['pricePerPage'] as num?)?.toDouble() ?? 100.0;
  }

  // ── Print Pricing ─────────────────────────────────────
  static Stream<PrintPricing> getPrintPricing() {
    return _printPricing.snapshots().map((doc) {
      if (!doc.exists) return const PrintPricing();
      return PrintPricing.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  // ── Print Job File Upload ─────────────────────────────
  static Future<String> uploadPrintJobFile({
    required String uid,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/pdf',
    void Function(double progress)? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ref = FirebaseStorage.instance
        .ref('print_jobs/$uid/${timestamp}_$safeName');
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }
    await task;
    return await ref.getDownloadURL();
  }

  static Future<String> uploadPrintJobPdf({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) => uploadPrintJobFile(uid: uid, fileName: fileName, bytes: bytes);

  // ── Image Upload ─────────────────────────────────────
  /// يرفع صورة المنتج إلى Firebase Storage ويرجع الـ download URL
  static Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required bool isSupply,
  }) async {
    final folder = isSupply ? 'supply_products' : 'products';
    final ref = FirebaseStorage.instance.ref('$folder/$productId.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  // ── Products (نوطات) ─────────────────────────────────
  static Stream<List<Product>> getProducts(String category, String year, String semester) {
    return _products
        .where('category', isEqualTo: category)
        .where('year', isEqualTo: year)
        .where('semester', isEqualTo: semester)
        .where('available', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map(Product.fromDoc).toList());
  }

  static Stream<List<Product>> getAllProducts() {
    return _products
        .orderBy('category')
        .snapshots()
        .map((s) => s.docs.map(Product.fromDoc).toList());
  }

  static Future<fs.DocumentReference> addProductGetRef(Product p) =>
      _products.add(p.toMap());

  static Future<void> addProduct(Product p) => _products.add(p.toMap());

  static Future<void> updateProduct(Product p) =>
      _products.doc(p.id).update(p.toMap());

  static Future<void> deleteProduct(String id) => _products.doc(id).delete();

  static Future<void> toggleProductAvailability(Product p) =>
      _products.doc(p.id).update({'available': !p.available});

  // ── Lectures (محاضرات) ───────────────────────────────
  static Stream<List<Lecture>> getLectures({
    required String category,
    required String year,
    required String semester,
    required String archiveSection,
  }) {
    return _lectures
        .where('category', isEqualTo: category)
        .where('year', isEqualTo: year)
        .where('semester', isEqualTo: semester)
        .where('archiveSection', isEqualTo: archiveSection)
        .where('available', isEqualTo: true)
        .orderBy('lectureNumber')
        .snapshots()
        .map((s) => s.docs.map(Lecture.fromDoc).toList());
  }

  static Stream<List<Lecture>> getAllLectures() {
    return _lectures
        .orderBy('lectureNumber')
        .snapshots()
        .map((s) => s.docs.map(Lecture.fromDoc).toList());
  }

  static Future<fs.DocumentReference> addLectureGetRef(Lecture l) =>
      _lectures.add(l.toMap());

  static Future<void> updateLecture(Lecture l) =>
      _lectures.doc(l.id).update(l.toMap());

  static Future<void> deleteLecture(String id) =>
      _lectures.doc(id).delete();

  static Future<void> renameSubject({
    required String category,
    required String year,
    required String semester,
    required String oldName,
    required String newName,
  }) async {
    final query = await _lectures
        .where('category', isEqualTo: category)
        .where('year', isEqualTo: year)
        .where('semester', isEqualTo: semester)
        .where('subject', isEqualTo: oldName)
        .get();
    final batch = _db.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'subject': newName});
    }
    await batch.commit();
  }

  static Future<String> uploadLecturePreview({
    required String lectureId,
    required Uint8List bytes,
  }) async {
    final ref = FirebaseStorage.instance
        .ref('lecture_previews/$lectureId/preview.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  // ── Supply Products (مستلزمات) ───────────────────────
  static Stream<List<SupplyProduct>> getSupplyProducts(String category) {
    return _supplyProducts
        .where('category', isEqualTo: category)
        .where('available', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map(SupplyProduct.fromDoc).toList());
  }

  static Stream<List<SupplyProduct>> getAllSupplyProducts() {
    return _supplyProducts
        .orderBy('category')
        .snapshots()
        .map((s) => s.docs.map(SupplyProduct.fromDoc).toList());
  }

  static Future<fs.DocumentReference> addSupplyProductGetRef(SupplyProduct p) =>
      _supplyProducts.add(p.toMap());

  static Future<void> addSupplyProduct(SupplyProduct p) =>
      _supplyProducts.add(p.toMap());

  static Future<void> updateSupplyProduct(SupplyProduct p) =>
      _supplyProducts.doc(p.id).update(p.toMap());

  static Future<void> deleteSupplyProduct(String id) =>
      _supplyProducts.doc(id).delete();

  static Future<void> toggleSupplyAvailability(SupplyProduct p) =>
      _supplyProducts.doc(p.id).update({'available': !p.available});

  // ── Orders ───────────────────────────────────────────────
  // ملاحظة: إنشاء الطلبات يتم عبر Cloud Function 'placeOrder' للتحقق
  // من الأسعار وكود الخصم على الخادم. لا تُنشأ الطلبات مباشرة من العميل.

  /// طلبات المستخدم الحالي (تستخدم userId من Firebase Auth)
  static Stream<List<Order>> getOrdersForUser(String userId) {
    return _orders
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) {
          final list = s.docs.map(Order.fromDoc).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// متروكة للتوافق — لا تستخدم بعد قواعد الأمان الجديدة
  @Deprecated('Use getOrdersForUser with FirebaseAuth uid')
  static Stream<List<Order>> getOrdersForPhone(String phone) {
    return _orders
        .where('phone', isEqualTo: phone)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Order.fromDoc).toList());
  }

  /// جميع الطلبات — للأدمن فقط
  static Stream<List<Order>> getAllOrders() {
    return _orders
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Order.fromDoc).toList());
  }

  static Future<void> updateOrderStatus(String orderId, String status) =>
      _orders.doc(orderId).update({'status': status});

  static Future<void> assignOrderAgent(String orderId, String agentName) =>
      _orders.doc(orderId).update({'assignedAgent': agentName});

  static Future<void> submitOrderRating({
    required String orderId,
    required int rating,
    required String feedback,
  }) =>
      _orders.doc(orderId).update({
        'rating': rating,
        'ratingFeedback': feedback,
      });

  // ── Delivery Agents ──────────────────────────────────────
  static fs.DocumentReference get _agentsDoc =>
      _db.collection('settings').doc('agents');

  static Stream<List<String>> getDeliveryAgents() {
    return _agentsDoc.snapshots().map((doc) {
      if (!doc.exists) return <String>[];
      final d = doc.data() as Map<String, dynamic>;
      return List<String>.from(d['names'] ?? []);
    });
  }

  static Future<void> setDeliveryAgents(List<String> names) =>
      _agentsDoc.set({'names': names}, fs.SetOptions(merge: true));

  // ── Promo Codes ──────────────────────────────────────────
  static fs.CollectionReference get _promoCodes =>
      _db.collection('promo_codes');

  static Stream<List<PromoCode>> getAllPromoCodes() {
    return _promoCodes
        .orderBy('code')
        .snapshots()
        .map((s) => s.docs.map(PromoCode.fromDoc).toList());
  }

  // التحقق عبر Cloud Function — العميل لا يقرأ مجموعة promo_codes مباشرةً
  // (القاعدة تمنعه)، فلا يمكن حصاد كل الأكواد. الدالة تفحص كوداً واحداً فقط.
  static Future<PromoCode?> validatePromoCode(String code) async {
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('validatePromo')
          .call<Map<String, dynamic>>({'code': code});
      final data = res.data;
      if (data['valid'] != true) return null;
      return PromoCode(
        code: code.toUpperCase(),
        discount: (data['discount'] as num?)?.toDouble() ?? 0,
        type: data['type'] as String? ?? 'percent',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> addPromoCode(PromoCode p) => _promoCodes.add({
        ...p.toMap(),
        'createdAt': fs.FieldValue.serverTimestamp(),
      });

  static Future<void> updatePromoCode(PromoCode p) =>
      _promoCodes.doc(p.id).update(p.toMap());

  static Future<void> deletePromoCode(String id) =>
      _promoCodes.doc(id).delete();

  static Future<void> togglePromoCode(PromoCode p) =>
      _promoCodes.doc(p.id).update({'active': !p.active});

  // ملاحظة: زيادة عداد الاستخدام تتم داخل Cloud Function 'placeOrder'
  // atomically مع إنشاء الطلب، لمنع التلاعب من العميل.

  // ── Delivery Settings ────────────────────────────────────
  static fs.DocumentReference get _delivery =>
      _db.collection('settings').doc('delivery');

  static Stream<DeliverySettings> getDeliverySettings() {
    return _delivery.snapshots().map((doc) {
      if (!doc.exists) return const DeliverySettings();
      return DeliverySettings.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  static Future<DeliverySettings> fetchDeliverySettings() async {
    final doc = await _delivery.get();
    if (!doc.exists) return const DeliverySettings();
    return DeliverySettings.fromMap(doc.data() as Map<String, dynamic>);
  }

  static Future<void> setDeliverySettings(DeliverySettings s) =>
      _delivery.set(s.toMap());

  static Future<void> setActiveBranch(int index) =>
      _delivery.set({'activeBranch': index}, fs.SetOptions(merge: true));

  // ── Ads (لوحة الإعلانات) ─────────────────────────────────
  static fs.CollectionReference get _ads => _db.collection('ads');

  static Stream<List<AdBanner>> getAllAds() {
    return _ads
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.map(AdBanner.fromDoc).toList());
  }

  static Stream<List<AdBanner>> getActiveAds() {
    return _ads
        .where('active', isEqualTo: true)
        .snapshots()
        .map((s) {
          final list = s.docs.map(AdBanner.fromDoc).toList();
          list.sort((a, b) => a.order.compareTo(b.order));
          return list;
        });
  }

  static Future<fs.DocumentReference> addAd(AdBanner ad) => _ads.add(ad.toMap());

  static Future<void> updateAd(AdBanner ad) =>
      _ads.doc(ad.id).update(ad.toMap());

  static Future<void> deleteAd(String id) => _ads.doc(id).delete();

  static Future<void> toggleAdActive(AdBanner ad) =>
      _ads.doc(ad.id).update({'active': !ad.active});

  static Future<void> updateAdOrder(String id, int order) =>
      _ads.doc(id).update({'order': order});

  // ── Lecture Drafts ───────────────────────────────────────
  static fs.CollectionReference get _drafts =>
      _db.collection('lecture_drafts');

  static Stream<List<LectureDraft>> getDrafts() {
    return _drafts
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(LectureDraft.fromDoc).toList());
  }

  static Future<fs.DocumentReference> addDraftGetRef(LectureDraft d) =>
      _drafts.add(d.toMap());

  static Future<String> uploadDraftPreview({
    required String draftId,
    required Uint8List bytes,
  }) async {
    final ref = FirebaseStorage.instance
        .ref('draft_previews/$draftId/preview.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  static Future<void> publishDraft(String draftId, Lecture lecture) async {
    await _lectures.add(lecture.toMap());
    await _drafts.doc(draftId).delete();
  }

  static Future<void> deleteDraft(String draftId) =>
      _drafts.doc(draftId).delete();

  // ── Customer Verification ────────────────────────────────
  static fs.CollectionReference get _customers =>
      _db.collection('customers');

  static Stream<Map<String, dynamic>?> getCustomerStatus(String phone) =>
      _customers.doc(phone).snapshots().map(
        (doc) => doc.exists ? doc.data() as Map<String, dynamic> : null,
      );

  static Future<void> verifyCustomer(String phone, String name) =>
      _customers.doc(phone).set({
        'verifiedAt': fs.FieldValue.serverTimestamp(),
        'name': name,
      }, fs.SetOptions(merge: true));

  static Future<void> banPhone(String phone) =>
      _customers.doc(phone).set({
        'bannedAt': fs.FieldValue.serverTimestamp(),
      }, fs.SetOptions(merge: true));

  static Future<void> unbanPhone(String phone) =>
      _customers.doc(phone).update({
        'bannedAt': fs.FieldValue.delete(),
      });

  /// يرفع صورة الإعلان إلى Firebase Storage ويرجع الـ download URL
  static Future<String> uploadAdImage({
    required String adId,
    required Uint8List bytes,
  }) async {
    final ref = FirebaseStorage.instance.ref('ads/$adId.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  // ── تسجيل الدخول عبر تيليجرام ────────────────────────────
  // ينشئ جلسة على الخادم ويرجع معرّفها + اسم البوت لبناء الرابط.
  static Future<({String sessionId, String botUsername})>
      startTelegramLogin({
    required String name,
    required String phone,
    required String specialty,
  }) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable('startTelegramLogin')
        .call<Map<String, dynamic>>({
      'name': name,
      'phone': phone,
      'specialty': specialty,
    });
    final data = res.data;
    return (
      sessionId: data['sessionId'] as String,
      botUsername: data['botUsername'] as String,
    );
  }

  // يتابع حالة الجلسة لحظياً (pending → verified → claimed)
  static Stream<String> telegramSessionStatus(String sessionId) {
    return _db
        .collection('telegram_sessions')
        .doc(sessionId)
        .snapshots()
        .map((s) => (s.data()?['status'] as String?) ?? 'pending');
  }

  // بعد التحقق: يطالب بالجلسة ويحصل على custom token + بيانات الطالب
  static Future<({String token, String name, String phone, String specialty})>
      claimTelegramSession(String sessionId) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable('claimTelegramSession')
        .call<Map<String, dynamic>>({'sessionId': sessionId});
    final data = res.data;
    return (
      token: data['token'] as String,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      specialty: data['specialty'] as String? ?? '',
    );
  }
}
