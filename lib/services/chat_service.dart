import 'package:cloud_functions/cloud_functions.dart';

class ChatService {
  static final _functions = FirebaseFunctions.instance;

  static Future<String> sendMessage({
    required String message,
    required List<Map<String, String>> history,
    required String userId,
  }) async {
    final callable = _functions.httpsCallable('ragChat');
    try {
      final result = await callable.call<Map<String, dynamic>>({
        'message': message,
        'history': history,
        'userId': userId,
      });
      return (result.data['reply'] as String?) ?? 'عذراً، لم أتمكن من الإجابة';
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return e.message ?? 'تجاوزت الحد المسموح من الرسائل. حاول لاحقاً.';
      }
      rethrow;
    }
  }
}
