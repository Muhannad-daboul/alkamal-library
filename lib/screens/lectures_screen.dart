import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../data.dart';
import '../main.dart';
import '../services/firestore_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/cart_added_popup.dart';

// ── Entry screen: pick category ───────────────────────────
class LecturesScreen extends StatelessWidget {
  const LecturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = lectureCategories;
    return Scaffold(
      appBar: AppBar(
        title: Text('الأرشيف', style: GoogleFonts.tajawal()),
        leading: const MenuButton(),
        actions: const [LogoAction()],
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _CategoryCard(cat: categories[0]),
                  const SizedBox(width: 14),
                  _CategoryCard(cat: categories[1]),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  _CategoryCard(cat: categories[2]),
                  const SizedBox(width: 14),
                  _CategoryCard(cat: categories[3]),
                ],
              ),
            ),
          ],
        ),
      ),

    );
  }
}

// ── Category card ─────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final CategoryItem cat;
  const _CategoryCard({required this.cat});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LectureYearsScreen(category: cat),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cat.color.withAlpha(18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cat.color.withAlpha(50)),
          ),
          child: Column(
            children: [
              Expanded(
                child: cat.svgAsset != null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                        child: SvgPicture.asset(
                          cat.svgAsset!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Center(
                        child: cat.faIcon != null
                            ? FaIcon(cat.faIcon!, color: cat.color, size: 44)
                            : Icon(cat.icon, color: cat.color, size: 44),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
                child: Text(
                  cat.title,
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cat.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Year picker ───────────────────────────────────────────
class LectureYearsScreen extends StatelessWidget {
  final CategoryItem category;
  final String? initialArchive;
  final bool currentYearOnly;
  const LectureYearsScreen({
    super.key,
    required this.category,
    this.initialArchive,
    this.currentYearOnly = false,
  });

  static const _primary = Color(0xFF00827E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.title, style: GoogleFonts.tajawal()),
        leading: const BackButton(),
        actions: const [LogoAction()],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: category.years.length,
        itemBuilder: (context, i) {
          final year = category.years[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Icon(Icons.class_outlined, color: _primary),
              title: Text(
                year,
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LectureListScreen(
                    category: category,
                    year: year,
                    initialArchive: initialArchive,
                    currentYearOnly: currentYearOnly,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Semester + archive tabs wrapper ──────────────────────
class LectureListScreen extends StatefulWidget {
  final CategoryItem category;
  final String year;
  final String? initialArchive;
  final bool currentYearOnly;

  const LectureListScreen({
    super.key,
    required this.category,
    required this.year,
    this.initialArchive,
    this.currentYearOnly = false,
  });

  @override
  State<LectureListScreen> createState() => _LectureListScreenState();
}

class _LectureListScreenState extends State<LectureListScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<String> _sections = [];
  String _semester = 'الفصل الأول';
  StreamSubscription<List<String>>? _sectionsSub;

  @override
  void initState() {
    super.initState();
    _sectionsSub = FirestoreService.getArchiveSections().listen((sections) {
      if (!mounted) return;
      final filtered = widget.currentYearOnly
          ? sections.where((s) => s == 'السنة الحالية').toList()
          : sections;
      if (filtered.length != _sections.length) {
        _tabController?.dispose();
        var initialIdx = 0;
        if (widget.initialArchive != null) {
          initialIdx = filtered.indexOf(widget.initialArchive!);
          if (initialIdx == -1) initialIdx = 0;
        } else {
          initialIdx = filtered.indexWhere((s) => s.contains('2023'));
          if (initialIdx == -1) initialIdx = filtered.length - 1;
          if (initialIdx < 0) initialIdx = 0;
        }
        _tabController = TabController(
          length: filtered.length,
          vsync: this,
          initialIndex: initialIdx,
        );
      }
      setState(() => _sections = filtered);
    });
  }

  @override
  void dispose() {
    _sectionsSub?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00827E);

    if (_sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.category.title} — ${widget.year}',
              style: GoogleFonts.tajawal()),
          leading: const BackButton(),
          actions: const [LogoAction()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.category.title} — ${widget.year}',
          style: GoogleFonts.tajawal(),
        ),
        leading: const BackButton(),
        actions: const [LogoAction()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: ['الفصل الأول', 'الفصل الثاني'].map((s) {
                    final selected = _semester == s;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(
                          s,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: selected ? primary : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: Colors.white,
                        backgroundColor: const Color(0xFF006B68),
                        side: BorderSide(
                          color: selected ? Colors.white : Colors.white70,
                          width: 1.5,
                        ),
                        onSelected: (_) => setState(() => _semester = s),
                      ),
                    );
                  }).toList(),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                indicatorWeight: 2.5,
                labelStyle: GoogleFonts.tajawal(
                    fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.tajawal(fontSize: 12),
                tabs: _sections.map((s) => Tab(text: s)).toList(),
              ),
            ],
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: _sections
            .map((section) => _LectureTab(
                  category: widget.category.title,
                  year: widget.year,
                  semester: _semester,
                  archiveSection: section,
                ))
            .toList(),
      ),
    );
  }
}

// ── Single tab: subject list ──────────────────────────────
class _LectureTab extends StatefulWidget {
  final String category;
  final String year;
  final String semester;
  final String archiveSection;

  const _LectureTab({
    required this.category,
    required this.year,
    required this.semester,
    required this.archiveSection,
  });

  @override
  State<_LectureTab> createState() => _LectureTabState();
}

class _LectureTabState extends State<_LectureTab> {
  static const _primary = Color(0xFF00827E);

  // ── Selection state ────────────────────────────────
  // Subjects don't carry a Firestore id, so we key by the subject name.
  // _isMultiSelectMode is explicit: long-press flips it on, "إلغاء" turns
  // it off. Tap behaviour (navigate vs toggle) is driven by this flag.
  final Set<String> _selectedSubjectIds = <String>{};
  bool _isMultiSelectMode = false;

  // Cached data so rebuilds (e.g. semester change) don't blank the screen
  // while a new Firestore stream resubscribes.
  List<Lecture>? _lectures;
  PagePricing _pricing = const PagePricing();
  Object? _lectureError;

  StreamSubscription<List<Lecture>>? _lecSub;
  StreamSubscription<PagePricing>? _priceSub;

  @override
  void initState() {
    super.initState();
    _subscribePricing();
    _subscribeLectures();
  }

  @override
  void didUpdateWidget(covariant _LectureTab old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category ||
        old.year != widget.year ||
        old.semester != widget.semester ||
        old.archiveSection != widget.archiveSection) {
      _subscribeLectures();
    }
  }

  void _subscribePricing() {
    _priceSub?.cancel();
    _priceSub = FirestoreService.getPagePricing().listen((p) {
      if (mounted) setState(() => _pricing = p);
    });
  }

  void _subscribeLectures() {
    _lecSub?.cancel();
    // keep previous data visible while new stream loads
    setState(() => _lectureError = null);
    _lecSub = FirestoreService.getLectures(
      category: widget.category,
      year: widget.year,
      semester: widget.semester,
      archiveSection: widget.archiveSection,
    ).listen(
      (lecs) {
        if (mounted) setState(() => _lectures = lecs);
      },
      onError: (e) {
        if (mounted) setState(() => _lectureError = e);
      },
    );
  }

  @override
  void dispose() {
    lectureSelectionActiveNotifier.value = false;
    _lecSub?.cancel();
    _priceSub?.cancel();
    super.dispose();
  }

  // Enter multi-select mode and mark the long-pressed subject.
  void _enterMultiSelect(String subjectId) {
    setState(() {
      _isMultiSelectMode = true;
      _selectedSubjectIds.add(subjectId);
    });
  }

  // Add/remove a subject while already in multi-select mode.
  // Exits the mode if the user cleared the last selection by tapping.
  void _toggleSubjectSelection(String subjectId) {
    setState(() {
      if (_selectedSubjectIds.contains(subjectId)) {
        _selectedSubjectIds.remove(subjectId);
        if (_selectedSubjectIds.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedSubjectIds.add(subjectId);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _selectedSubjectIds.clear();
      _isMultiSelectMode = false;
    });
  }

  void _openSubject(String subjectId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SubjectLecturesScreen(
          category: widget.category,
          year: widget.year,
          semester: widget.semester,
          archiveSection: widget.archiveSection,
          subject: subjectId,
        ),
      ),
    );
  }

  Future<void> _addSelectedToCart(
    Map<String, List<Lecture>> groups,
    PagePricing pricing,
  ) async {
    final list = List<CartItem>.from(cartNotifier.value);
    for (final subject in _selectedSubjectIds) {
      final lectures = groups[subject] ?? [];
      if (lectures.isEmpty) continue;

      // هاي شاشة المواد — تحديد مادة = تحديد كل محاضراتها = باندل دائماً
      if (!mounted) return;
      final bindingType = await _showBindingDialogForSubject(subject, pricing);
      if (!mounted) return;

      double totalPrice = lectures.fold<double>(
          0, (s, l) => s + (l.customPrice ?? (l.pages * pricing.priceA5)));
      if (bindingType == 'تسليك') totalPrice += pricing.bindingPrice;

      final bundleId = 'bundle:$subject';
      final idx = list.indexWhere((i) => i.id == bundleId);
      final ctx =
          '${widget.category} · ${widget.year} · ${widget.semester}';
      if (idx >= 0) {
        list[idx].quantity++;
      } else {
        list.add(CartItem(
          id: bundleId,
          title: '$subject كامل\n$ctx',
          price: totalPrice,
          isLecture: true,
          imageUrl: lectures.first.previewImageUrl,
          bindingType: bindingType,
          bundleLectureIds: lectures.map((l) => l.id).toList(),
        ));
      }
    }
    cartNotifier.value = list;
    _exitMultiSelect();
    if (mounted) showCartAddedPopup(context);
  }

  Future<String?> _showBindingDialogForSubject(
    String subject,
    PagePricing pricing,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final bindingPrice = pricing.bindingPrice.toStringAsFixed(0);
    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cFill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'اختر نوع التجليد',
              textAlign: TextAlign.right,
              style: GoogleFonts.tajawal(
                  fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subject,
              textAlign: TextAlign.right,
              style: GoogleFonts.tajawal(fontSize: 13, color: context.cFaint),
            ),
            const SizedBox(height: 16),
            _bindingOptionSheet(sheetCtx, 'تسليك', Icons.rotate_right_rounded,
                '+$bindingPrice ل.س', primary),
            const SizedBox(height: 10),
            _bindingOptionSheet(sheetCtx, 'خرز', Icons.layers_outlined,
                'بدون رسوم إضافية', Colors.teal),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheetCtx, null),
              child: Text('بدون تجليد',
                  style: GoogleFonts.tajawal(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bindingOptionSheet(BuildContext ctx, String label, IconData icon,
      String subtitle, Color color) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(label,
                      style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle,
                      style: GoogleFonts.tajawal(
                          fontSize: 12, color: ctx.cMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: color),
          ],
        ),
      ),
    );
  }

  Widget _statChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pricing = _pricing;
    final lectures = _lectures;

    if (_lectureError != null && lectures == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'تعذّر تحميل المحاضرات. تحقق من الاتصال وحاول مجدداً.',
            style: GoogleFonts.tajawal(fontSize: 14, color: context.cMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (lectures == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lectures.isEmpty) {
      return Center(
        child: Text(
          'لا توجد محاضرات في هذا القسم',
          style: GoogleFonts.tajawal(fontSize: 16, color: context.cFaint),
        ),
      );
    }

    final groups = <String, List<Lecture>>{};
    for (final lec in lectures) {
      final key = lec.subject.isNotEmpty ? lec.subject : 'محاضرات';
      groups.putIfAbsent(key, () => []).add(lec);
    }

    // Drop any selected ids that no longer exist in the data (e.g. after
    // archive section changes). Keeps state in sync with the visible list.
    final visibleSubjectIds = groups.keys.toSet();
    _selectedSubjectIds.retainAll(visibleSubjectIds);
    if (_selectedSubjectIds.isEmpty) _isMultiSelectMode = false;

    final hasSelection = _selectedSubjectIds.isNotEmpty;

    // أبلغ الـ ChatBotFab بعد بناء الإطار مشان يرتفع لفوق ولا يتداخل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (lectureSelectionActiveNotifier.value != hasSelection) {
        lectureSelectionActiveNotifier.value = hasSelection;
      }
    });

    // حسابات الملخص: عدد المحاضرات، الصفحات، والسعر الإجمالي للمواد المحددة
    int totalLectures = 0;
    int totalPages = 0;
    double totalPrice = 0;
    for (final subject in _selectedSubjectIds) {
      for (final lec in groups[subject] ?? <Lecture>[]) {
        totalLectures++;
        totalPages += lec.pages;
        totalPrice += lec.customPrice ?? (lec.pages * pricing.priceA5);
      }
    }

    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, hasSelection ? 120 : 16),
          itemCount: groups.length,
          itemBuilder: (context, i) {
            final entry = groups.entries.elementAt(i);
            final subjectId = entry.key;
            final isSelected = _selectedSubjectIds.contains(subjectId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SubjectCard(
                subject: subjectId,
                lectureCount: entry.value.length,
                isSelected: isSelected,
                isMultiSelectMode: _isMultiSelectMode,
                onCardTap: () {
                  if (_isMultiSelectMode) {
                    _toggleSubjectSelection(subjectId);
                  } else {
                    _openSubject(subjectId);
                  }
                },
                onCardLongPress: () => _enterMultiSelect(subjectId),
              ),
            );
          },
        ),
        if (hasSelection)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: _primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _statChip(
                        icon: Icons.folder_outlined,
                        label: '${_selectedSubjectIds.length} مادة',
                      ),
                      const SizedBox(width: 6),
                      _statChip(
                        icon: Icons.menu_book_outlined,
                        label: '$totalLectures محاضرة',
                      ),
                      const SizedBox(width: 6),
                      _statChip(
                        icon: Icons.description_outlined,
                        label: '$totalPages صفحة',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'الإجمالي',
                              style: GoogleFonts.tajawal(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '${totalPrice.toStringAsFixed(0)} ل.س',
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _exitMultiSelect,
                        child: Text(
                          'إلغاء',
                          style: GoogleFonts.tajawal(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _addSelectedToCart(groups, pricing),
                        icon: const Icon(
                            Icons.shopping_cart_outlined,
                            size: 18),
                        label: Text(
                          'أضف للسلة',
                          style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _primary,
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Subject card ──────────────────────────────────────────
class _SubjectCard extends StatelessWidget {
  final String subject;
  final int lectureCount;
  final VoidCallback onCardTap;
  final VoidCallback onCardLongPress;
  final bool isSelected;
  final bool isMultiSelectMode;

  const _SubjectCard({
    required this.subject,
    required this.lectureCount,
    required this.onCardTap,
    required this.onCardLongPress,
    this.isSelected = false,
    this.isMultiSelectMode = false,
  });

  static const _primary = Color(0xFF00827E);

  @override
  Widget build(BuildContext context) {
    // Use Material + InkWell so taps and long-presses go through Flutter's
    // ink gesture pipeline, which disambiguates tap vs long-press cleanly.
    return Material(
      color: isSelected ? _primary.withAlpha(18) : context.cSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onCardTap,
        onLongPress: onCardLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? _primary : _primary.withAlpha(40),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _primary.withAlpha(40)
                      : _primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected
                      ? Icons.check_circle_outline
                      : Icons.menu_book_outlined,
                  color: _primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$lectureCount محاضرة',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: context.cFaint,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing affordance: in multi-select mode show a checkbox,
              // otherwise show the navigation chevron.
              Icon(
                isMultiSelectMode
                    ? (isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank)
                    : Icons.arrow_forward_ios,
                size: isMultiSelectMode ? 22 : 16,
                color: isSelected ? _primary : context.cFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Subject lectures screen ───────────────────────────────
class _SubjectLecturesScreen extends StatefulWidget {
  final String category;
  final String year;
  final String semester;
  final String archiveSection;
  final String subject;

  const _SubjectLecturesScreen({
    required this.category,
    required this.year,
    required this.semester,
    required this.archiveSection,
    required this.subject,
  });

  @override
  State<_SubjectLecturesScreen> createState() => _SubjectLecturesScreenState();
}

class _SubjectLecturesScreenState extends State<_SubjectLecturesScreen> {
  static const _primary = Color(0xFF00827E);

  final Set<String> _selected = {};
  List<Lecture> _lectures = [];
  PagePricing _pricing = const PagePricing();
  bool _loading = true;

  StreamSubscription<List<Lecture>>? _lecSub;
  StreamSubscription<PagePricing>? _priceSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showSubjectHintDialog();
    });
    _priceSub = FirestoreService.getPagePricing().listen((p) {
      if (mounted) setState(() => _pricing = p);
    });
    _lecSub = FirestoreService.getLectures(
      category: widget.category,
      year: widget.year,
      semester: widget.semester,
      archiveSection: widget.archiveSection,
    )
        .map((all) => all
            .where((l) =>
                (l.subject.isEmpty ? 'محاضرات' : l.subject) == widget.subject)
            .toList())
        .listen((lecs) {
      if (!mounted) return;
      setState(() {
        _lectures = lecs;
        _loading = false;
        _selected.retainAll(lecs.map((l) => l.id).toSet());
      });
    });
  }

  @override
  void dispose() {
    lectureSelectionActiveNotifier.value = false;
    _lecSub?.cancel();
    _priceSub?.cancel();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == _lectures.length) {
        _selected.clear();
      } else {
        _selected.addAll(_lectures.map((l) => l.id));
      }
    });
  }

  Future<void> _addToCart() async {
    final selectedLectures =
        _lectures.where((l) => _selected.contains(l.id)).toList();
    final allSelected =
        selectedLectures.length == _lectures.length && _lectures.isNotEmpty;

    String? bindingType;
    if (allSelected) {
      if (!mounted) return;
      bindingType = await _showBindingDialog();
      if (!mounted) return;
    }

    final list = List<CartItem>.from(cartNotifier.value);

    if (allSelected) {
      double totalPrice = selectedLectures.fold<double>(
          0, (s, l) => s + (l.customPrice ?? (l.pages * _pricing.priceA5)));
      if (bindingType == 'تسليك') totalPrice += _pricing.bindingPrice;

      final bundleId = 'bundle:${widget.subject}';
      final idx = list.indexWhere((i) => i.id == bundleId);
      final ctx =
          '${widget.category} · ${widget.year} · ${widget.semester}';
      if (idx >= 0) {
        list[idx].quantity++;
      } else {
        list.add(CartItem(
          id: bundleId,
          title: '${widget.subject} كامل\n$ctx',
          price: totalPrice,
          isLecture: true,
          imageUrl: selectedLectures.first.previewImageUrl,
          bindingType: bindingType,
          bundleLectureIds: selectedLectures.map((l) => l.id).toList(),
        ));
      }
    } else {
      for (final lec in selectedLectures) {
        final price = lec.customPrice ?? (lec.pages * _pricing.priceA5);
        final idx = list.indexWhere((i) => i.id == lec.id && i.isLecture);
        final ctx =
            '${widget.category} · ${widget.year} · ${widget.semester}';
        if (idx >= 0) {
          list[idx].quantity++;
        } else {
          final t = lec.title.trim();
          final showTitle = t.isNotEmpty && t != 'محاضرة ${lec.lectureNumber}';
          list.add(CartItem(
            id: lec.id,
            title: showTitle
                ? '${widget.subject} — محاضرة ${lec.lectureNumber}: $t\n$ctx'
                : '${widget.subject} — محاضرة ${lec.lectureNumber}\n$ctx',
            price: price,
            isLecture: true,
            imageUrl: lec.previewImageUrl,
          ));
        }
      }
    }
    cartNotifier.value = list;
    setState(() => _selected.clear());
    showCartAddedPopup(context);
  }

  Future<String?> _showBindingDialog() {
    final primary = Theme.of(context).colorScheme.primary;
    final bindingPrice = _pricing.bindingPrice.toStringAsFixed(0);
    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cFill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'اختر نوع التجليد',
              textAlign: TextAlign.right,
              style: GoogleFonts.tajawal(
                  fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'للمادة الكاملة',
              textAlign: TextAlign.right,
              style: GoogleFonts.tajawal(
                  fontSize: 13, color: context.cFaint),
            ),
            const SizedBox(height: 16),
            _bindingOption(ctx, 'تسليك', Icons.rotate_right_rounded,
                '+$bindingPrice ل.س', primary),
            const SizedBox(height: 10),
            _bindingOption(ctx, 'خرز', Icons.layers_outlined,
                'بدون رسوم إضافية', Colors.teal),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('بدون تجليد',
                  style: GoogleFonts.tajawal(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bindingOption(BuildContext ctx, String label, IconData icon,
      String subtitle, Color color) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(label,
                      style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle,
                      style: GoogleFonts.tajawal(
                          fontSize: 12, color: ctx.cMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: color),
          ],
        ),
      ),
    );
  }

  void _showSubjectHintDialog() {
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
                  color: _primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.touch_app_rounded,
                  color: _primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اضغط مطولاً على أي محاضرة لمعاينتها',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  color: context.cMuted,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'اضغط مطولاً لعرض المحاضرة',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
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

  void _showPreview(String url) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 400,
                        color: Colors.white,
                        child:
                            const Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (ctx, err, stack) => Container(
                  height: 200,
                  color: Colors.white,
                  child:
                      const Center(child: Icon(Icons.broken_image, size: 48)),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selected.isNotEmpty;
    final allSelected =
        _lectures.isNotEmpty && _selected.length == _lectures.length;

    // الـ action bar في هاي الشاشة ظاهر دائماً، فالـ chat FAB لازم
    // يكون مرفوع طول ما الشاشة معروضة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!lectureSelectionActiveNotifier.value) {
        lectureSelectionActiveNotifier.value = true;
      }
    });

    int selPages = 0;
    double selPrice = 0;
    for (final lec in _lectures.where((l) => _selected.contains(l.id))) {
      selPages += lec.pages;
      selPrice += lec.customPrice ?? (lec.pages * _pricing.priceA5);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject, style: GoogleFonts.tajawal()),
        leading: const BackButton(),
        actions: const [LogoAction()],
        // ── مسار التنقل: يبيّن للطالب وين هو بالضبط ──
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '${widget.category}  ‹  ${widget.year}  ‹  ${widget.semester}'
              '${widget.archiveSection == 'السنة الحالية' ? '' : '  ‹  ${widget.archiveSection}'}',
              style: GoogleFonts.tajawal(fontSize: 11.5, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lectures.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد محاضرات',
                    style: GoogleFonts.tajawal(
                        fontSize: 16, color: context.cFaint),
                  ),
                )
              : Column(
                  children: [
                    // ── tip banner: long-press hint (shown once at top
                    // instead of repeating under every lecture card) ──
                    if (_lectures.any((l) => l.previewImageUrl.isNotEmpty))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _primary.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_outlined,
                                size: 16, color: _primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'اضغط مطولاً على أي محاضرة لمعاينتها',
                                style: GoogleFonts.tajawal(
                                  fontSize: 12,
                                  color: _primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // ── header row ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            '${_lectures.length} محاضرة',
                            style: GoogleFonts.tajawal(
                                fontSize: 14, color: context.cMuted),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _toggleAll,
                            icon: Icon(
                              allSelected
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 18,
                              color: _primary,
                            ),
                            label: Text(
                              allSelected ? 'إلغاء الكل' : 'تحديد الكل',
                              style: GoogleFonts.tajawal(
                                  fontSize: 12, color: _primary),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── lecture list ────────────────────────────
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _lectures.length,
                        itemBuilder: (context, i) {
                          final lec = _lectures[i];
                          final sel = _selected.contains(lec.id);
                          final price =
                              lec.customPrice ?? (lec.pages * _pricing.priceA5);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _toggle(lec.id),
                              onLongPress: lec.previewImageUrl.isNotEmpty
                                  ? () => _showPreview(lec.previewImageUrl)
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? _primary.withAlpha(28)
                                      : context.cSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: sel ? _primary : context.cFill,
                                    width: sel ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(12),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? _primary.withAlpha(40)
                                            : _primary.withAlpha(20),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${lec.lectureNumber}',
                                          style: GoogleFonts.tajawal(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: _primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Builder(builder: (_) {
                                            final t = lec.title.trim();
                                            final displayTitle = t.isNotEmpty
                                                ? t
                                                : 'محاضرة ${lec.lectureNumber}';
                                            return Text(
                                              displayTitle,
                                              style: GoogleFonts.tajawal(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            );
                                          }),
                                          if (lec.doctorName.isNotEmpty)
                                            Text(
                                              'د. ${lec.doctorName}',
                                              style: GoogleFonts.tajawal(
                                                fontSize: 12,
                                                color: context.cFaint,
                                              ),
                                            ),
                                          Text(
                                            '${price.toStringAsFixed(0)} ل.س  •  ${lec.pages} صفحة',
                                            style: GoogleFonts.tajawal(
                                              fontSize: 13,
                                              color: _primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      sel
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color:
                                          sel ? _primary : context.cFaint,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // ── action bar (plain Container, no Material/elevation) ──
                    Container(
                      decoration: BoxDecoration(
                        color: _primary,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    hasSelection
                                        ? '${_selected.length} محاضرة • $selPages صفحة'
                                        : 'حدّد محاضرات للإضافة',
                                    style: GoogleFonts.tajawal(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    hasSelection
                                        ? '${selPrice.toStringAsFixed(0)} ل.س'
                                        : '0 ل.س',
                                    style: GoogleFonts.tajawal(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasSelection) ...[
                              TextButton(
                                onPressed: () =>
                                    setState(() => _selected.clear()),
                                child: Text(
                                  'إلغاء',
                                  style: GoogleFonts.tajawal(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            ElevatedButton.icon(
                              onPressed: hasSelection ? _addToCart : null,
                              icon: const Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 18),
                              label: Text(
                                'أضف للسلة',
                                style: GoogleFonts.tajawal(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _primary,
                                disabledBackgroundColor:
                                    Colors.white.withAlpha(80),
                                disabledForegroundColor:
                                    Colors.white.withAlpha(180),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
