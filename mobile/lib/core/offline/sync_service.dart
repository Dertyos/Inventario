import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import 'pending_sales_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.read(dioProvider), ref.read(pendingSalesServiceProvider));
});

class SyncService {
  final Dio _dio;
  final PendingSalesService _pending;

  SyncService(this._dio, this._pending);

  Future<int> syncPendingSales() async {
    final pending = await _pending.getPending();
    int synced = 0;

    for (final sale in pending) {
      final localId = sale['_localId'] as String;
      final teamId = sale['_teamId'] as String;

      // Remover metadatos locales antes de enviar
      final data = Map<String, dynamic>.from(sale)
        ..remove('_localId')
        ..remove('_teamId')
        ..remove('_createdAt');

      try {
        await _dio.post('/teams/$teamId/sales', data: data);
        await _pending.removePendingSale(localId);
        synced++;
      } catch (_) {
        // Reintentar en la proxima sincronizacion
      }
    }
    return synced;
  }
}
