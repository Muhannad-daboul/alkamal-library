import 'package:flutter_test/flutter_test.dart';
import 'package:alkamal_app/data.dart';

void main() {
  group('PrintPricing', () {
    test('fromMap uses provided values', () {
      final p = PrintPricing.fromMap({
        'bwSinglePage': 25.0,
        'bwDoublePage': 20.0,
        'colorSinglePage': 100.0,
        'colorDoublePage': 80.0,
        'bindingStaple': 500.0,
        'bindingSpiral': 1500.0,
      });
      expect(p.bwSinglePage, 25.0);
      expect(p.colorDoublePage, 80.0);
      expect(p.bindingSpiral, 1500.0);
    });

    test('fromMap uses defaults for missing keys', () {
      final p = PrintPricing.fromMap({});
      expect(p.bwSinglePage, 25.0);
      expect(p.bindingStaple, 500.0);
    });

    test('toMap round-trips', () {
      const p = PrintPricing();
      final m = p.toMap();
      final p2 = PrintPricing.fromMap(m);
      expect(p2.bwSinglePage, p.bwSinglePage);
      expect(p2.bindingSpiral, p.bindingSpiral);
    });
  });
}
