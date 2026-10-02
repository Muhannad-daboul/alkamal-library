import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../data.dart';
import '../services/firestore_service.dart';
import '../widgets/app_drawer.dart';
import 'print_order_screen.dart';
import 'lectures_screen.dart';
import 'supply_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.cBackground,
        appBar: _buildAppBar(context),
        drawer: const AppDrawer(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BannersSection(),
              const SizedBox(height: 24),
              _SectionTabs(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text('مكتبة الكمال'),
      actions: const [LogoAction()],
    );
  }
}

// ── Banners (Ads) ─────────────────────────────────────────
class _BannersSection extends StatefulWidget {
  @override
  State<_BannersSection> createState() => _BannersSectionState();
}

class _BannersSectionState extends State<_BannersSection> {
  final _pageCtrl = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _adCount = 0;
  int _currentPage = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _restartTimer(int count) {
    _timer?.cancel();
    _adCount = count;
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      final next = (_pageCtrl.page!.round() + 1) % _adCount;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdBanner>>(
      stream: FirestoreService.getActiveAds(),
      builder: (context, snap) {
        final ads = snap.data ?? [];
        if (ads.isEmpty) return const SizedBox.shrink();

        if (ads.length != _adCount) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _restartTimer(ads.length),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00827E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'عروض اليوم',
                  style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: ads.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final ad = ads[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: context.cFill,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      ad.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 48, color: Colors.black26),
                      ),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (ads.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(ads.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF00827E)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Tabs Section ──────────────────────────────────────────
class _SectionTabs extends StatefulWidget {
  @override
  State<_SectionTabs> createState() => _SectionTabsState();
}

class _SectionTabsState extends State<_SectionTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF00827E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'تصفّح المتجر',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Modern tab headers
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _ModernTab(
                label: 'الكليات',
                icon: Icons.school_outlined,
                selected: _tab.index == 0,
                onTap: () => _tab.animateTo(0),
              ),
              _ModernTab(
                label: 'المستلزمات',
                icon: Icons.medical_services_outlined,
                selected: _tab.index == 1,
                onTap: () => _tab.animateTo(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Print PDF — special CTA
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrintOrderScreen()),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withAlpha(60),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.print_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اطبع ملفاتك PDF',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'ارفع الملف واستلمه جاهز',
                        style: GoogleFonts.tajawal(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 14),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 16),

        // Grid
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _tab.index == 0
              ? _buildCategoryGrid(
                  key: const ValueKey('faculties'),
                  items: categories,
                  onTap: (c) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LectureYearsScreen(
                        category: c,
                        initialArchive: 'السنة الحالية',
                        currentYearOnly: true,
                      ),
                    ),
                  ),
                )
              : _buildSupplyGrid(
                  key: const ValueKey('supplies'),
                  items: supplyCategories,
                  onTap: (s) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplyDetailScreen(supply: s),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid({
    required Key key,
    required List<CategoryItem> items,
    required void Function(CategoryItem) onTap,
  }) {
    return GridView.builder(
      key: key,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return _BoldCategoryCard(item: item, onTap: () => onTap(item))
            .animate(delay: (i * 80).ms)
            .fadeIn(duration: 400.ms)
            .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.easeOutBack,
            );
      },
    );
  }

  Widget _buildSupplyGrid({
    required Key key,
    required List<SupplyCategory> items,
    required void Function(SupplyCategory) onTap,
  }) {
    return GridView.builder(
      key: key,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return _SupplyCard(item: item, onTap: () => onTap(item))
            .animate(delay: (i * 80).ms)
            .fadeIn(duration: 400.ms)
            .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.easeOutBack,
            );
      },
    );
  }
}

// ── Modern Tab Button ─────────────────────────────────────
class _ModernTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModernTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF00827E) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : context.cMuted,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.tajawal(
                  color: selected ? Colors.white : context.cMuted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bold Category Card with Gradient + SVG ────────────────
class _BoldCategoryCard extends StatefulWidget {
  final CategoryItem item;
  final VoidCallback onTap;
  const _BoldCategoryCard({required this.item, required this.onTap});

  @override
  State<_BoldCategoryCard> createState() => _BoldCategoryCardState();
}

class _BoldCategoryCardState extends State<_BoldCategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cat.color.withAlpha(50), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: cat.svgAsset != null
                      ? Center(
                          child: SvgPicture.asset(
                            cat.svgAsset!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Center(
                          child: Icon(cat.icon, color: cat.color, size: 56),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  cat.title,
                  style: GoogleFonts.tajawal(
                    color: context.cText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  cat.subtitle,
                  style: GoogleFonts.tajawal(
                    color: context.cFaint,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Supply Card (simpler, also bold) ─────────────────────
class _SupplyCard extends StatefulWidget {
  final SupplyCategory item;
  final VoidCallback onTap;
  const _SupplyCard({required this.item, required this.onTap});

  @override
  State<_SupplyCard> createState() => _SupplyCardState();
}

class _SupplyCardState extends State<_SupplyCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sup = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sup.color.withAlpha(50), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sup.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(sup.icon, color: sup.color, size: 26),
              ),
              const Spacer(),
              Text(
                sup.title,
                style: GoogleFonts.tajawal(
                  color: context.cText,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sup.subtitle,
                style: GoogleFonts.tajawal(
                  color: context.cFaint,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
