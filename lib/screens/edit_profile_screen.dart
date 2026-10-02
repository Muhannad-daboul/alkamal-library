import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../data.dart';
import '../main.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  String? _selectedCollege;
  String? _selectedYear;

  // College → Years mapping (from data.dart)
  final Map<String, List<String>> _collegeYears = {
    for (final c in categories) c.title: c.years,
  };

  @override
  void initState() {
    super.initState();
    final p = userProfileNotifier.value;
    _nameCtrl = TextEditingController(text: p.name);
    _phoneCtrl = TextEditingController(text: p.phone);

    // Parse existing specialty "كلية الطب - السنة الثالثة"
    // تحقق أن الكلية المحفوظة موجودة فعلاً بالقائمة
    final parts = p.specialty.split(' - ');
    if (parts.length == 2 && _collegeYears.containsKey(parts[0])) {
      _selectedCollege = parts[0];
      // تحقق أن السنة موجودة بقائمة سنوات تلك الكلية
      final years = _collegeYears[parts[0]] ?? [];
      if (years.contains(parts[1])) {
        _selectedYear = parts[1];
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  List<String> get _availableYears =>
      _selectedCollege != null ? (_collegeYears[_selectedCollege] ?? []) : [];

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCollege == null) {
      _showError('يرجى اختيار الكلية');
      return;
    }
    if (_selectedYear == null) {
      _showError('يرجى اختيار السنة');
      return;
    }

    userProfileNotifier.value = userProfileNotifier.value.copyWith(
      name: _nameCtrl.text.trim(),
      specialty: '$_selectedCollege - $_selectedYear',
      phone: _phoneCtrl.text.trim(),
    );

    // احفظ الـ messenger قبل pop لأن الـ context لن يكون صالحاً بعدها
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('تم حفظ المعلومات بنجاح'),
        backgroundColor: Color(0xFF00827E),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('تعديل المعلومات'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'حفظ',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Name
              _textField(
                controller: _nameCtrl,
                label: 'الاسم الكامل',
                icon: Icons.person_outline,
                primary: primary,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),

              const SizedBox(height: 20),

              // College dropdown
              _dropdownField(
                label: 'الكلية',
                icon: Icons.school_outlined,
                value: _selectedCollege,
                items: _collegeYears.keys.toList(),
                primary: primary,
                onChanged: (val) => setState(() {
                  _selectedCollege = val;
                  _selectedYear = null; // reset year on college change
                }),
              ),

              const SizedBox(height: 20),

              // Year dropdown (enabled only after college selected)
              _dropdownField(
                label: 'السنة الدراسية',
                icon: Icons.calendar_today_outlined,
                value: _selectedYear,
                items: _availableYears,
                primary: primary,
                enabled: _selectedCollege != null,
                hint: _selectedCollege == null
                    ? 'اختر الكلية أولاً'
                    : 'اختر السنة',
                onChanged: (val) => setState(() => _selectedYear = val),
              ),

              const SizedBox(height: 20),

              // Phone
              _textField(
                controller: _phoneCtrl,
                label: 'رقم الموبايل',
                icon: Icons.phone_outlined,
                primary: primary,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'رقم الموبايل مطلوب'
                    : null,
              ),

              const SizedBox(height: 36),

              ElevatedButton(onPressed: _save, child: Text('حفظ التغييرات')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primary,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Color primary,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
    String? hint,
  }) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? primary : Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        filled: !enabled,
        fillColor: enabled ? null : context.cFill,
      ),
      hint: Text(
        hint ?? 'اختر...',
        style: GoogleFonts.tajawal(color: context.cFaint),
      ),
      items: enabled
          ? items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList()
          : [],
      onChanged: enabled ? onChanged : null,
    );
  }
}
