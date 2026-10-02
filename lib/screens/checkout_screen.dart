import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../main.dart';
import '../services/firestore_service.dart';
import '../widgets/app_drawer.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  const CheckoutScreen({super.key, required this.items});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _voucherCtrl = TextEditingController();

  bool _saving = false;
  bool _showInstructionsExpanded = false;
  bool _validatingVoucher = false;
  String? _selectedZone;
  String _deliveryMethod = 'delivery'; // 'delivery' | 'pickup'
  String _selectedInstruction = 'اتصل بي عندما تصل';
  String _selectedPayment = 'cash';
  String? _voucherError;
  double _discount = 0;

  static const _instructions = [
    'اتصل بي عندما تصل',
    'اترك الطلب عند الباب',
    'أرسل رسالة عند الوصول',
    'لا تطرق الجرس',
  ];

  static const _paymentMethods = [
    _PaymentMethod('cash', 'نقداً', Icons.payments_outlined),
    _PaymentMethod('cham_bank', 'بنك الشام', Icons.account_balance_outlined),
    _PaymentMethod('syriatel', 'Syriatel Cash', Icons.phone_android_outlined),
  ];


  @override
  void initState() {
    super.initState();
    final profile = userProfileNotifier.value;
    _nameCtrl.text = profile.name;
    _phoneCtrl.text = profile.phone;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _voucherCtrl.dispose();
    super.dispose();
  }

  double get _subtotal =>
      widget.items.fold(0, (sum, i) => sum + i.price * i.quantity);

  double get _total {
    final raw = (_subtotal - _discount).clamp(0, double.infinity);
    return (raw / 100).ceil() * 100.0;
  }

  int get _totalQuantity => widget.items.fold(0, (sum, i) => sum + i.quantity);

  Future<void> _applyVoucher() async {
    final code = _voucherCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _validatingVoucher = true);
    try {
      final promo = await FirestoreService.validatePromoCode(code);
      if (!mounted) return;
      if (promo != null) {
        final disc = promo.type == 'percent'
            ? _subtotal * promo.discount / 100
            : promo.discount;
        setState(() {
          _discount = disc.clamp(0, _subtotal);
          _voucherError = null;
        });
      } else {
        setState(() {
          _voucherError = 'الكود غير صحيح أو منتهي الصلاحية';
          _discount = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _validatingVoucher = false);
    }
  }

  Future<void> _placeOrder() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_deliveryMethod == 'delivery' && _selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار منطقة التوصيل')),
      );
      return;
    }
    if (widget.items.isEmpty) return;

    // التحقق من تسجيل الدخول قبل الإرسال
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جارٍ الاتصال بالخادم... يرجى المحاولة مرة أخرى'),
          duration: Duration(seconds: 3),
        ),
      );
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر الاتصال، تأكد من الإنترنت وأعد المحاولة')),
          );
        }
        return;
      }
    }

    setState(() => _saving = true);
    try {
      // الطلب يُنشأ عبر Cloud Function للتحقق من الأسعار وكود الخصم على الخادم
      final callable =
          FirebaseFunctions.instance.httpsCallable('placeOrder');
      await callable.call<Map<String, dynamic>>({
        'userName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _deliveryMethod == 'pickup' ? '' : _addressCtrl.text.trim(),
        'zone': _deliveryMethod == 'pickup' ? '' : (_selectedZone ?? ''),
        'deliveryMethod': _deliveryMethod,
        'paymentMethod': _selectedPayment,
        'notes': _notesCtrl.text.trim(),
        'deliveryLat': 0,
        'deliveryLng': 0,
        'fcmToken': deviceFcmToken ?? '',
        'promoCode': _voucherCtrl.text.trim().isEmpty
            ? null
            : _voucherCtrl.text.trim(),
        'items': widget.items
            .map((item) => {
                  'id': item.id,
                  'quantity': item.quantity,
                  'isSupply': item.isSupply,
                  'isLecture': item.isLecture,
                  if (item.isPrintJob) ...{
                    'isPrintJob': true,
                    'title': item.title,
                    'printJobStoragePath': item.printJobStoragePath,
                    'printPageCount': item.printPageCount,
                    'printColor': item.printColor,
                    'printSides': item.printSides,
                    'printBinding': item.printBinding,
                    'printCopies': item.printCopies,
                  },
                  if (item.id.startsWith('bundle:')) ...{
                    'title': item.title,
                    'bundleLectureIds': item.bundleLectureIds,
                  },
                  if (item.bindingType != null) 'bindingType': item.bindingType,
                })
            .toList(),
      });
      cartNotifier.value = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلبك بنجاح ✓ ستجد كود الاستلام في صفحة طلباتي بعد قبول الطلب')),
        );
        if (mounted) Navigator.pop(context);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'فشل إرسال الطلب')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إرسال الطلب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00827E);

    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        title: Text('إتمام الطلب'),
        backgroundColor: context.cSurface,
        foregroundColor: context.cText,
        elevation: 0.5,
        leading: const MenuButton(),

        actions: const [LogoAction()],
      ),
      drawer: const AppDrawer(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('طريقة الاستلام'),
              _buildDeliveryMethodCard(primary),
              const SizedBox(height: 16),
              if (_deliveryMethod == 'delivery') ...[
                _sectionLabel('منطقة التوصيل'),
                _buildZonePicker(primary),
                const SizedBox(height: 16),
                if (_selectedZone != null) ...[
                  _sectionLabel('تفاصيل الموقع'),
                  _buildLandmarkField(primary),
                  const SizedBox(height: 16),
                ],
              ],
              if (_deliveryMethod == 'delivery') ...[
                _sectionLabel('تعليمات التوصيل'),
                _buildInstructionsCard(primary),
                const SizedBox(height: 16),
              ],
              _sectionLabel('طريقة الدفع'),
              _buildPaymentRow(primary),
              const SizedBox(height: 16),
              _sectionLabel('كود الخصم'),
              _buildVoucherCard(primary),
              const SizedBox(height: 16),
              _sectionLabel('الفاتورة'),
              _buildInvoiceCard(primary),
            ],
          ),
        ),
      ),
      bottomSheet: _buildBottomBar(primary),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.tajawal(fontSize: 16.0, fontWeight: FontWeight.bold),
    ),
  );

  // ── طريقة الاستلام ─────────────────────────────────────────
  Widget _buildDeliveryMethodCard(Color primary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طريقة الاستلام',
                style: GoogleFonts.tajawal(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                _methodChip(
                  icon: Icons.delivery_dining_outlined,
                  label: 'توصيل للمنزل',
                  selected: _deliveryMethod == 'delivery',
                  primary: primary,
                  onTap: () => setState(() {
                    _deliveryMethod = 'delivery';
                  }),
                ),
                const SizedBox(width: 10),
                _methodChip(
                  icon: Icons.store_outlined,
                  label: 'استلام من المكتبة',
                  selected: _deliveryMethod == 'pickup',
                  primary: primary,
                  onTap: () => setState(() {
                    _deliveryMethod = 'pickup';
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodChip({
    required IconData icon,
    required String label,
    required bool selected,
    required Color primary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primary.withAlpha(20) : context.cFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? primary : context.cFaint, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected ? primary : context.cMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── تفاصيل الموقع (شارع / معلم) ───────────────────────────
  Widget _buildLandmarkField(Color primary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _addressCtrl,
          textDirection: TextDirection.rtl,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'يرجى كتابة اسم الشارع أو معلم قريب'
              : null,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'اسم الشارع أو مكان معروف قريب',
            hintText: 'مثال: جامع الأمويين، شارع بغداد، مقابل مدرسة...',
            prefixIcon: Icon(Icons.place_outlined, color: primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  // ── منطقة التوصيل ─────────────────────────────────────────
  Widget _buildZonePicker(Color primary) {
    return StreamBuilder<List<String>>(
      stream: FirestoreService.getDeliveryZones(),
      builder: (context, snap) {
        final zones = snap.data ?? [];
        if (zones.isEmpty) return const SizedBox.shrink();
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedZone,
              decoration: InputDecoration(
                labelText: 'اختر منطقة التوصيل',
                prefixIcon: Icon(Icons.location_city_outlined, color: primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
              hint: const Text('اختر منطقتك'),
              isExpanded: true,
              items: zones
                  .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedZone = v),
            ),
          ),
        );
      },
    );
  }

  // ── تعليمات التوصيل ────────────────────────────────────────
  Widget _buildInstructionsCard(Color primary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(
              () => _showInstructionsExpanded = !_showInstructionsExpanded,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _instructionChip(
                        _selectedInstruction,
                        primary,
                        selected: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showInstructionsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: context.cFaint,
                  ),
                ],
              ),
            ),
          ),
          if (_showInstructionsExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _instructions.map((inst) {
                  final sel = inst == _selectedInstruction;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedInstruction = inst;
                      _showInstructionsExpanded = false;
                    }),
                    child: _instructionChip(inst, primary, selected: sel),
                  );
                }).toList(),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: _inputDecoration(
                'ملاحظات إضافية (اختياري)',
                Icons.notes_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionChip(
    String label,
    Color primary, {
    required bool selected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? primary : primary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? primary : primary.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.tajawal(
          color: selected ? Colors.white : primary,
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── طريقة الدفع ────────────────────────────────────────────
  Widget _buildPaymentRow(Color primary) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _paymentMethods.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final method = _paymentMethods[i];
          final selected = method.id == _selectedPayment;
          return GestureDetector(
            onTap: () => setState(() => _selectedPayment = method.id),
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                color: selected ? primary.withAlpha(20) : context.cSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? primary : Colors.grey.withAlpha(80),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    method.icon,
                    color: selected ? primary : context.cMuted,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    method.label,
                    style: GoogleFonts.tajawal(
                      fontSize: 12.0,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: selected ? primary : context.cMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── كود الخصم ──────────────────────────────────────────────
  Widget _buildVoucherCard(Color primary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voucherCtrl,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'أدخل كود الخصم',
                      filled: true,
                      fillColor: _voucherError != null
                          ? Colors.red.withAlpha(15)
                          : Colors.grey.withAlpha(20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _voucherError != null
                              ? Colors.red.withAlpha(120)
                              : Colors.transparent,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _voucherError != null ? Colors.red : primary,
                        ),
                      ),
                      suffixIcon: _voucherCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _voucherCtrl.clear();
                                setState(() {
                                  _voucherError = null;
                                  _discount = 0;
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _validatingVoucher ? null : _applyVoucher,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(80, 52),
                    ),
                    child: _validatingVoucher
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('تطبيق'),
                  ),
                ),
              ],
            ),
            if (_voucherError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _voucherError!,
                        style: GoogleFonts.tajawal(
                          color: Colors.red,
                          fontSize: 13.0,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _voucherCtrl.clear();
                        setState(() {
                          _voucherError = null;
                          _discount = 0;
                        });
                      },
                      icon: const Icon(
                        Icons.refresh,
                        size: 14,
                        color: Colors.red,
                      ),
                      label: Text(
                        'إعادة',
                        style: GoogleFonts.tajawal(color: Colors.red, fontSize: 13.0),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_discount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تم تطبيق خصم ${_discount.toStringAsFixed(0)} ل.س',
                      style: GoogleFonts.tajawal(
                        color: Colors.green,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── الفاتورة ───────────────────────────────────────────────
  Widget _buildInvoiceCard(Color primary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...widget.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    productImage(
                      asset: item.imageUrl,
                      size: 46,
                      isSupply: item.isSupply,
                      radius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.tajawal(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item.quantity} × ${item.price.toStringAsFixed(0)} ل.س',
                            style: GoogleFonts.tajawal(
                              fontSize: 12.0,
                              color: context.cFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(item.price * item.quantity).toStringAsFixed(0)} ل.س',
                      style: GoogleFonts.tajawal(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            _invoiceRow(
              'المجموع الفرعي',
              '${_subtotal.toStringAsFixed(0)} ل.س',
            ),
            if (_discount > 0) ...[
              const SizedBox(height: 8),
              _invoiceRow(
                'الخصم',
                '- ${_discount.toStringAsFixed(0)} ل.س',
                color: Colors.green,
              ),
            ],
            const SizedBox(height: 8),
            _invoiceRow(
              'رسوم التوصيل',
              _deliveryMethod == 'pickup' ? 'لا يوجد' : 'يُحدد عند التوصيل',
              color: _deliveryMethod == 'pickup' ? Colors.green : null,
            ),
            const SizedBox(height: 8),
            _invoiceRow(
              'الإجمالي',
              '${_total.toStringAsFixed(0)} ل.س',
              bold: true,
              color: primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.tajawal(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── زر تأكيد الطلب (bottomSheet) ──────────────────────────
  Widget _buildBottomBar(Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      decoration: BoxDecoration(
        color: context.cSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_totalQuantity',
              style: GoogleFonts.tajawal(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'تأكيد الطلب',
                        style: GoogleFonts.tajawal(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF00827E)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _PaymentMethod {
  final String id, label;
  final IconData icon;
  const _PaymentMethod(this.id, this.label, this.icon);
}


