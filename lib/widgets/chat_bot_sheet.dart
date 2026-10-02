import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatBotSheet extends StatelessWidget {
  const ChatBotSheet({super.key});

  static const _faqs = [
    _Faq(
      question: 'ما هي أوقات عمل المكتبة؟',
      answer: 'تعمل المكتبة من الساعة 8:00 صباحاً حتى 5:00 مساءً.',
    ),
    _Faq(
      question: 'كيف أطلب محاضرة؟',
      answer:
          'افتح قسم "الأرشيف" من الشريط السفلي، اختر كليتك والسنة الدراسية، '
          'ثم اضغط على المحاضرة التي تريدها وأضفها إلى السلة. '
          'بعدها اكمل الطلب من السلة وأدخل عنوان التوصيل.',
    ),
    _Faq(
      question: 'كم يستغرق التوصيل؟',
      answer:
          'يعتمد على منطقتك وحجم الطلبات. الطلبات المقدمة أثناء دوام المكتبة '
          '(8 ص – 5 م) تُوصَّل عادةً في نفس اليوم، '
          'أما الطلبات بعد الدوام فقد تُوصَّل في اليوم التالي.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, sc) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            // ── header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: primary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الأسئلة الشائعة',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ── faq list ──
            Expanded(
              child: ListView.separated(
                controller: sc,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _faqs.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (_, i) => _FaqTile(faq: _faqs[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Faq {
  final String question;
  final String answer;
  const _Faq({required this.question, required this.answer});
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq});
  final _Faq faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.faq.question,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: primary),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeIn,
              crossFadeState:
                  _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.faq.answer,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.tajawal(
                    fontSize: 13.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
