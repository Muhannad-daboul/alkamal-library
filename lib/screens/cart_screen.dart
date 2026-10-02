import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../main.dart';
import '../widgets/animated_empty_state.dart';
import '../widgets/app_drawer.dart';
import 'checkout_screen.dart';
import 'print_job_preview_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('السلة'),
        automaticallyImplyLeading: false,
        leading: const MenuButton(),
        actions: [
          ValueListenableBuilder<List<CartItem>>(
            valueListenable: cartNotifier,
            builder: (context2, items, _) => items.isEmpty
                ? const SizedBox()
                : TextButton.icon(
                    onPressed: () => _confirmClear(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    label: Text(
                      'تفريغ',
                      style: GoogleFonts.tajawal(color: Colors.white),
                    ),
                  ),
          ),
          const LogoAction(),
        ],
      ),
      drawer: const AppDrawer(),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: cartNotifier,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return const AnimatedEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'السلة فارغة',
              subtitle: 'أضف منتجات من قائمة النوطات أو المستلزمات',
            );
          }

          final total = items.fold<double>(
            0,
            (sum, i) => sum + i.price * i.quantity,
          );

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (context3, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _CartItemCard(item: items[i]),
                ),
              ),
              _OrderSummary(total: total),
            ],
          );
        },
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تفريغ السلة'),
        content: Text('هل تريد إزالة كل المنتجات من السلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              cartNotifier.value = [];
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
            child: Text('تفريغ',
                style: GoogleFonts.tajawal(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00827E);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // صورة المنتج
            item.isPrintJob
                ? GestureDetector(
                    onTap: () => _openPdfPreview(context),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf, color: primary, size: 32),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.visibility, color: Colors.white, size: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : item.isLecture
                    ? Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.menu_book, color: primary, size: 32),
                      )
                    : productImage(
                        asset: item.imageUrl,
                        size: 64,
                        isSupply: item.isSupply,
                        radius: 14,
                      ),
            const SizedBox(width: 14),

            // معلومات المنتج
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (_) {
                    final parts = item.title.split('\n');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parts[0],
                          style: GoogleFonts.tajawal(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (parts.length > 1)
                          Text(
                            parts[1],
                            style: GoogleFonts.tajawal(
                              fontSize: 11.0,
                              color: context.cFaint,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    );
                  }),
                  if (item.isPrintJob && item.printJobNotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.printJobNotes,
                        style: GoogleFonts.tajawal(
                          fontSize: 12.0,
                          color: context.cFaint,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.price.toStringAsFixed(0)} ل.س / وحدة',
                    style: GoogleFonts.tajawal(
                      fontSize: 13.0,
                      color: context.cMuted,
                    ),
                  ),
                  if (item.bindingType != null)
                    Text(
                      item.bindingType == 'تسليك'
                          ? '+ تسليك'
                          : '+ خرز',
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.tajawal(
                        fontSize: 12.0,
                        color: item.bindingType == 'تسليك'
                            ? Colors.orange.shade700
                            : Colors.teal.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            // التحكم بالكمية + حذف
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyBtn(icon: Icons.remove, onTap: () => _decrement()),
                    Container(
                      width: 36,
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}',
                        style: GoogleFonts.tajawal(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _qtyBtn(
                      icon: Icons.add,
                      color: primary,
                      onTap: () => _increment(),
                    ),
                  ],
                ),
                Text(
                  '${(item.price * item.quantity).toStringAsFixed(0)} ل.س',
                  style: GoogleFonts.tajawal(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.red),
              onPressed: _remove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: (color ?? Colors.grey).withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color ?? Colors.grey.shade500),
      ),
    );
  }

  void _increment() {
    final list = List<CartItem>.from(cartNotifier.value);
    final idx = list.indexWhere(
      (i) =>
          i.id == item.id &&
          i.isSupply == item.isSupply &&
          i.isLecture == item.isLecture &&
          i.isPrintJob == item.isPrintJob,
    );
    if (idx >= 0) {
      list[idx].quantity++;
      cartNotifier.value = list;
    }
  }

  void _decrement() {
    final list = List<CartItem>.from(cartNotifier.value);
    final idx = list.indexWhere(
      (i) =>
          i.id == item.id &&
          i.isSupply == item.isSupply &&
          i.isLecture == item.isLecture &&
          i.isPrintJob == item.isPrintJob,
    );
    if (idx >= 0) {
      if (list[idx].quantity > 1) {
        list[idx].quantity--;
      } else {
        list.removeAt(idx);
      }
      cartNotifier.value = list;
    }
  }

  void _remove() {
    final list = List<CartItem>.from(cartNotifier.value);
    list.removeWhere(
      (i) =>
          i.id == item.id &&
          i.isSupply == item.isSupply &&
          i.isLecture == item.isLecture &&
          i.isPrintJob == item.isPrintJob,
    );
    cartNotifier.value = list;
  }

  void _openPdfPreview(BuildContext context) {
    final urls = item.printJobStoragePath
        .split(',')
        .where((u) => u.isNotEmpty)
        .toList();
    if (urls.isEmpty) return;

    if (urls.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrintJobPreviewScreen(
            fileUrl: urls.first,
            fileName: item.title.split('\n').first,
          ),
        ),
      );
      return;
    }

    // Multiple files — show chooser
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'اختر ملفاً للمعاينة',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ...urls.asMap().entries.map((e) {
                final idx = e.key + 1;
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF00827E)),
                  title: Text(
                    'ملف $idx',
                    style: GoogleFonts.tajawal(),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrintJobPreviewScreen(
                          fileUrl: e.value,
                          fileName: 'ملف $idx',
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _OrderSummary extends StatelessWidget {
  final double total;
  const _OrderSummary({required this.total});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00827E);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الإجمالي',
                style: GoogleFonts.tajawal(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
              Text(
                '${total.toStringAsFixed(0)} ل.س',
                style: GoogleFonts.tajawal(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(items: cartNotifier.value),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                'إتمام الطلب',
                style: GoogleFonts.tajawal(fontSize: 16.0),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
