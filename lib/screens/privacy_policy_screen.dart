import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _primary = Color(0xFF00827E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سياسة الخصوصية', style: GoogleFonts.tajawal()),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _header('مكتبة الكمال الطبية تحترم خصوصيتك'),
          const SizedBox(height: 14),
          _paragraph(
            context,
            'هذه السياسة توضح كيف نجمع ونستخدم ونحمي بياناتك الشخصية عند استخدامك للتطبيق.',
          ),
          const SizedBox(height: 24),
          _section(context, '1. البيانات التي نجمعها'),
          _bullet(context, 'اسمك الكامل ورقم هاتفك (لإتمام الطلبات).'),
          _bullet(context, 'عنوان التوصيل وإحداثيات الموقع (لتوصيل الطلبات فقط).'),
          _bullet(context, 'ملفات PDF والصور التي ترفعها للطباعة (تُحفظ بشكل آمن).'),
          _bullet(context, 'بيانات الطلبات والتقييمات التي تقدمها.'),
          const SizedBox(height: 16),
          _section(context, '2. كيف نستخدم بياناتك'),
          _bullet(context, 'تنفيذ طلباتك وتوصيلها لك.'),
          _bullet(context, 'التواصل معك بشأن حالة الطلب.'),
          _bullet(context, 'تحسين خدماتنا وتجربة المستخدم.'),
          _bullet(context, 'إرسال إشعارات مهمة (تأكيد الطلب، التوصيل).'),
          const SizedBox(height: 16),
          _section(context, '3. حماية بياناتك'),
          _paragraph(
            context,
            'نستخدم خدمات Firebase من Google التي توفر تشفيراً عالياً للبيانات أثناء النقل والتخزين. لا نشارك بياناتك مع أي طرف ثالث لأغراض تسويقية.',
          ),
          const SizedBox(height: 16),
          _section(context, '4. الملفات المرفوعة للطباعة'),
          _paragraph(
            context,
            'الملفات التي ترفعها للطباعة تُخزَّن مؤقتاً لإتمام الطلب فقط، ولا يمكن لأي مستخدم آخر الوصول إليها. يمكنك طلب حذفها في أي وقت.',
          ),
          const SizedBox(height: 16),
          _section(context, '5. حقوقك'),
          _bullet(context, 'الاطلاع على بياناتك المخزنة.'),
          _bullet(context, 'طلب تعديل أو حذف بياناتك.'),
          _bullet(context, 'سحب موافقتك على معالجة بياناتك.'),
          const SizedBox(height: 16),
          _section(context, '6. التواصل معنا'),
          _paragraph(
            context,
            'لأي استفسار حول الخصوصية أو لطلب حذف بياناتك، تواصل مع إدارة المكتبة عبر صفحة "من نحن".',
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              'آخر تحديث: 2026/06/06',
              style: GoogleFonts.tajawal(
                color: context.cFaint,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _header(String text) => Text(
        text,
        style: GoogleFonts.tajawal(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _primary,
        ),
      );

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.tajawal(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.cText,
          ),
        ),
      );

  Widget _paragraph(BuildContext context, String text) => Text(
        text,
        style: GoogleFonts.tajawal(
          fontSize: 13,
          color: context.cMuted,
          height: 1.7,
        ),
      );

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.circle, size: 6, color: _primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  color: context.cMuted,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
}
