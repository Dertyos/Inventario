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

/// Manages offline operations queue (sales, products, customers).
/// Data is saved as JSON lists in SharedPreferences.
class PendingSalesService {
  static const _salesKey = 'pending_sales';
  static const _opsKey = 'pending_operations';
  static const _productsCacheKey = 'products_cache';
  static const _customersCacheKey = 'customers_cache';
  static const _cacheTimestampKey = 'cache_timestamp';

  // ---------------------------------------------------------------------------
  // Pending sales (existing)
  // ---------------------------------------------------------------------------

  Future<void> savePendingSale(
      String teamId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_salesKey) ?? [];
    final entry = jsonEncode({
      ...data,
      '_localId': const Uuid().v4(),
      '_teamId': teamId,
      '_createdAt': DateTime.now().toIso8601String(),
    });
    queue.add(entry);
    await prefs.setStringList(_salesKey, queue);
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_salesKey) ?? [];
    return queue
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
  }

  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final salesCount = (prefs.getStringList(_salesKey) ?? []).length;
    final opsCount = (prefs.getStringList(_opsKey) ?? []).length;
    return salesCount + opsCount;
  }

  Future<void> removePendingSale(String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_salesKey) ?? [];
    queue.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['_localId'] == localId;
    });
    await prefs.setStringList(_salesKey, queue);
  }

  // ---------------------------------------------------------------------------
  // Pending operations (products, customers, etc.)
  // ---------------------------------------------------------------------------

  Future<void> savePendingOperation({
    required String teamId,
    required String type, // 'create_product', 'create_customer'
    required String endpoint, // '/teams/$teamId/products'
    required Map<String, dynamic> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_opsKey) ?? [];
    final entry = jsonEncode({
      '_localId': const Uuid().v4(),
      '_teamId': teamId,
      '_type': type,
      '_endpoint': endpoint,
      '_data': data,
      '_createdAt': DateTime.now().toIso8601String(),
    });
    queue.add(entry);
    await prefs.setStringList(_opsKey, queue);
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_opsKey) ?? [];
    return queue
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
  }

  Future<void> removePendingOperation(String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_opsKey) ?? [];
    queue.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['_localId'] == localId;
    });
    await prefs.setStringList(_opsKey, queue);
  }

  // ---------------------------------------------------------------------------
  // Products cache (read offline)
  // ---------------------------------------------------------------------------

  Future<void> cacheProducts(
      String teamId, List<Map<String, dynamic>> products) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '${_productsCacheKey}_$teamId', jsonEncode(products));
    await prefs.setInt(
        '${_cacheTimestampKey}_products_$teamId',
        DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Map<String, dynamic>>?> getCachedProducts(String teamId) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('${_productsCacheKey}_$teamId');
    if (cached == null) return null;
    return (jsonDecode(cached) as List)
        .cast<Map<String, dynamic>>();
  }

  Future<bool> isProductsCacheStale(String teamId,
      {Duration maxAge = const Duration(hours: 1)}) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp =
        prefs.getInt('${_cacheTimestampKey}_products_$teamId');
    if (timestamp == null) return true;
    return DateTime.now().millisecondsSinceEpoch - timestamp >
        maxAge.inMilliseconds;
  }

  // ---------------------------------------------------------------------------
  // Customers cache (read offline)
  // ---------------------------------------------------------------------------

  Future<void> cacheCustomers(
      String teamId, List<Map<String, dynamic>> customers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '${_customersCacheKey}_$teamId', jsonEncode(customers));
    await prefs.setInt(
        '${_cacheTimestampKey}_customers_$teamId',
        DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Map<String, dynamic>>?> getCachedCustomers(
      String teamId) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('${_customersCacheKey}_$teamId');
    if (cached == null) return null;
    return (jsonDecode(cached) as List)
        .cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // Clear all
  // ---------------------------------------------------------------------------

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_salesKey);
    await prefs.remove(_opsKey);
    // Don't clear caches - they're useful even after logout
  }
}
