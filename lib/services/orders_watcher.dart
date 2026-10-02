import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data.dart';
import '../main.dart' show ordersUnseenNotifier, userProfileNotifier;
import 'firestore_service.dart';

/// يتابع طلبات المستخدم ويحدّث [ordersUnseenNotifier] بعدد الطلبات التي تغيّرت
/// حالتها منذ آخر مرة دخل فيها الطالب لصفحة "طلباتي".
class OrdersWatcher {
  static const _prefsKey = 'seen_order_statuses';

  StreamSubscription<List<Order>>? _sub;
  StreamSubscription<User?>? _authSub;
  String _currentUid = '';

  void start() {
    userProfileNotifier.addListener(_onProfileChanged);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _onProfileChanged();
    });
    _onProfileChanged();
  }

  void stop() {
    userProfileNotifier.removeListener(_onProfileChanged);
    _authSub?.cancel();
    _sub?.cancel();
    _sub = null;
  }

  void _onProfileChanged() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hasProfile = userProfileNotifier.value.phone.trim().isNotEmpty;
    if (uid == _currentUid) return;
    _currentUid = uid;
    _sub?.cancel();
    if (uid.isEmpty || !hasProfile) {
      ordersUnseenNotifier.value = 0;
      return;
    }
    _sub = FirestoreService.getOrdersForUser(uid).listen(
      _onOrders,
      onError: (_) {
        ordersUnseenNotifier.value = 0;
      },
    );
  }

  Future<void> _onOrders(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final seen = raw == null
        ? <String, String>{}
        : (jsonDecode(raw) as Map).cast<String, dynamic>().map(
              (k, v) => MapEntry(k, v.toString()),
            );

    int unseen = 0;
    for (final o in orders) {
      final last = seen[o.id];
      if (last == null || last != o.status) {
        unseen++;
      }
    }
    ordersUnseenNotifier.value = unseen;
  }

  /// يُستدعى عندما يفتح الطالب صفحة "طلباتي" — يحفظ الحالات الحالية كمشاهَدة.
  static Future<void> markAllSeen(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (final o in orders) o.id: o.status};
    await prefs.setString(_prefsKey, jsonEncode(map));
    ordersUnseenNotifier.value = 0;
  }
}

final ordersWatcher = OrdersWatcher();
