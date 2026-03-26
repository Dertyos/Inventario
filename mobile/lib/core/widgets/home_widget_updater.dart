import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

/// Updates home screen widget data. Call after dashboard loads or sales change.
class HomeWidgetUpdater {
  static const _androidWidget = 'InventarioWidgetProvider';
  static const _iosWidget = 'InventarioWidget';

  /// Update the widget with current dashboard metrics.
  static Future<void> updateDashboard({
    required double todayRevenue,
    required int todaySalesCount,
    required int totalProducts,
    required int lowStockCount,
  }) async {
    final cop = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    await HomeWidget.saveWidgetData('today_revenue', cop.format(todayRevenue));
    await HomeWidget.saveWidgetData(
        'today_sales_count', '$todaySalesCount ventas');
    await HomeWidget.saveWidgetData('total_products', '$totalProducts');
    await HomeWidget.saveWidgetData('low_stock_count', '$lowStockCount');
    await HomeWidget.saveWidgetData(
      'last_updated',
      DateFormat('HH:mm').format(DateTime.now()),
    );

    await HomeWidget.updateWidget(
      androidName: _androidWidget,
      iOSName: _iosWidget,
    );
  }
}
