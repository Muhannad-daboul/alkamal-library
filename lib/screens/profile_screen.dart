import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../main.dart';
import '../widgets/app_drawer.dart';
import 'about_us_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('حسابي'),
        automaticallyImplyLeading: false,
        leading: const MenuButton(),

        actions: const [LogoAction()],
      ),
      drawer: const AppDrawer(),
      body: ValueListenableBuilder<UserProfile>(
        valueListenable: userProfileNotifier,
        builder: (context, profile, _) => _ProfileBody(profile: profile),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserProfile profile;
  const _ProfileBody({required this.profile});

  Future<void> _pickPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    userProfileNotifier.value = userProfileNotifier.value.copyWith(
      photoBytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Profile photo
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: primary.withAlpha(30),
                backgroundImage: profile.photoBytes != null
                    ? MemoryImage(profile.photoBytes!)
                    : null,
                child: profile.photoBytes == null
                    ? Text(
                        profile.name.isNotEmpty ? profile.name[0] : '؟',
                        style: GoogleFonts.tajawal(
                          fontSize: 40.0,
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: GestureDetector(
                  onTap: () => _pickPhoto(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            profile.name,
            style: GoogleFonts.tajawal(
              fontSize: 28.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            profile.specialty,
            style: GoogleFonts.tajawal(
              fontSize: 15.0,
              color: primary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 28),

          // Support card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.support_agent_outlined,
                    size: 64,
                    color: Color(0xFF00827E),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'الدعم',
                    style: GoogleFonts.tajawal(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'متاح يومياً كل أيام الأسبوع عدا يوم الجمعة\nمن 8:00 صباحاً وحتى 6:00 مساءً',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(fontSize: 15.0, color: context.cMuted),
                  ),
                  const SizedBox(height: 18),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => launchUrl(
                      Uri.parse('tel:+96309440422766'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone, color: Color(0xFF00827E), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '+963 09440422766',
                            style: GoogleFonts.tajawal(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00827E),
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF00827E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      'المعلومات الشخصية',
                      style: GoogleFonts.tajawal(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _infoTile(context, Icons.person_outline, 'الاسم الكامل', profile.name),
                  _infoTile(
                    context,
                    Icons.school_outlined,
                    'الاختصاص',
                    profile.specialty,
                  ),
                  _infoTile(
                    context,
                    Icons.phone_outlined,
                    'رقم الموبايل',
                    profile.phone,
                    valueDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Edit button
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text('تعديل المعلومات'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 16),

          // ── Appearance / theme selector ─────────────────
          const _ThemeSelectorCard(),

          const SizedBox(height: 8),

          // ── Footer ──────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 16, bottom: 8),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 56,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                  errorBuilder: (ctx, e, st) => const Icon(
                    Icons.local_pharmacy,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'مكتبة الكمال الطبية',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://wa.me/963944042766'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: Text(
                      'تواصل معنا على واتساب',
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                      ),
                      child: Text(
                        'من نحن',
                        style: GoogleFonts.tajawal(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    Text('·',
                        style: GoogleFonts.tajawal(
                            color: Colors.white38, fontSize: 16)),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen()),
                      ),
                      child: Text(
                        'سياسة الخصوصية',
                        style: GoogleFonts.tajawal(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2026 مكتبة الكمال الطبية. جميع الحقوق محفوظة',
                  style: GoogleFonts.tajawal(
                      color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Developed by Muhannad Daboul',
                  style: GoogleFonts.tajawal(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          TextButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('تأكيد الخروج', style: GoogleFonts.tajawal()),
                  content: Text('هل تريد تسجيل الخروج؟', style: GoogleFonts.tajawal()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('إلغاء', style: GoogleFonts.tajawal()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('خروج', style: GoogleFonts.tajawal(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_profile');
              userProfileNotifier.value = UserProfile(name: '', specialty: '', phone: '');
              hasOnboarded = false;
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (_) => false);
              }
            },
            icon: const Icon(Icons.logout, color: Colors.red, size: 18),
            label: Text(
              'تسجيل الخروج',
              style: GoogleFonts.tajawal(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    TextDirection? valueDirection,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: context.cFaint),
      title: Text(
        label,
        style: GoogleFonts.tajawal(fontSize: 12.0, color: context.cFaint),
      ),
      subtitle: Text(
        value,
        textDirection: valueDirection,
        style: GoogleFonts.tajawal(fontSize: 15.0, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Theme selector ──────────────────────────────────────────
class _ThemeSelectorCard extends StatelessWidget {
  const _ThemeSelectorCard();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.brightness_6_outlined, size: 20, color: primary),
                const SizedBox(width: 8),
                Text(
                  'مظهر التطبيق',
                  style: GoogleFonts.tajawal(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (context, mode, _) => Row(
                children: [
                  Expanded(
                    child: _ThemeOption(
                      icon: Icons.light_mode_outlined,
                      label: 'فاتح',
                      selected: mode == ThemeMode.light,
                      onTap: () => themeModeNotifier.value = ThemeMode.light,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeOption(
                      icon: Icons.dark_mode_outlined,
                      label: 'داكن',
                      selected: mode == ThemeMode.dark,
                      onTap: () => themeModeNotifier.value = ThemeMode.dark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeOption(
                      icon: Icons.brightness_auto_outlined,
                      label: 'النظام',
                      selected: mode == ThemeMode.system,
                      onTap: () => themeModeNotifier.value = ThemeMode.system,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final borderColor = selected ? primary : Theme.of(context).dividerColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? primary.withAlpha(28) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: selected ? primary : Colors.grey),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.tajawal(
                fontSize: 13.0,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
