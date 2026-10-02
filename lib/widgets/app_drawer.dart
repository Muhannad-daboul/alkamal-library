import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../main.dart' show tabIndexNotifier, ordersUnseenNotifier;
import '../screens/about_us_screen.dart';
import '../screens/privacy_policy_screen.dart';

/// يُستخدم في كل شاشات التطبيق لفتح القائمة الجانبية
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: const Color(0xFF00827E),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 90,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (ctx, e, _) => const Icon(
                      Icons.local_pharmacy,
                      color: Colors.white,
                      size: 90,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'مكتبة الكمال الطبية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  _item(context, Icons.home_outlined, 'الرئيسية', 2),
                  _item(context, Icons.search_outlined, 'البحث', 0),
                  _item(context, Icons.shopping_cart_outlined, 'السلة', 1),
                  ValueListenableBuilder<int>(
                    valueListenable: ordersUnseenNotifier,
                    builder: (_, count, _) => _item(
                      context,
                      Icons.inventory_2_outlined,
                      'طلباتي',
                      4,
                      badgeCount: count,
                    ),
                  ),
                  _item(context, Icons.menu_book_outlined, 'الأرشيف', 3),
                  _item(context, Icons.person_outline, 'حسابي', 5),
                  const Divider(height: 24, indent: 16, endIndent: 16),
                  _navItem(
                    context,
                    Icons.info_outline,
                    'من نحن',
                    const AboutUsScreen(),
                  ),
                  _navItem(
                    context,
                    Icons.privacy_tip_outlined,
                    'سياسة الخصوصية',
                    const PrivacyPolicyScreen(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'الإصدار 1.0.0',
                style: TextStyle(color: context.cFaint, fontSize: 12.0),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    int tabIndex, {
    int badgeCount = 0,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              constraints: const BoxConstraints(minWidth: 24),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: () {
        Navigator.pop(context); // أغلق الـ drawer
        // إذا كنا في sub-screen، ارجع للرئيسية أولاً
        Navigator.of(context).popUntil((route) => route.isFirst);
        tabIndexNotifier.value = tabIndex;
      },
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    Widget destination,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => destination),
        );
      },
    );
  }
}

/// زر المنيو للـ AppBar — يفتح الـ Drawer
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(ctx).openDrawer(),
      ),
    );
  }
}

/// شعار المكتبة للـ AppBar — يُوضع في actions (يظهر على اليسار في RTL)
class LogoAction extends StatelessWidget {
  const LogoAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Image.asset(
        'assets/images/logo.png',
        height: 40,
        color: Colors.white,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (context, e, st) =>
            const Icon(Icons.local_pharmacy, color: Colors.white, size: 36),
      ),
    );
  }
}

/// يعرض SnackBar أخضر لمدة 3 ثواني
void showCartSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF00827E),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// يعرض صورة المنتج — يدعم URLs من Firebase Storage وأيضاً assets محلية
Widget productImage({
  required String asset,
  double size = 72,
  bool isSupply = false,
  double radius = 18,
}) {
  final icon = isSupply ? Icons.medical_services : Icons.menu_book;
  const color = Color(0xFF00827E);
  final isUrl = asset.startsWith('http');

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: asset.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: isUrl
                ? Image.network(
                    asset,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, _) =>
                        Icon(icon, color: color, size: size * 0.5),
                  )
                : Image.asset(
                    'assets/images/$asset',
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, _) =>
                        Icon(icon, color: color, size: size * 0.5),
                  ),
          )
        : Icon(icon, color: color, size: size * 0.5),
  );
}
