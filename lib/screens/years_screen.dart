import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../data.dart';
import '../widgets/app_drawer.dart';
import 'products_list_screen.dart';

class _SemesterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SemesterButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.tajawal(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YearsScreen extends StatelessWidget {
  final CategoryItem category;

  const YearsScreen({super.key, required this.category});

  void _showSemesterSheet(BuildContext context, String year) {
    const primary = Color(0xFF00827E);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              year,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'اختر الفصل الدراسي',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 14.0, color: context.cFaint),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SemesterButton(
                    label: 'الفصل الأول',
                    icon: Icons.looks_one_outlined,
                    color: primary,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductsListScreen(
                            category: category,
                            year: year,
                            semester: 'الفصل الأول',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SemesterButton(
                    label: 'الفصل الثاني',
                    icon: Icons.looks_two_outlined,
                    color: primary,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductsListScreen(
                            category: category,
                            year: year,
                            semester: 'الفصل الثاني',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.title),
        leading: const MenuButton(),

        actions: const [LogoAction()],
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              category.subtitle,
              style: GoogleFonts.tajawal(fontSize: 16.0, color: context.cMuted),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: category.years.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final year = category.years[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      title: Text(
                        year,
                        style: GoogleFonts.tajawal(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'اضغط لعرض النوطات المتاحة',
                        style: GoogleFonts.tajawal(fontSize: 13.0),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () => _showSemesterSheet(context, year),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
