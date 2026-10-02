import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../main.dart';
import '../widgets/chat_bot_fab.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'lectures_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Order: Search(0) | Cart(1) | Home(2-center) | Lectures(3) | Orders(4) | Profile(5)
  static const _rootScreens = [
    SearchScreen(),
    CartScreen(),
    HomeScreen(),
    LecturesScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  final List<GlobalKey<NavigatorState>> _navKeys = List.generate(
    6,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    tabIndexNotifier.addListener(_onTabChange);
  }

  @override
  void dispose() {
    tabIndexNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    setState(() {});
    if (tabIndexNotifier.value == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showArchiveInfoDialog();
      });
    }
  }

  void _showArchiveInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF00827E).withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF00827E),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'أنت الآن في قسم الأرشيف',
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00827E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'هنا يمكنك تصفح محاضرات جميع الكليات والسنوات وإضافتها إلى سلة الطلبات للحصول على نسخ مطبوعة.',
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  color: context.cMuted,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00827E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'فهمت',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabNavigator(int index) {
    return Navigator(
      key: _navKeys[index],
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => _rootScreens[index],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final currentIndex = tabIndexNotifier.value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final navState = _navKeys[currentIndex].currentState;
        if (navState != null && navState.canPop()) {
          navState.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: currentIndex,
              children: List.generate(6, _buildTabNavigator),
            ),
            const DraggableChatBotFab(),
          ],
        ),
        bottomNavigationBar: _CustomNavBar(
          currentIndex: currentIndex,
          primary: primary,
        ),
      ),
    );
  }
}

// ── Custom nav bar with raised home button ────────────────
class _CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Color primary;

  const _CustomNavBar({required this.currentIndex, required this.primary});

  static const _centerSize = 62.0;
  static const _riseAbove = 22.0;
  static const _barHeight = 62.0;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final totalHeight = _barHeight + _riseAbove + bottomPad;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // ── bar background ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: _barHeight + bottomPad,
            child: Container(
              decoration: BoxDecoration(
                color: context.cSurface,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.only(bottom: bottomPad),
              child: Row(
                children: [
                  _NavItem(
                    index: 0,
                    icon: Icons.search_outlined,
                    selectedIcon: Icons.search,
                    label: 'البحث',
                    currentIndex: currentIndex,
                    primary: primary,
                  ),
                  ValueListenableBuilder<List<CartItem>>(
                    valueListenable: cartNotifier,
                    builder: (_, cart, _) {
                      final count = cart.fold(0, (s, i) => s + i.quantity);
                      return _NavItem(
                        index: 1,
                        icon: Icons.shopping_cart_outlined,
                        selectedIcon: Icons.shopping_cart,
                        label: 'السلة',
                        currentIndex: currentIndex,
                        primary: primary,
                        badgeCount: count,
                      );
                    },
                  ),
                  const SizedBox(width: _centerSize + 8),
                  _NavItem(
                    index: 3,
                    icon: Icons.menu_book_outlined,
                    selectedIcon: Icons.menu_book,
                    label: 'الأرشيف',
                    currentIndex: currentIndex,
                    primary: primary,
                  ),
                  _NavItem(
                    index: 5,
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'حسابي',
                    currentIndex: currentIndex,
                    primary: primary,
                  ),
                ],
              ),
            ),
          ),
          // ── raised home button ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  tabIndexNotifier.value = 2;
                },
                child: Container(
                  width: _centerSize,
                  height: _centerSize,
                  decoration: BoxDecoration(
                    color: currentIndex == 2 ? primary : context.cSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: currentIndex == 2 ? Colors.white : primary,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withAlpha(90),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.home,
                    color: currentIndex == 2 ? Colors.white : primary,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int currentIndex;
  final Color primary;
  final int badgeCount;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.currentIndex,
    required this.primary,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => tabIndexNotifier.value = index,
        splashColor: primary.withAlpha(20),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? primary : Colors.grey.shade400,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? primary : Colors.grey.shade400,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
