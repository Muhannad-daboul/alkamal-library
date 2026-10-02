import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../data.dart';
import '../main.dart';
import '../widgets/app_drawer.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final double computedPrice;
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.computedPrice,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00827E);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.title),
        leading: const MenuButton(),
        actions: const [LogoAction()],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // صورة المنتج
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 200,
                child: product.imageUrl.isNotEmpty
                    ? (product.imageUrl.startsWith('http')
                          ? Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, e, _) => _placeholder(),
                            )
                          : Image.asset(
                              'assets/images/${product.imageUrl}',
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, e, _) => _placeholder(),
                            ))
                    : _placeholder(),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              product.title,
              style: GoogleFonts.tajawal(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${product.category} — ${product.year}',
              style: GoogleFonts.tajawal(fontSize: 14.0, color: context.cFaint),
            ),
            const SizedBox(height: 12),
            Text(
              product.description,
              style: GoogleFonts.tajawal(
                fontSize: 16.0,
                color: context.cText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // تفاصيل السعر
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _priceRow(context, 'عدد الصفحات', '${product.pages} صفحة'),
                  const Divider(height: 20),
                  _priceRow(
                    context,
                    'السعر الإجمالي',
                    '${computedPrice.toStringAsFixed(0)} ل.س',
                    bold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _addToCart(context),
              icon: const Icon(Icons.add_shopping_cart),
              label: Text('أضف إلى السلة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0x1F00827E),
    child: Center(
      child: Icon(Icons.menu_book, color: Color(0xFF00827E), size: 80),
    ),
  );

  Widget _priceRow(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: bold ? 17 : 14,
            color: bold ? context.cText : context.cMuted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.tajawal(
            fontSize: bold ? 20 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: bold ? const Color(0xFF00827E) : context.cText,
          ),
        ),
      ],
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
