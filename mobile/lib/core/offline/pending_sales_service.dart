import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final pendingSalesServiceProvider = Provider<PendingSalesService>((ref) {
  return PendingSalesService();
});

final pendingSalesCountProvider = FutureProvider<int>((ref) async {
  return ref.read(pendingSalesServiceProvider).getPendingCount();
});

class PendingSalesService {
  static const _key = 'pending_sales';

  Future<void> savePendingSale(String teamId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_key) ?? [];
    final entry = jsonEncode({
      ...data,
      '_localId': const Uuid().v4(),
      '_teamId': teamId,
      '_createdAt': DateTime.now().toIso8601String(),
    });
    queue.add(entry);
    await prefs.setStringList(_key, queue);
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_key) ?? [];
    return queue.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }

  Future<void> removePendingSale(String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_key) ?? [];
    queue.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['_localId'] == localId;
    });
    await prefs.setStringList(_key, queue);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
