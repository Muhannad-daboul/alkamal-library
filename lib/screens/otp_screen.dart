import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../main.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String displayPhone; // للعرض فقط مثل +963 9XX XXX XXX
  final String e164Phone;    // للإرسال مثل +9639xxxxxxxx
  final String name;
  final String specialty;
  final int? resendToken;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.displayPhone,
    required this.e164Phone,
    required this.name,
    required this.specialty,
    this.resendToken,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _primary = Color(0xFF00827E);

  late String _verificationId;
  int? _resendToken;

  final _controllers = List<TextEditingController>.generate(6, (_) => TextEditingController());
  final _focusNodes  = List<FocusNode>.generate(6, (_) => FocusNode());

  int  _secondsLeft = 60;
  Timer? _timer;
  bool _verifying = false;
  bool _resending  = false;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken    = widget.resendToken;
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNodes.first.requestFocus(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes)  { f.dispose(); }
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── OTP boxes ─────────────────────────────────────────────
  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onBoxChanged(int index, String val) {
    if (val.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_otpCode.length == 6) _verify();
      }
    } else {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
    setState(() {}); // refresh verify button state
  }

  // ── Verify ────────────────────────────────────────────────
  Future<void> _verify() async {
    final code = _otpCode;
    if (code.length < 6) return;
    setState(() => _verifying = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      userProfileNotifier.value = UserProfile(
        name:      widget.name,
        phone:     widget.displayPhone,
        specialty: widget.specialty,
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      _showError(e.message ?? 'رمز غير صحيح، تحقق وأعد المحاولة');
      for (final c in _controllers) { c.clear(); }
      _focusNodes.first.requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() => _verifying = false);
      _showError('حدث خطأ، حاول مجدداً');
    }
  }

  // ── Resend ────────────────────────────────────────────────
  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.e164Phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (cred) async {
          await FirebaseAuth.instance.signInWithCredential(cred);
          if (!mounted) return;
          userProfileNotifier.value = UserProfile(
            name:      widget.name,
            phone:     widget.displayPhone,
            specialty: widget.specialty,
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => _resending = false);
          _showError(e.message ?? 'فشل إعادة الإرسال');
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken    = resendToken;
            _resending      = false;
          });
          _startTimer();
          for (final c in _controllers) { c.clear(); }
          _focusNodes.first.requestFocus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إرسال الرمز مجدداً', style: GoogleFonts.tajawal()),
              backgroundColor: _primary,
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _resending = false);
      _showError('تعذّر إعادة الإرسال');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.tajawal()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ready = _otpCode.length == 6;
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
          child: Column(
            children: [
              // ── أيقونة القفل ──
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: _primary, size: 40),
              ),
              const SizedBox(height: 24),

              Text(
                'أدخل رمز التحقق',
                style: GoogleFonts.tajawal(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'أُرسل رمز مكوّن من 6 أرقام إلى',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                    fontSize: 14, color: context.cMuted),
              ),
              const SizedBox(height: 6),

              // ── رقم الهاتف + تغيير ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.displayPhone,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'تغيير',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: Colors.blue.shade600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.blue.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // ── صناديق الـ OTP ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _controllers[i],
                  focusNode:  _focusNodes[i],
                  onChanged:  (v) => _onBoxChanged(i, v),
                )),
              ),
              const SizedBox(height: 36),

              // ── عداد / إعادة إرسال ──
              if (_secondsLeft > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'إعادة الإرسال بعد ',
                      style: GoogleFonts.tajawal(
                          fontSize: 13, color: context.cFaint),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_secondsLeft ث',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          color: _primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: _resending ? null : _resend,
                  icon: _resending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _primary),
                        )
                      : const Icon(Icons.refresh, color: _primary, size: 18),
                  label: Text(
                    'إعادة إرسال الرمز',
                    style: GoogleFonts.tajawal(color: _primary, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 36),

              // ── زر التأكيد ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_verifying || !ready) ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withAlpha(70),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'تأكيد',
                          style: GoogleFonts.tajawal(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  صندوق OTP واحد
// ═══════════════════════════════════════════════
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  static const _primary = Color(0xFF00827E);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller:     controller,
        focusNode:      focusNode,
        textAlign:      TextAlign.center,
        maxLength:      1,
        keyboardType:   TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.tajawal(
            fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText:    '',
          contentPadding: EdgeInsets.zero,
          filled:         true,
          fillColor:      controller.text.isEmpty
              ? context.cFill
              : _primary.withAlpha(15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: controller.text.isNotEmpty
                  ? _primary
                  : Colors.grey.shade300,
              width: controller.text.isNotEmpty ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
