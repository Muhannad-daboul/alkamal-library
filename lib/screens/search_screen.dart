import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../data.dart';
import '../main.dart';
import '../services/firestore_service.dart';
import '../widgets/animated_empty_state.dart';
import '../widgets/app_drawer.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String _typeFilter = 'all'; // 'all' | 'notes' | 'supplies'
  String? _yearFilter;
  String? _semesterFilter;

  static const _years = [
    'السنة التحضيرية',
    'السنة الثانية',
    'السنة الثالثة',
    'السنة الرابعة',
    'السنة الخامسة',
  ];
  static const _semesters = ['الفصل الأول', 'الفصل الثاني'];

  bool get _hasActiveFilter =>
      _typeFilter != 'all' || _yearFilter != null || _semesterFilter != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSupplies = _typeFilter != 'notes';
    final showNotes    = _typeFilter != 'supplies';

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث'),
        automaticallyImplyLeading: false,
        leading: const MenuButton(),

        actions: const [LogoAction()],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // ── حقل البحث ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن نوطة أو مستلزم...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),

          // ── شريط الفلاتر ────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                // نوع المنتج
                _TypeChip(label: 'الكل',        value: 'all',      current: _typeFilter, onTap: (v) => setState(() { _typeFilter = v; if (v == 'supplies') { _yearFilter = null; _semesterFilter = null; } })),
                _TypeChip(label: 'نوطات',       value: 'notes',    current: _typeFilter, onTap: (v) => setState(() => _typeFilter = v)),
                _TypeChip(label: 'مستلزمات',   value: 'supplies', current: _typeFilter, onTap: (v) => setState(() { _typeFilter = v; _yearFilter = null; _semesterFilter = null; })),

                if (showNotes) ...[
                  const SizedBox(width: 8),
                  const VerticalDivider(width: 1, thickness: 1, indent: 4, endIndent: 4),
                  const SizedBox(width: 8),
                  // السنة
                  DropdownButton<String?>(
                    value: _yearFilter,
                    hint: Text('السنة', style: GoogleFonts.tajawal(fontSize: 13)),
                    style: GoogleFonts.tajawal(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(10),
                    items: [
                      DropdownMenuItem(value: null, child: Text('كل السنوات', style: GoogleFonts.tajawal())),
                      ..._years.map((y) => DropdownMenuItem(value: y, child: Text(y, style: GoogleFonts.tajawal()))),
                    ],
                    onChanged: (v) => setState(() { _yearFilter = v; _semesterFilter = null; }),
                  ),
                  // الفصل (يظهر فقط إذا اختار سنة)
                  if (_yearFilter != null) ...[
                    const SizedBox(width: 6),
                    ..._semesters.map((s) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                        label: Text(s == 'الفصل الأول' ? 'ف١' : 'ف٢',
                            style: GoogleFonts.tajawal(fontSize: 12)),
                        selected: _semesterFilter == s,
                        onSelected: (_) => setState(() =>
                            _semesterFilter = _semesterFilter == s ? null : s),
                      ),
                    )),
                  ],
                ],
              ],
            ),
          ),

          // ── النتائج ─────────────────────────────────────────
          Expanded(
            child: (!_query.isNotEmpty && !_hasActiveFilter)
                ? Center(
                    child: Text(
                      'ابحث أو اختر فلتراً...',
                      style: GoogleFonts.tajawal(
                          color: context.cFaint, fontSize: 16),
                    ),
                  )
                : StreamBuilder<List<Product>>(
                    stream: FirestoreService.getAllProducts(),
                    builder: (context, prodSnap) {
                      return StreamBuilder<List<SupplyProduct>>(
                        stream: FirestoreService.getAllSupplyProducts(),
                        builder: (context, supSnap) {
                          if (prodSnap.connectionState == ConnectionState.waiting ||
                              supSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final q = _query;
                          final products = !showNotes ? <Product>[] : (prodSnap.data ?? [])
                              .where((p) =>
                                  p.available &&
                                  (q.isEmpty || '${p.title} ${p.description} ${p.category}'.toLowerCase().contains(q)) &&
                                  (_yearFilter == null || p.year == _yearFilter) &&
                                  (_semesterFilter == null || p.semester == _semesterFilter))
                              .toList();

                          final supplies = !showSupplies ? <SupplyProduct>[] : (supSnap.data ?? [])
                              .where((s) =>
                                  s.available &&
                                  (q.isEmpty || '${s.title} ${s.description} ${s.category}'.toLowerCase().contains(q)))
                              .toList();

                          if (products.isEmpty && supplies.isEmpty) {
                            return AnimatedEmptyState(
                              icon: Icons.search_off_rounded,
                              title: q.isNotEmpty
                                  ? 'لا توجد نتائج لـ "$_query"'
                                  : 'لا توجد نتائج لهذه الفلاتر',
                              subtitle: q.isNotEmpty
                                  ? 'جرّب كلمة أخرى أو تصفّح الفئات'
                                  : null,
                            );
                          }

                          return StreamBuilder<PagePricing>(
                            stream: FirestoreService.getPagePricing(),
                            builder: (context, priceSnap) {
                              final pricing = priceSnap.data ?? const PagePricing();
                              return ListView(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                children: [
                                  if (products.isNotEmpty) ...[
                                    _SectionHeader(title: 'نوطات (${products.length})'),
                                    ...products.asMap().entries.map((e) =>
                                        _ProductResultCard(product: e.value, pricing: pricing)
                                            .animate(delay: (e.key * 60).ms)
                                            .fadeIn(duration: 350.ms)
                                            .slideY(begin: 0.2, end: 0, duration: 350.ms, curve: Curves.easeOut)),
                                  ],
                                  if (supplies.isNotEmpty) ...[
                                    _SectionHeader(title: 'مستلزمات (${supplies.length})'),
                                    ...supplies.asMap().entries.map((e) =>
                                        _SupplyResultCard(supply: e.value)
                                            .animate(delay: ((products.length + e.key) * 60).ms)
                                            .fadeIn(duration: 350.ms)
                                            .slideY(begin: 0.2, end: 0, duration: 350.ms, curve: Curves.easeOut)),
                                  ],
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.tajawal(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ProductResultCard extends StatelessWidget {
  final Product product;
  final PagePricing pricing;
  const _ProductResultCard(
      {required this.product, required this.pricing});

  double get _price =>
      product.customPrice ?? (product.pages * pricing.priceForSize(product.pageSize));

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            productImage(asset: product.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title,
                      style: GoogleFonts.tajawal(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    '${product.category} • ${product.year}',
                    style: GoogleFonts.tajawal(
                        fontSize: 12, color: context.cFaint),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_price.toStringAsFixed(0)} ل.س',
                    style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primary),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => _addToCart(context),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(64, 34),
                      padding: EdgeInsets.zero),
                  child: Text('إضافة',
                      style: GoogleFonts.tajawal(fontSize: 13)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                          product: product, computedPrice: _price),
                    ),
                  ),
                  child: Text('تفاصيل',
                      style: GoogleFonts.tajawal(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final list = List<CartItem>.from(cartNotifier.value);
    final idx =
        list.indexWhere((i) => i.id == product.id && !i.isSupply);
    if (idx >= 0) {
      list[idx].quantity++;
    } else {
      list.add(CartItem(
        id: product.id,
        title: product.title,
        price: _price,
        isSupply: false,
        imageUrl: product.imageUrl,
      ));
    }
    cartNotifier.value = list;
  }
}

class _SupplyResultCard extends StatelessWidget {
  final SupplyProduct supply;
  const _SupplyResultCard({required this.supply});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            productImage(asset: supply.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supply.title,
                      style: GoogleFonts.tajawal(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(supply.category,
                      style: GoogleFonts.tajawal(
                          fontSize: 12, color: context.cFaint)),
                  const SizedBox(height: 4),
                  Text(
                    '${supply.price.toStringAsFixed(0)} ل.س',
                    style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primary),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _addToCart(context),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, 34),
                  padding: EdgeInsets.zero),
              child:
                  Text('إضافة', style: GoogleFonts.tajawal(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final list = List<CartItem>.from(cartNotifier.value);
    final idx =
        list.indexWhere((i) => i.id == supply.id && i.isSupply);
    if (idx >= 0) {
      list[idx].quantity++;
    } else {
      list.add(CartItem(
        id: supply.id,
        title: supply.title,
        price: supply.price,
        isSupply: true,
        imageUrl: supply.imageUrl,
      ));
    }
    cartNotifier.value = list;
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onTap;

  const _TypeChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.tajawal(fontSize: 13)),
        selected: current == value,
        onSelected: (_) => onTap(value),
      ),
    );
  }
}
