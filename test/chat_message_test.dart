import 'package:flutter_test/flutter_test.dart';
import 'package:alkamal_app/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('isBot true for bot message', () {
      final msg = ChatMessage(text: 'مرحبا', isBot: true, timestamp: DateTime(2026, 5, 19));
      expect(msg.isBot, isTrue);
      expect(msg.text, 'مرحبا');
      expect(msg.timestamp, equals(DateTime(2026, 5, 19)));
    });

    test('isBot false for user message', () {
      final msg = ChatMessage(text: 'سؤال', isBot: false, timestamp: DateTime(2026, 5, 19));
      expect(msg.isBot, isFalse);
      expect(msg.timestamp, equals(DateTime(2026, 5, 19)));
    });
  });
}
