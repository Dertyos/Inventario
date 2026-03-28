import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../network/api_client.dart';
import 'pending_sales_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.read(dioProvider), ref.read(pendingSalesServiceProvider));
});

class SyncService {
  final Dio _dio;
  final PendingSalesService _pending;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  /// Errors accumulated during the last sync attempt.
  final List<String> lastSyncErrors = [];

  SyncService(this._dio, this._pending);

  /// Syncs all pending operations. Returns total synced count.
  Future<int> syncAll() async {
    lastSyncErrors.clear();
    final salesSynced = await syncPendingSales();
    final opsSynced = await syncPendingOperations();
    return salesSynced + opsSynced;
  }

  Future<int> syncPendingSales() async {
    final pending = await _pending.getPending();
    int synced = 0;

    for (final sale in pending) {
      final localId = sale['_localId'] as String;
      final teamId = sale['_teamId'] as String;

      final data = Map<String, dynamic>.from(sale)
        ..remove('_localId')
        ..remove('_teamId')
        ..remove('_createdAt');

      try {
        await _dio.post('/teams/$teamId/sales', data: data);
        await _pending.removePendingSale(localId);
        synced++;
      } catch (e) {
        final message = e is DioException
            ? (e.response?.data?['message']?.toString() ?? e.message ?? 'Error de red')
            : e.toString();
        _logger.w('Sync failed for sale $localId: $message');
        lastSyncErrors.add('Venta $localId: $message');
      }
    }
    return synced;
  }

  Future<int> syncPendingOperations() async {
    final ops = await _pending.getPendingOperations();
    int synced = 0;

    for (final op in ops) {
      final localId = op['_localId'] as String;
      final endpoint = op['_endpoint'] as String;
      final data = op['_data'] as Map<String, dynamic>;

      try {
        await _dio.post(endpoint, data: data);
        await _pending.removePendingOperation(localId);
        synced++;
      } catch (e) {
        final message = e is DioException
            ? (e.response?.data?['message']?.toString() ?? e.message ?? 'Error de red')
            : e.toString();
        _logger.w('Sync failed for operation $localId ($endpoint): $message');
        lastSyncErrors.add('Operacion pendiente: $message');
      }
    }
    return synced;
  }
}
