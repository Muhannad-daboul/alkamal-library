import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../data.dart';
import '../main.dart';
import '../services/firestore_service.dart';
import '../services/orders_watcher.dart';
import '../widgets/animated_empty_state.dart';
import '../widgets/app_drawer.dart';

Future<void> _showRatingDialog(BuildContext context, Order order) async {
  int selectedStars = 0;
  final feedbackCtrl = TextEditingController();
  bool submitting = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'قيّم تجربتك',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'كيف كانت تجربتك مع هذا الطلب؟',
                style: GoogleFonts.tajawal(color: context.cMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: selectedStars == 0
                    ? const SizedBox(height: 48)
                    : Text(
                        ['😡', '😕', '😐', '😊', '🤩'][selectedStars - 1],
                        key: ValueKey(selectedStars),
                        style: const TextStyle(fontSize: 40),
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setStateDialog(() => selectedStars = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        star <= selectedStars ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              if (selectedStars > 0 && selectedStars <= 3) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'أخبرنا ما الذي يمكن تحسينه...',
                    hintStyle: GoogleFonts.tajawal(color: context.cFaint, fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00827E)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: Text('لاحقاً', style: GoogleFonts.tajawal(color: context.cFaint)),
            ),
            ElevatedButton(
              onPressed: (selectedStars == 0 || submitting)
                  ? null
                  : () async {
                      setStateDialog(() => submitting = true);
                      await FirestoreService.submitOrderRating(
                        orderId: order.id,
                        rating: selectedStars,
                        feedback: feedbackCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00827E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('إرسال',
                      style: GoogleFonts.tajawal(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
  feedbackCtrl.dispose();
}

String _formatDateTime(DateTime dt) {
  const months = [
    '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${months[dt.month]} ${dt.year} — $h:$m';
}

Color _statusColor(String status) {
  switch (status) {
    case 'تم القبول':  return const Color(0xFF00827E);
    case 'في الطريق':  return Colors.blue;
    case 'تم التسليم': return Colors.green;
    default:           return Colors.orange;
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        automaticallyImplyLeading: false,
        leading: const MenuButton(),
        actions: const [LogoAction()],
      ),
      drawer: const AppDrawer(),
      body: ValueListenableBuilder<UserProfile>(
        valueListenable: userProfileNotifier,
        builder: (context, profile, _) {
          // يستعلم برقم الهاتف — أكثر موثوقية من UID (لا يتأثر بإعادة التثبيت)
          final phone = profile.phone.trim();
          if (phone.isEmpty) {
            return Center(
              child: Text(
                'يرجى إكمال بيانات ملفك الشخصي أولاً',
                style: GoogleFonts.tajawal(fontSize: 16, color: context.cFaint),
              ),
            );
          }

          // التحقق من تسجيل الدخول المجهول
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            return Center(
              child: Text(
                'جارٍ الاتصال... يرجى الانتظار أو إعادة تشغيل التطبيق',
                style: GoogleFonts.tajawal(fontSize: 15, color: context.cFaint),
                textAlign: TextAlign.center,
              ),
            );
          }

          return StreamBuilder<List<Order>>(
            // ignore: deprecated_member_use
            stream: FirestoreService.getOrdersForPhone(phone),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'تعذّر تحميل الطلبات',
                        style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}',
                        style: GoogleFonts.tajawal(fontSize: 12, color: context.cFaint),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              final orders = snapshot.data ?? [];
              // علِّم جميع الحالات الحالية كمشاهَدة لتصفير شارة الإشعارات
              if (orders.isNotEmpty) {
                OrdersWatcher.markAllSeen(orders);
              }
              if (orders.isEmpty) {
                return const AnimatedEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'لا توجد طلبات بعد',
                  subtitle: 'طلباتك ستظهر هنا بعد إتمام أول عملية شراء',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long, color: Color(0xFF00827E)),
                              const SizedBox(width: 10),
                              Text(
                                'طلب #${order.id.length > 6 ? order.id.substring(0, 6) : order.id}',
                                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(order.status).withAlpha(25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  order.status,
                                  style: GoogleFonts.tajawal(
                                    color: _statusColor(order.status),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 13, color: context.cFaint),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(order.createdAt),
                                style: GoogleFonts.tajawal(fontSize: 12, color: context.cFaint),
                              ),
                            ],
                          ),
                          // كود الاستلام — يظهر فقط بعد قبول الطلب من المكتبة
                          if (order.pickupCode.isNotEmpty &&
                              order.status != 'قيد المعالجة') ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00827E).withAlpha(18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF00827E).withAlpha(60)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.confirmation_number_outlined,
                                      color: Color(0xFF00827E), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'كود الاستلام: ',
                                    style: GoogleFonts.tajawal(
                                        fontSize: 14, color: context.cMuted),
                                  ),
                                  Text(
                                    order.pickupCode,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF00827E),
                                      letterSpacing: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (order.address.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.place_outlined, size: 16, color: context.cFaint),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    order.address,
                                    style: GoogleFonts.tajawal(fontSize: 13, color: context.cMuted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.payments_outlined, size: 16, color: context.cFaint),
                              const SizedBox(width: 4),
                              Text(
                                'الإجمالي: ${order.total.toStringAsFixed(0)} ل.س',
                                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: order.items.map((item) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(
                                      '${item.title} × ${item.quantity}',
                                      style: GoogleFonts.tajawal(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.grey.shade100,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (item.bindingType != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 3),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: item.bindingType == 'تسليك'
                                            ? Colors.orange.shade50
                                            : Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: item.bindingType == 'تسليك'
                                              ? Colors.orange.shade300
                                              : Colors.teal.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            item.bindingType == 'تسليك'
                                                ? Icons.rotate_right_rounded
                                                : Icons.layers_outlined,
                                            size: 13,
                                            color: item.bindingType == 'تسليك'
                                                ? Colors.orange.shade800
                                                : Colors.teal.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'تجليد: ${item.bindingType!}',
                                            style: GoogleFonts.tajawal(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: item.bindingType == 'تسليك'
                                                  ? Colors.orange.shade800
                                                  : Colors.teal.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                          // زر التقييم — يظهر بعد التسليم ما لم يُقيَّم بعد
                          if (order.status == 'تم التسليم' &&
                              order.rating == 0) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _showRatingDialog(context, order),
                              icon: const Icon(Icons.star_border,
                                  color: Colors.amber, size: 18),
                              label: Text(
                                'قيّم تجربتك',
                                style: GoogleFonts.tajawal(
                                    color: Colors.amber.shade800,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.amber.shade300),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                          // عرض التقييم المُرسل
                          if (order.rating > 0) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ...List.generate(
                                  5,
                                  (i) => Icon(
                                    i < order.rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'تم تقييمك لهذا الطلب',
                                  style: GoogleFonts.tajawal(
                                      fontSize: 12,
                                      color: context.cFaint),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                      .animate(delay: (index * 60).ms)
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.15, end: 0, duration: 350.ms, curve: Curves.easeOut);
                },
              );
            },
          );
        },
      ),
    );
  }
}
