import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../data.dart';
import '../main.dart';
import '../services/firestore_service.dart';
import '../widgets/app_drawer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'product_detail_screen.dart';

class ProductsListScreen extends StatefulWidget {
  final CategoryItem category;
  final String year;
  final String semester;

  const ProductsListScreen({
    super.key,
    required this.category,
    required this.year,
    required this.semester,
  });

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  late String _semester;

  @override
  void initState() {
    super.initState();
    _semester = widget.semester;
  }

  void _showSemesterSheet() {
    const primary = Color(0xFF00827E);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'اختر الفصل الدراسي',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SemesterTile(
                    label: 'الفصل الأول',
                    icon: Icons.looks_one_outlined,
                    color: primary,
                    selected: _semester == 'الفصل الأول',
                    onTap: () {
                      setState(() => _semester = 'الفصل الأول');
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SemesterTile(
                    label: 'الفصل الثاني',
                    icon: Icons.looks_two_outlined,
                    color: primary,
                    selected: _semester == 'الفصل الثاني',
                    onTap: () {
                      setState(() => _semester = 'الفصل الثاني');
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.title} • ${widget.year}'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton.icon(
            onPressed: _showSemesterSheet,
            icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
            label: Text(
              _semester,
              style: GoogleFonts.tajawal(color: Colors.white, fontSize: 13.0),
            ),
          ),
          const MenuButton(),
          const LogoAction(),
        ],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<PagePricing>(
        stream: FirestoreService.getPagePricing(),
        builder: (context, priceSnap) {
          final pricing = priceSnap.data ?? const PagePricing();
          return StreamBuilder<List<Product>>(
            stream: FirestoreService.getProducts(
              widget.category.title,
              widget.year,
              _semester,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('خطأ في التحميل: ${snap.error}'));
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'لا توجد نوطات لهذه السنة حتى الآن\nتحقق لاحقاً!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        fontSize: 18.0,
                        color: context.cFaint,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                itemCount: items.length,
                separatorBuilder: (context, i) => const SizedBox(height: 14),
                itemBuilder: (context, i) =>
                    _ProductCard(product: items[i], pricing: pricing)
                        .animate(delay: (i * 60).ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 350.ms,
                          curve: Curves.easeOut,
                        ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final PagePricing pricing;
  const _ProductCard({required this.product, required this.pricing});

  double get computedPrice =>
      product.customPrice ??
      (product.pages * pricing.priceForSize(product.pageSize));

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00827E);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            productImage(asset: product.imageUrl),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: GoogleFonts.tajawal(
                      fontSize: 17.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    style: GoogleFonts.tajawal(
                      color: context.cMuted,
                      fontSize: 13.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${computedPrice.toStringAsFixed(0)} ل.س',
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.0,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${product.pages} صفحة',
                        style: GoogleFonts.tajawal(
                          fontSize: 12.0,
                          color: context.cFaint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Column(
              children: [
                ElevatedButton(
                  onPressed: () => _addToCart(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(70, 36),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'إضافة',
                    style: GoogleFonts.tajawal(fontSize: 13.0),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        product: product,
                        computedPrice: computedPrice,
                      ),
                    ),
                  ),
                  child: Text(
                    'تفاصيل',
                    style: GoogleFonts.tajawal(fontSize: 13.0),
                  ),
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
    final idx = list.indexWhere((i) => i.id == product.id && !i.isSupply);
    if (idx >= 0) {
      list[idx].quantity++;
    } else {
      list.add(
        CartItem(
          id: product.id,
          title: product.title,
          price: computedPrice,
          isSupply: false,
          imageUrl: product.imageUrl,
        ),
      );
    }
    cartNotifier.value = list;
    Navigator.of(context).popUntil((route) => route.isFirst);
    tabIndexNotifier.value = 1;
  }
}

class _SemesterTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SemesterTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? color : color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.tajawal(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w700,
                fontSize: 15.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
