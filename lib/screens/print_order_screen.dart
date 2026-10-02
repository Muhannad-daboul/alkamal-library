import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';

import '../app_theme.dart';
import '../data.dart';
import '../main.dart';
import '../services/firestore_service.dart';
import '../widgets/app_drawer.dart';

class _UploadedFile {
  final String name;
  final Uint8List bytes;
  final int pageCount;
  final bool isImage;

  const _UploadedFile({
    required this.name,
    required this.bytes,
    required this.pageCount,
    required this.isImage,
  });
}

class PrintOrderScreen extends StatefulWidget {
  const PrintOrderScreen({super.key});

  @override
  State<PrintOrderScreen> createState() => _PrintOrderScreenState();
}

class _PrintOrderScreenState extends State<PrintOrderScreen> {
  static const _primary = Color(0xFF00827E);

  // Options
  String _pageSize = 'A4';
  String _sides = 'one';
  String _color = 'bw';
  String _binding = 'none';
  int _copies = 1;

  // Files
  final List<_UploadedFile> _files = [];
  String? _processingMessage; // non-null = show loading overlay
  bool _addingToCart = false;
  List<double> _fileProgress = [];
  int _uploadingFileIndex = -1;

  // Pricing
  PrintPricing _pricing = const PrintPricing();
  StreamSubscription<PrintPricing>? _pricingSub;

  // Notes
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pricingSub = FirestoreService.getPrintPricing().listen((p) {
      if (mounted) setState(() => _pricing = p);
    });
  }

  @override
  void dispose() {
    _pricingSub?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _totalPageCount => _files.fold(0, (s, f) => s + f.pageCount);

  double get _pricePerPage {
    if (_color == 'color') {
      return _sides == 'one'
          ? _pricing.colorSinglePage
          : _pricing.colorDoublePage;
    }
    return _sides == 'one' ? _pricing.bwSinglePage : _pricing.bwDoublePage;
  }

  double get _bindingFee {
    switch (_binding) {
      case 'staple':
        return _pricing.bindingStaple;
      case 'spiral':
        return _pricing.bindingSpiral;
      default:
        return 0;
    }
  }

  double get _total =>
      (_totalPageCount * _pricePerPage + _bindingFee) * _copies;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _processingMessage = 'جاري تحليل الملف...');
    try {
      final newFiles = <_UploadedFile>[];
      for (final file in result.files) {
        if (file.bytes == null) continue;
        final doc = await PdfDocument.openData(file.bytes!);
        final pages = doc.pagesCount;
        await doc.close();
        newFiles.add(_UploadedFile(
          name: file.name,
          bytes: file.bytes!,
          pageCount: pages,
          isImage: false,
        ));
      }
      if (mounted) setState(() => _files.addAll(newFiles));
    } finally {
      if (mounted) setState(() => _processingMessage = null);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    setState(() => _processingMessage = 'جاري تحميل الصور...');
    try {
      final newFiles = <_UploadedFile>[];
      for (final img in images) {
        final bytes = await img.readAsBytes();
        newFiles.add(_UploadedFile(
          name: img.name,
          bytes: bytes,
          pageCount: 1,
          isImage: true,
        ));
      }
      if (mounted) setState(() => _files.addAll(newFiles));
    } finally {
      if (mounted) setState(() => _processingMessage = null);
    }
  }

  void _removeFile(int index) => setState(() => _files.removeAt(index));

  Future<void> _addToCart() async {
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة ملف أو صورة أولاً')),
      );
      return;
    }
    setState(() => _addingToCart = true);
    try {
      // استخدام uid الحقيقي للمستخدم — يربط الملف بصاحبه ويسمح بتطبيق قواعد التخزين
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى الانتظار وإعادة المحاولة')),
        );
        setState(() => _addingToCart = false);
        return;
      }
      final batchId = DateTime.now().millisecondsSinceEpoch.toString();
      final urls = <String>[];

      setState(() {
        _fileProgress = List.filled(_files.length, 0.0);
        _uploadingFileIndex = 0;
      });

      for (int i = 0; i < _files.length; i++) {
        setState(() => _uploadingFileIndex = i);
        final f = _files[i];
        final url = await FirestoreService.uploadPrintJobFile(
          uid: authUid,
          fileName: '${batchId}_${i}_${f.name}',
          bytes: f.bytes,
          contentType: f.isImage ? 'image/jpeg' : 'application/pdf',
          onProgress: (p) {
            if (mounted) setState(() => _fileProgress[i] = p);
          },
        );
        urls.add(url);
      }

      final colorLabel = _color == 'color' ? 'ملون' : 'أبيض وأسود';
      final sidesLabel = _sides == 'one' ? 'وجه واحد' : 'وجهان';
      final bindingLabel = _binding == 'none'
          ? 'بدون تجليد'
          : _binding == 'staple'
              ? 'تسليك'
              : 'خرز';
      final fileCount = _files.length;
      final titleName =
          fileCount > 1 ? '$fileCount ملفات' : _files.first.name;

      final item = CartItem(
        id: 'print_$batchId',
        title:
            'طباعة $titleName\n$_pageSize · $colorLabel · $sidesLabel · $bindingLabel · $_copies نسخة',
        price: _total,
        quantity: 1,
        isPrintJob: true,
        printJobStoragePath: urls.join(','),
        printJobNotes: _notesCtrl.text.trim(),
        printPageCount: _totalPageCount,
        printColor: _color,
        printSides: _sides,
        printBinding: _binding,
        printCopies: _copies,
      );

      cartNotifier.value = [...cartNotifier.value, item];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الإضافة للسلة ✓')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل رفع الملف: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.cBackground,
          appBar: AppBar(
            title: Text('طلب طباعة', style: GoogleFonts.tajawal()),
            leading: const MenuButton(),
            actions: const [LogoAction()],
          ),
          drawer: const AppDrawer(),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFileCard(),
                    const SizedBox(height: 16),
                    _buildOptionsCard(),
                    const SizedBox(height: 16),
                    _buildNotesCard(),
                    const SizedBox(height: 16),
                    if (_totalPageCount > 0) ...[
                      _buildPriceSummaryCard(),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              if (_processingMessage != null) _buildLoadingOverlay(),
            ],
          ),
          bottomSheet: _buildAddToCartBar(),
        ),
        if (_addingToCart) _buildUploadOverlay(),
      ],
    );
  }

  // ── Upload blur overlay ───────────────────────────────────
  Widget _buildUploadOverlay() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        color: Colors.black.withAlpha(100),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/upload_illustration.svg',
                  height: 90,
                ),
                const SizedBox(height: 16),
                Text(
                  'جاري رفع الملفات...',
                  style: GoogleFonts.tajawal(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'لا تغلق التطبيق',
                  style: GoogleFonts.tajawal(fontSize: 12, color: context.cFaint),
                ),
                const SizedBox(height: 20),
                ...List.generate(_files.length, (i) {
                  final progress = i < _fileProgress.length ? _fileProgress[i] : 0.0;
                  final isDone = progress >= 1.0;
                  final isCurrent = i == _uploadingFileIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDone ? Icons.check_circle : Icons.upload_file_outlined,
                              size: 16,
                              color: isDone ? Colors.green : (isCurrent ? _primary : context.cFaint),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _files[i].name,
                                style: GoogleFonts.tajawal(
                                  fontSize: 12,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                                  color: isCurrent ? _primary : context.cMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                color: isDone ? Colors.green : context.cFaint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: context.cFill,
                            valueColor: AlwaysStoppedAnimation(
                              isDone ? Colors.green : _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading overlay ───────────────────────────────────────
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withAlpha(160),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
                Icon(
                  Icons.picture_as_pdf,
                  color: Colors.white.withAlpha(220),
                  size: 36,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _processingMessage!,
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── File picker card ──────────────────────────────────────
  Widget _buildFileCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '📄 الملفات',
              style: GoogleFonts.tajawal(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_files.isEmpty) ...[
              const SizedBox(height: 8),
              SvgPicture.asset(
                'assets/images/upload_illustration.svg',
                height: 160,
              ),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildUploadButton(
                    icon: Icons.picture_as_pdf,
                    label: 'رفع PDF',
                    onTap: _pickPdf,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUploadButton(
                    icon: Icons.photo_library_outlined,
                    label: 'رفع صورة',
                    onTap: _pickImage,
                  ),
                ),
              ],
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._files.asMap().entries.map((e) => _buildFileItem(e.key, e.value)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: _primary.withAlpha(100), width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: _primary.withAlpha(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _primary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.tajawal(color: _primary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(int index, _UploadedFile file) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.cFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            file.isImage ? Icons.image_outlined : Icons.picture_as_pdf,
            color: _primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: GoogleFonts.tajawal(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${file.pageCount} ${file.isImage ? "صورة" : "صفحة"}',
                  style:
                      GoogleFonts.tajawal(fontSize: 11, color: context.cMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
            onPressed: () => _removeFile(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Options card ──────────────────────────────────────────
  Widget _buildOptionsCard() {
    final bool isA5 = _pageSize == 'A5';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚙️ خيارات الطباعة',
              style: GoogleFonts.tajawal(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildOptionRow(
              label: '📐 قياس الصفحة',
              options: const ['A3', 'A4', 'B5', 'A5'],
              selected: _pageSize,
              onSelect: (v) => setState(() {
                _pageSize = v;
                if (v == 'A5') _sides = 'two';
              }),
            ),
            const SizedBox(height: 10),
            _buildSizeComparisonWidget(),
            const SizedBox(height: 12),
            _buildOptionRow(
              label: '🔄 الوجوه',
              options: isA5 ? const ['two'] : const ['one', 'two'],
              labels: isA5 ? const ['وجهان'] : const ['وجه واحد', 'وجهان'],
              selected: _sides,
              onSelect: (v) => setState(() => _sides = v),
              subtitle: isA5 ? 'A5 يتطلب الطباعة على وجهين' : null,
            ),
            const SizedBox(height: 12),
            _buildOptionRow(
              label: '🎨 اللون',
              options: const ['bw', 'color'],
              labels: const ['أبيض وأسود', 'ملون'],
              selected: _color,
              onSelect: (v) => setState(() => _color = v),
            ),
            const SizedBox(height: 12),
            _buildOptionRow(
              label: '📎 التجليد',
              options: const ['none', 'staple', 'spiral'],
              labels: const ['بدون', 'تسليك', 'خرز'],
              selected: _binding,
              onSelect: (v) => setState(() => _binding = v),
            ),
            const SizedBox(height: 12),
            Text('🗂️ عدد النسخ',
                style:
                    GoogleFonts.tajawal(fontSize: 13, color: context.cMuted)),
            const SizedBox(height: 6),
            Row(
              children: [
                _counterButton(Icons.remove, () {
                  if (_copies > 1) setState(() => _copies--);
                }),
                const SizedBox(width: 16),
                Text('$_copies',
                    style: GoogleFonts.tajawal(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                _counterButton(Icons.add, () => setState(() => _copies++)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Paper size comparison widget ──────────────────────────
  static const _paperSizes = {
    'A3': (297.0, 420.0),
    'A4': (210.0, 297.0),
    'B5': (176.0, 250.0),
    'A5': (148.0, 210.0),
  };

  static String _fmtCm(double mm) {
    final cm = mm / 10;
    return cm == cm.truncateToDouble() ? '${cm.truncate()}' : cm.toStringAsFixed(1);
  }

  Widget _buildSizeComparisonWidget() {
    const scale = 85.0 / 420.0; // A3 height = 85px
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.cFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cFill),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _paperSizes.entries.map((e) {
          final wPx = e.value.$1 * scale;
          final hPx = e.value.$2 * scale;
          final isSelected = _pageSize == e.key;
          final wCm = _fmtCm(e.value.$1);
          final hCm = _fmtCm(e.value.$2);
          final color = isSelected ? _primary : Colors.grey.shade400;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // width label on top
              SizedBox(
                width: wPx + 16,
                child: Text(
                  '$wCm سم',
                  style: GoogleFonts.tajawal(
                    fontSize: 8,
                    color: isSelected ? _primary : context.cFaint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 2),
              // paper box + height label side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: wPx,
                    height: hPx,
                    decoration: BoxDecoration(
                      color: isSelected ? _primary.withAlpha(35) : Colors.white,
                      border: Border.all(
                        color: color,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: isSelected
                        ? Center(child: Icon(Icons.check, color: _primary, size: hPx * 0.28))
                        : null,
                  ),
                  const SizedBox(width: 3),
                  RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      '$hCm سم',
                      style: GoogleFonts.tajawal(
                        fontSize: 8,
                        color: isSelected ? _primary : context.cFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                e.key,
                style: GoogleFonts.tajawal(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? _primary : context.cMuted,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _primary.withAlpha(20),
          shape: BoxShape.circle,
          border: Border.all(color: _primary.withAlpha(80)),
        ),
        child: Icon(icon, color: _primary, size: 18),
      ),
    );
  }

  Widget _buildOptionRow({
    required String label,
    required List<String> options,
    List<String>? labels,
    required String selected,
    required ValueChanged<String> onSelect,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: GoogleFonts.tajawal(
                    fontSize: 13, color: context.cMuted)),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subtitle,
                  style: GoogleFonts.tajawal(
                      fontSize: 10, color: Colors.orange.shade800),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options.asMap().entries.map((entry) {
            final value = entry.value;
            final display = labels?[entry.key] ?? value;
            final isSelected = selected == value;
            return GestureDetector(
              onTap: () => onSelect(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : _primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _primary : _primary.withAlpha(60),
                  ),
                ),
                child: Text(
                  display,
                  style: GoogleFonts.tajawal(
                    color: isSelected ? Colors.white : _primary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Notes card ───────────────────────────────────────────
  Widget _buildNotesCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '📝 ملاحظات (اختياري)',
              style: GoogleFonts.tajawal(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'مثال: اطبع الصفحة الأولى بالألوان فقط...',
                hintStyle: GoogleFonts.tajawal(color: context.cFaint),
                filled: true,
                fillColor: context.cFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Price summary card ────────────────────────────────────
  Widget _buildPriceSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '💰 ملخص السعر',
            style: GoogleFonts.tajawal(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800),
          ),
          const SizedBox(height: 10),
          _priceRow('عدد الملفات', '${_files.length} ملف'),
          _priceRow('إجمالي الصفحات', '$_totalPageCount صفحة'),
          _priceRow('سعر الصفحة', '${_pricePerPage.toStringAsFixed(0)} ل.س'),
          if (_bindingFee > 0)
            _priceRow('التجليد', '${_bindingFee.toStringAsFixed(0)} ل.س'),
          _priceRow('عدد النسخ', '$_copies نسخة'),
          const Divider(height: 16, color: Colors.green),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإجمالي',
                  style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green.shade900)),
              Text(
                '${_total.toStringAsFixed(0)} ل.س',
                style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: _primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.tajawal(
                    color: context.cMuted, fontSize: 13)),
            Text(value,
                style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  // ── Bottom bar ────────────────────────────────────────────
  Widget _buildAddToCartBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      decoration: BoxDecoration(
        color: context.cSurface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _addingToCart ? null : _addToCart,
          icon: _addingToCart
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.shopping_cart_outlined),
          label: Text(
            _addingToCart ? 'جاري الرفع...' : 'أضف للسلة',
            style: GoogleFonts.tajawal(
                fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}
