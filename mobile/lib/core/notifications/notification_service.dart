import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

import '../../shared/models/product_model.dart';

/// Singleton service for local push notifications.
///
/// Handles low-stock alerts checked on app open — no server required.
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final _logger = Logger(printer: SimplePrinter());
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Whether low-stock alerts have already been checked this session.
  static bool _lowStockCheckedThisSession = false;

  // Android notification channel
  static const _channelId = 'inventario_alerts';
  static const _channelName = 'Alertas de Inventario';
  static const _channelDescription = 'Alertas de stock bajo y recordatorios';

  // Notification group key
  static const _lowStockGroupKey = 'inventario_low_stock';

  /// Initialize the notification plugin. Call once from main.dart after
  /// [WidgetsFlutterBinding.ensureInitialized].
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(initSettings);

    // Request permissions on Android 13+
    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    _initialized = true;
    _logger.i('NotificationService initialized');
  }

  /// Show an immediate notification.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  /// Check products for low stock and fire grouped notifications.
  ///
  /// Only runs once per app session to avoid spamming the user.
  Future<void> checkLowStockAlerts(List<ProductModel> products) async {
    if (_lowStockCheckedThisSession) return;
    _lowStockCheckedThisSession = true;

    if (!_initialized) {
      _logger.w('NotificationService not initialized — skipping alerts');
      return;
    }

    final lowStock = products
        .where((p) => p.stock <= p.minStock && p.stock > 0)
        .toList();

    if (lowStock.isEmpty) return;

    _logger.i('Found ${lowStock.length} low-stock products');

    // Show individual notifications for each product (max 5 to avoid flood)
    final toShow = lowStock.take(5).toList();
    for (final product in toShow) {
      final notificationId = product.id.hashCode;
      await _plugin.show(
        notificationId,
        'Stock bajo: ${product.name}',
        'Quedan ${product.stock} unidades (mín: ${product.minStock})',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: false,
            enableVibration: false,
            groupKey: _lowStockGroupKey,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: false,
            threadIdentifier: _lowStockGroupKey,
          ),
        ),
      );
    }

    // Show summary notification (Android group summary)
    if (Platform.isAndroid && lowStock.length > 1) {
      const summaryId = 0; // fixed ID for the summary
      await _plugin.show(
        summaryId,
        'Stock bajo',
        '${lowStock.length} productos con stock bajo',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: false,
            enableVibration: false,
            groupKey: _lowStockGroupKey,
            setAsGroupSummary: true,
          ),
        ),
      );
    }
  }
}
