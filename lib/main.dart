import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firestore_service.dart';
import 'services/orders_watcher.dart';

// ── Global notifiers ──────────────────────────────────────
final tabIndexNotifier    = ValueNotifier<int>(2); // Home = center (index 2)
final cartNotifier        = ValueNotifier<List<CartItem>>([]);
final userProfileNotifier = ValueNotifier<UserProfile>(
  UserProfile(name: '', specialty: '', phone: ''),
);
final pricePerPageNotifier = ValueNotifier<double>(100.0);
final ordersUnseenNotifier = ValueNotifier<int>(0);

// وضع السمة (فاتح / داكن / حسب النظام) — محفوظ في SharedPreferences
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

// يصبح true لما يكون في action bar للتحديد في شاشة الأرشيف،
// مشان زر الـ chat يرتفع لفوق ولا يتداخل معه.
final lectureSelectionActiveNotifier = ValueNotifier<bool>(false);

// يصبح true إذا وُجد ملف مستخدم محفوظ من جلسة سابقة
bool hasOnboarded = false;

// FCM token الخاص بالجهاز — يُرسل مع كل طلب
String? deviceFcmToken;

// ── Cart model ────────────────────────────────────────────
class CartItem {
  final String id;
  final String title;
  final double price;
  int quantity;
  final bool isSupply;
  final String imageUrl;
  final bool isPrintJob;
  final String printJobStoragePath;
  final String printJobNotes;
  final bool isLecture;
  final String? bindingType; // 'تسليك' | 'خرز' | null

  // معطيات طلب الطباعة — يعيد الخادم حساب السعر منها بدل الوثوق بـ price
  final int printPageCount;
  final String printColor; // 'bw' | 'color'
  final String printSides; // 'one' | 'two'
  final String printBinding; // 'none' | 'staple' | 'spiral'
  final int printCopies;

  // معرّفات محاضرات المادة الكاملة — يعيد الخادم حساب مجموعها بدل الوثوق بـ price
  final List<String> bundleLectureIds;

  CartItem({
    required this.id,
    required this.title,
    required this.price,
    this.quantity = 1,
    this.isSupply = false,
    this.imageUrl = '',
    this.isPrintJob = false,
    this.printJobStoragePath = '',
    this.printJobNotes = '',
    this.isLecture = false,
    this.bindingType,
    this.printPageCount = 0,
    this.printColor = 'bw',
    this.printSides = 'one',
    this.printBinding = 'none',
    this.printCopies = 1,
    this.bundleLectureIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'price': price,
    'quantity': quantity,
    'isSupply': isSupply,
    'imageUrl': imageUrl,
    'isPrintJob': isPrintJob,
    'printJobStoragePath': printJobStoragePath,
    'printJobNotes': printJobNotes,
    'isLecture': isLecture,
    if (bindingType != null) 'bindingType': bindingType,
    'printPageCount': printPageCount,
    'printColor': printColor,
    'printSides': printSides,
    'printBinding': printBinding,
    'printCopies': printCopies,
    if (bundleLectureIds.isNotEmpty) 'bundleLectureIds': bundleLectureIds,
  };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    id: j['id'] as String,
    title: j['title'] as String,
    price: (j['price'] as num).toDouble(),
    quantity: (j['quantity'] as num).toInt(),
    isSupply: j['isSupply'] as bool? ?? false,
    imageUrl: j['imageUrl'] as String? ?? '',
    isPrintJob: j['isPrintJob'] as bool? ?? false,
    printJobStoragePath: j['printJobStoragePath'] as String? ?? '',
    printJobNotes: j['printJobNotes'] as String? ?? '',
    isLecture: j['isLecture'] as bool? ?? false,
    bindingType: j['bindingType'] as String?,
    printPageCount: (j['printPageCount'] as num?)?.toInt() ?? 0,
    printColor: j['printColor'] as String? ?? 'bw',
    printSides: j['printSides'] as String? ?? 'one',
    printBinding: j['printBinding'] as String? ?? 'none',
    printCopies: (j['printCopies'] as num?)?.toInt() ?? 1,
    bundleLectureIds:
        (j['bundleLectureIds'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}

// ── User profile persistence ──────────────────────────────
const _profileKey = 'user_profile';

Future<void> _saveProfile(UserProfile p) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_profileKey, jsonEncode({
    'name': p.name,
    'specialty': p.specialty,
    'phone': p.phone,
  }));
}

Future<UserProfile?> _loadProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_profileKey);
  if (raw == null) return null;
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return UserProfile(
      name: j['name'] as String? ?? '',
      specialty: j['specialty'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
    );
  } catch (_) {
    return null;
  }
}

// ── Theme mode persistence ────────────────────────────────
const _themeKey = 'theme_mode';

Future<void> _saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_themeKey, mode.name); // 'light' | 'dark' | 'system'
}

Future<ThemeMode> _loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_themeKey);
  return ThemeMode.values.firstWhere(
    (m) => m.name == raw,
    orElse: () => ThemeMode.light,
  );
}

// ── Cart persistence ──────────────────────────────────────
const _cartKey = 'cart_items';

Future<void> _saveCart(List<CartItem> items) async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
  await prefs.setString(_cartKey, encoded);
}

Future<List<CartItem>> _loadCart() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_cartKey);
  if (raw == null) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

// ── UserProfile model ─────────────────────────────────────
class UserProfile {
  final String name;
  final String specialty;
  final String phone;
  final Uint8List? photoBytes;

  UserProfile({
    required this.name,
    required this.specialty,
    required this.phone,
    this.photoBytes,
  });

  UserProfile copyWith({
    String? name,
    String? specialty,
    String? phone,
    Uint8List? photoBytes,
  }) =>
      UserProfile(
        name: name ?? this.name,
        specialty: specialty ?? this.specialty,
        phone: phone ?? this.phone,
        photoBytes: photoBytes ?? this.photoBytes,
      );
}

// ── Entry point ───────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ملاحظة أمنية: لا تستورد main_admin.dart هنا أبداً — استيراده يُضمِّن
  // السر الإداري داخل APK الطالب الموزَّع للجميع. نسخة الأدمن تُبنى
  // بشكل منفصل عبر: flutter build/run --flavor admin --target lib/main_admin.dart

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Firebase init — يعمل بعد تنفيذ flutterfire configure
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (!kIsWeb) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (_) {
    // Firebase غير مُعدّ بعد — التطبيق يعمل بدون Firestore
  }

  // تسجيل دخول مجهول (مطلوب لقواعد Firestore وCloud Functions)
  // يُكرر المحاولة حتى مرتين عند الفشل
  if (FirebaseAuth.instance.currentUser == null) {
    for (var i = 0; i < 2; i++) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  // تحميل وضع السمة المحفوظ
  themeModeNotifier.value = await _loadThemeMode();
  themeModeNotifier.addListener(() => _saveThemeMode(themeModeNotifier.value));

  // تحميل السلة المحفوظة
  cartNotifier.value = await _loadCart();
  cartNotifier.addListener(() => _saveCart(cartNotifier.value));

  // تحميل بيانات المستخدم المحفوظة
  final savedProfile = await _loadProfile();
  if (savedProfile != null && savedProfile.phone.isNotEmpty) {
    userProfileNotifier.value = savedProfile;
    hasOnboarded = true;
  }
  userProfileNotifier.addListener(() => _saveProfile(userProfileNotifier.value));

  // بدء متابع الطلبات لإظهار شارة الإشعارات
  ordersWatcher.start();

  // الاشتراك بسعر الصفحة العام
  FirestoreService.getPricePerPage().listen(
    (price) { pricePerPageNotifier.value = price; },
    onError: (_) {},
  );

  if (!kIsWeb) {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, sound: true, badge: true);
      deviceFcmToken = await messaging.getToken();
      messaging.onTokenRefresh.listen((t) => deviceFcmToken = t);
    } catch (_) {}
  }

  runApp(const AlKamalApp());
}

class AlKamalApp extends StatelessWidget {
  const AlKamalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'مكتبة الكمال الطبية',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/',
          routes: {
            '/':           (_) => const SplashScreen(),
            '/onboarding': (_) => const OnboardingScreen(),
            '/home':       (_) => const MainShell(),
          },
        );
      },
    );
  }
}
