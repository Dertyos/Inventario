import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline/offline_provider.dart';
import '../../core/offline/pending_sales_service.dart';
import '../../core/theme/app_theme.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pendingCount = ref.watch(pendingSalesCountProvider);

    if (isOnline && (pendingCount.valueOrNull ?? 0) == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      color: isOnline ? AppColors.success : AppColors.warning,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOnline
                  ? 'Sincronizando ${pendingCount.valueOrNull} ventas...'
                  : 'Sin conexion \u00b7 Las ventas se guardan localmente',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
