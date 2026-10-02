import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const _primary = Color(0xFF00827E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('من نحن', style: GoogleFonts.tajawal()),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // الشعار + الاسم
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primary.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withAlpha(40),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      color: _primary,
                      colorBlendMode: BlendMode.srcIn,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.local_pharmacy,
                        color: _primary,
                        size: 50,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'مكتبة الكمال الطبية',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'وجهتك الأولى للمستلزمات الطبية والمحاضرات',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    color: context.cMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // قصتنا
          _section(
            context,
            icon: Icons.menu_book_outlined,
            title: 'قصتنا',
            content:
                'تأسست مكتبة الكمال الطبية لتكون شريكاً موثوقاً لطلاب الكليات الطبية في سوريا. نوفّر المحاضرات والنوطات الجامعية والمستلزمات الطبية بأسعار مناسبة وجودة عالية.',
          ),
          const SizedBox(height: 16),

          _section(
            context,
            icon: Icons.flag_outlined,
            title: 'رؤيتنا',
            content:
                'أن نكون الخيار الأول لطلاب الطب والصيدلة وطب الأسنان في سوريا من خلال خدمات سريعة وملائمة لاحتياجاتهم.',
          ),
          const SizedBox(height: 16),

          _section(
            context,
            icon: Icons.handshake_outlined,
            title: 'ما نقدمه',
            content: '',
            bullets: const [
              'محاضرات ونوطات جامعية لجميع السنوات',
              'مستلزمات طبية احترافية',
              'خدمة طباعة سريعة وتسليم للموقع',
              'دعم مباشر عبر التطبيق',
            ],
          ),
          const SizedBox(height: 24),

          // معلومات التواصل
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primary.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تواصل معنا',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.cText,
                  ),
                ),
                const SizedBox(height: 12),
                _contactRow(
                  context,
                  icon: Icons.phone_outlined,
                  text: '+963 11 1234567',
                  onTap: () =>
                      launchUrl(Uri.parse('tel:+963111234567')),
                ),
                _contactRow(
                  context,
                  icon: Icons.location_on_outlined,
                  text: 'دمشق — المزة، شارع الجلاء',
                ),
                _contactRow(
                  context,
                  icon: Icons.access_time_outlined,
                  text: 'السبت — الخميس: 9 صباحاً — 9 مساءً',
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              'الإصدار 1.0.0',
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

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    List<String>? bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.cText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (content.isNotEmpty)
            Text(
              content,
              style: GoogleFonts.tajawal(
                fontSize: 13,
                color: context.cMuted,
                height: 1.7,
              ),
            ),
          if (bullets != null)
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child:
                            Icon(Icons.check_circle, size: 14, color: _primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: context.cMuted,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _contactRow(
    BuildContext context, {
    required IconData icon,
    required String text,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  color: context.cText,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios, size: 14, color: context.cFaint),
          ],
        ),
      ),
    );
  }
}
