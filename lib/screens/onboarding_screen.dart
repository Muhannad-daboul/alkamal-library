import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../main.dart';
import '../services/firestore_service.dart';

/// يفتح تطبيق تيليجرام مباشرة عبر tg:// (يتجاوز حجب نطاق t.me على
/// بعض الشبكات السورية). إذا فشل (تيليجرام غير منصّب أو منصة ويب)
/// يرجع لرابط t.me العادي.
Future<void> _launchTelegram(Uri tgUri, Uri webUri) async {
  var opened = false;
  if (!kIsWeb) {
    try {
      opened = await launchUrl(tgUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (!opened) {
    await launchUrl(
      webUri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }
}

const _specialties = [
  'كلية الطب',
  'كلية الصيدلة',
  'كلية طب الأسنان',
  'السنة التحضيرية',
  'أخرى',
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _primary = Color(0xFF00827E);

  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _selectedSpecialty;
  bool    _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _displayPhone(String local) {
    final digits = local.startsWith('0') ? local.substring(1) : local;
    return '+963 $digits';
  }

  // ── تسجيل الدخول عبر تيليجرام ──────────────────────────────
  Future<void> _startTelegramAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final name = _nameCtrl.text.trim();
    final phone = _displayPhone(_phoneCtrl.text.trim());
    final specialty = _selectedSpecialty ?? _specialties.first;

    try {
      final session = await FirestoreService.startTelegramLogin(
        name: name,
        phone: phone,
        specialty: specialty,
      );

      final botUrl = Uri.parse(
        'https://t.me/${session.botUsername}?start=${session.sessionId}',
      );
      final tgUrl = Uri.parse(
        'tg://resolve?domain=${session.botUsername}&start=${session.sessionId}',
      );
      await _launchTelegram(tgUrl, botUrl);

      if (!mounted) return;
      // شاشة انتظار تتابع الجلسة وتسجّل الدخول تلقائياً عند التأكيد.
      // ترجع الرقم الموثّق من تيليجرام (null إذا أُلغيت أو فشلت).
      final verifiedPhone = await showModalBottomSheet<String>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TelegramWaitingSheet(
          sessionId: session.sessionId,
          botUrl: botUrl,
          tgUrl: tgUrl,
        ),
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (verifiedPhone != null) {
        userProfileNotifier.value = UserProfile(
          name: name,
          phone: verifiedPhone.isNotEmpty ? verifiedPhone : phone,
          specialty: specialty,
        );
        hasOnboarded = true;
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذّر بدء تسجيل الدخول، حاول مجدداً',
            style: GoogleFonts.tajawal(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // ── شعار ──
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 90,
                    color: _primary,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (ctx, e, st) =>
                        const Icon(Icons.local_pharmacy,
                            size: 80, color: _primary),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'مرحباً بك في مكتبة الكمال الطبية',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 36),

                // ── الاسم ──
                _label('الاسم الكامل'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: _inputDec('أدخل اسمك الكامل', Icons.person_outline),
                  style: GoogleFonts.tajawal(),
                  validator: (v) =>
                      (v == null || v.trim().length < 2)
                          ? 'يرجى إدخال الاسم'
                          : null,
                ),
                const SizedBox(height: 18),

                // ── التخصص ──
                _label('التخصص'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSpecialty,
                  decoration: _inputDec('اختر تخصصك', Icons.school_outlined),
                  style: GoogleFonts.tajawal(
                      fontSize: 14, color: context.cText),
                  items: _specialties
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, style: GoogleFonts.tajawal()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSpecialty = v),
                  validator: (v) =>
                      v == null ? 'يرجى اختيار التخصص' : null,
                ),
                const SizedBox(height: 18),

                // ── رقم الهاتف (سوري +963) ──
                _label('رقم الهاتف'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: _inputDec('09XXXXXXXX', Icons.phone_outlined).copyWith(
                    prefixIcon: null,
                    prefix: Padding(
                      padding: const EdgeInsets.only(right: 12, left: 4),
                      child: Text(
                        '🇸🇾 +963',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.cText,
                        ),
                      ),
                    ),
                  ),
                  style: GoogleFonts.tajawal(
                      letterSpacing: 1, fontSize: 15),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'أدخل رقم الهاتف';
                    if (!RegExp(r'^09\d{8}$').hasMatch(t)) {
                      return 'أدخل رقم موبايل سوري صحيح (09XXXXXXXX)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'مثال: 0936546825',
                  textDirection: TextDirection.ltr,
                  style: GoogleFonts.tajawal(
                      fontSize: 12, color: context.cFaint),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 36),

                // ── زر المتابعة عبر تيليجرام ──
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _startTelegramAuth,
                    icon: _loading
                        ? const SizedBox.shrink()
                        : const FaIcon(FontAwesomeIcons.telegram, size: 20),
                    label: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'المتابعة عبر تيليجرام',
                            style: GoogleFonts.tajawal(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF229ED9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor:
                          const Color(0xFF229ED9).withAlpha(120),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'سنرسل لك رابط بوت تيليجرام لتأكيد حسابك بضغطة واحدة.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                      fontSize: 12, color: context.cFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w600, fontSize: 14),
      );

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.tajawal(color: context.cFaint, fontSize: 14),
        prefixIcon: Icon(icon, color: context.cFaint, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: Color(0xFF00827E), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
//  شاشة انتظار تأكيد تيليجرام — تتابع الجلسة لحظياً وتسجّل
//  الدخول تلقائياً عند التحقق، ثم تُغلق بنتيجة النجاح.
// ═══════════════════════════════════════════════════════════
class _TelegramWaitingSheet extends StatefulWidget {
  final String sessionId;
  final Uri botUrl;
  final Uri tgUrl;

  const _TelegramWaitingSheet({
    required this.sessionId,
    required this.botUrl,
    required this.tgUrl,
  });

  @override
  State<_TelegramWaitingSheet> createState() => _TelegramWaitingSheetState();
}

class _TelegramWaitingSheetState extends State<_TelegramWaitingSheet> {
  static const _telegramBlue = Color(0xFF229ED9);

  StreamSubscription<String>? _sub;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _sub = FirestoreService.telegramSessionStatus(widget.sessionId)
        .listen(_onStatus);
  }

  Future<void> _onStatus(String status) async {
    if (status != 'verified' || _signingIn) return;
    _signingIn = true;
    await _sub?.cancel();
    try {
      final claim =
          await FirestoreService.claimTelegramSession(widget.sessionId);
      await FirebaseAuth.instance.signInWithCustomToken(claim.token);
      if (!mounted) return;
      // نرجّع الرقم الموثّق من تيليجرام ليُعتمد في الملف الشخصي
      Navigator.of(context).pop(claim.phone);
    } catch (_) {
      if (!mounted) return;
      _signingIn = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر إكمال تسجيل الدخول، حاول مجدداً',
              style: GoogleFonts.tajawal()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: context.cFill,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: _telegramBlue.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const FaIcon(FontAwesomeIcons.telegram,
                color: _telegramBlue, size: 44),
          ),
          const SizedBox(height: 24),
          Text(
            'بانتظار التأكيد عبر تيليجرام',
            style: GoogleFonts.tajawal(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'افتح البوت واضغط «Start»، ثم اضغط زر «📱 مشاركة رقمي» لتوثيق رقمك، وسننقلك تلقائياً.',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(fontSize: 13, color: context.cMuted),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: _telegramBlue),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _launchTelegram(widget.tgUrl, widget.botUrl),
              icon: const FaIcon(FontAwesomeIcons.telegram, size: 18),
              label: Text('فتح تيليجرام مجدداً',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _telegramBlue,
                side: const BorderSide(color: _telegramBlue),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إلغاء',
                style: GoogleFonts.tajawal(color: context.cMuted)),
          ),
        ],
      ),
    );
  }
}
