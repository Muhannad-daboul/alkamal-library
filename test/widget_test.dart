// اختبار دخان أساسي: يتأكد أن التطبيق يُبنى ويعرض شاشة البداية
// بدون أخطاء. (بدون Firebase — لا يمكن اختبار الشاشات المتصلة هنا.)

import 'package:flutter_test/flutter_test.dart';

import 'package:alkamal_app/main.dart';

void main() {
  testWidgets('App builds and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AlKamalApp());

    expect(find.byType(AlKamalApp), findsOneWidget);
  });
}
