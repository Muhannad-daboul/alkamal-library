# مكتبة الكمال الطبية — Alkamal Medical Store

تطبيق Flutter لإدارة مكتبة طبية، يتيح للمستخدمين تصفح المنتجات والمستلزمات الطبية وإتمام عمليات الشراء، مع لوحة تحكم للمشرفين.

---

## التقنيات المستخدمة

| التقنية | الاستخدام |
|---|---|
| Flutter 3.x | إطار العمل الرئيسي |
| Dart SDK ^3.11.4 | لغة البرمجة |
| Firebase Firestore | قاعدة البيانات |
| Firebase Storage | رفع الصور |
| Firebase Messaging | الإشعارات |
| Flutter Map | خرائط التوصيل |
| Geolocator | تحديد الموقع |
| Google Fonts | الخطوط |

---

## هيكل المشروع

```
lib/
├── main.dart              # نقطة دخول تطبيق المستخدم
├── main_admin.dart        # نقطة دخول لوحة الإدارة
├── app_theme.dart         # الثيم والألوان
├── data.dart              # البيانات الثابتة
├── screens/
│   ├── admin/             # شاشات الإدارة
│   ├── home_screen.dart
│   ├── products_list_screen.dart
│   ├── product_detail_screen.dart
│   ├── cart_screen.dart
│   ├── checkout_screen.dart
│   ├── orders_screen.dart
│   ├── delivery_map_screen.dart
│   ├── search_screen.dart
│   ├── profile_screen.dart
│   └── splash_screen.dart
├── services/
│   └── firestore_service.dart
└── widgets/
    ├── app_drawer.dart
    └── student_bottom_navigation_bar.dart
```

---

## تشغيل المشروع محلياً

### المتطلبات
- Flutter SDK 3.x
- Dart SDK ^3.11.4
- حساب Firebase

### الخطوات

```bash
# 1. استنساخ المشروع
git clone https://github.com/Muhannad-daboul/alkamal-app.git
cd alkamal-app

# 2. تثبيت المكتبات
flutter pub get

# 3. إضافة ملفات Firebase (غير مرفوعة لأسباب أمنية)
# ضع الملفات التالية في مكانها الصحيح:
# - android/app/google-services.json
# - ios/Runner/GoogleService-Info.plist
# - lib/firebase_options.dart

# 4. تشغيل التطبيق
flutter run

# لتشغيل لوحة الإدارة
flutter run -t lib/main_admin.dart
```

---

## ملاحظات مهمة

- ملفات Firebase (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) **غير مرفوعة** في الـ repository لأسباب أمنية — يجب إضافتها يدوياً عند استنساخ المشروع.
- الإصدار الحالي: `1.0.0+1`
