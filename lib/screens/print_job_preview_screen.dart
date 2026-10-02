import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';

class PrintJobPreviewScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;

  const PrintJobPreviewScreen({
    super.key,
    required this.fileUrl,
    required this.fileName,
  });

  @override
  State<PrintJobPreviewScreen> createState() => _PrintJobPreviewScreenState();
}

class _PrintJobPreviewScreenState extends State<PrintJobPreviewScreen> {
  static const _primary = Color(0xFF00827E);

  PdfControllerPinch? _pdfController;
  Uint8List? _imageBytes;
  String? _error;
  bool _loading = true;
  int _currentPage = 1;
  int _totalPages = 0;

  bool get _isImage {
    final url = widget.fileUrl.toLowerCase();
    final path = url.split('?').first;
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await _download(widget.fileUrl);
      if (!mounted) return;
      if (_isImage) {
        setState(() {
          _imageBytes = bytes;
          _loading = false;
        });
      } else {
        final doc = PdfDocument.openData(bytes);
        final ctrl = PdfControllerPinch(document: doc);
        if (!mounted) return;
        setState(() {
          _pdfController = ctrl;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Uint8List> _download(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = true;
      final response = await request.close();
      return Uint8List.fromList(
        await response.fold<List<int>>([], (buf, chunk) => buf..addAll(chunk)),
      );
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              style: GoogleFonts.tajawal(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'صفحة $_currentPage من $_totalPages',
                style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white60),
              ),
          ],
        ),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: _primary),
                  const SizedBox(height: 16),
                  Text(
                    'جاري تحميل الملف...',
                    style: GoogleFonts.tajawal(color: Colors.white60),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'تعذّر فتح الملف',
                          style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: GoogleFonts.tajawal(
                              color: Colors.white38, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
          : _imageBytes != null
              ? InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Center(
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : PdfViewPinch(
                  controller: _pdfController!,
                  onDocumentLoaded: (doc) {
                    if (mounted) setState(() => _totalPages = doc.pagesCount);
                  },
                  onPageChanged: (page) {
                    if (mounted) setState(() => _currentPage = page);
                  },
                  scrollDirection: Axis.vertical,
                  builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                    options: const DefaultBuilderOptions(),
                    documentLoaderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                    pageLoaderBuilder: (_) => const SizedBox(),
                    errorBuilder: (_, e) => Center(
                      child: Text(e.toString(),
                          style: GoogleFonts.tajawal(color: Colors.white38)),
                    ),
                  ),
                ),
    );
  }
}
