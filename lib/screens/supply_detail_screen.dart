import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../data.dart';
import '../main.dart';
import '../services/firestore_service.dart';
import '../widgets/app_drawer.dart';

class SupplyDetailScreen extends StatelessWidget {
  final SupplyCategory supply;
  const SupplyDetailScreen({super.key, required this.supply});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(supply.title),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: const [MenuButton(), LogoAction()],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<List<SupplyProduct>>(
        stream: FirestoreService.getSupplyProducts(supply.title),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('خطأ: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: supply.color.withAlpha(40),
                    child: Icon(supply.icon, color: supply.color, size: 48),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    supply.title,
                    style: GoogleFonts.tajawal(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لا توجد مستلزمات لهذه الفئة حتى الآن',
                    style: GoogleFonts.tajawal(
                      fontSize: 15.0,
                      color: context.cFaint,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: items.length,
            separatorBuilder: (context, i) => const SizedBox(height: 14),
            itemBuilder: (context, i) => _SupplyProductCard(product: items[i]),
          );
        },
      ),
    );
  }
}

class _SupplyProductCard extends StatelessWidget {
  final SupplyProduct product;
  const _SupplyProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00827E);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            productImage(asset: product.imageUrl, isSupply: true),
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
                  Text(
                    '${product.price.toStringAsFixed(0)} ل.س',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.0,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _addToCart(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(70, 36),
                padding: EdgeInsets.zero,
              ),
              child: Text('إضافة', style: GoogleFonts.tajawal(fontSize: 13.0)),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final list = List<CartItem>.from(cartNotifier.value);
    final idx = list.indexWhere((i) => i.id == product.id && i.isSupply);
    if (idx >= 0) {
      list[idx].quantity++;
    } else {
      list.add(
        CartItem(
          id: product.id,
          title: product.title,
          price: product.price,
          isSupply: true,
          imageUrl: product.imageUrl,
        ),
      );
    }
    cartNotifier.value = list;
    Navigator.of(context).popUntil((route) => route.isFirst);
    tabIndexNotifier.value = 1;
  }
}
