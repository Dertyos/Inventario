package com.inventario.inventario_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class InventarioWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.inventario_widget)

            // Read data saved from Flutter
            val todayRevenue = widgetData.getString("today_revenue", "\$0") ?: "\$0"
            val todaySalesCount = widgetData.getString("today_sales_count", "0 ventas") ?: "0 ventas"
            val totalProducts = widgetData.getString("total_products", "0") ?: "0"
            val lowStockCount = widgetData.getString("low_stock_count", "0") ?: "0"
            val lastUpdated = widgetData.getString("last_updated", "--:--") ?: "--:--"

            // Set text values
            views.setTextViewText(R.id.txt_today_revenue, todayRevenue)
            views.setTextViewText(R.id.txt_today_sales_count, todaySalesCount)
            views.setTextViewText(R.id.txt_total_products, totalProducts)
            views.setTextViewText(R.id.txt_low_stock, lowStockCount)
            views.setTextViewText(R.id.txt_last_updated, lastUpdated)

            // Click handlers - open app at specific routes
            views.setOnClickPendingIntent(
                R.id.btn_new_sale,
                makePendingIntent(context, "inventario://sales/new", 0)
            )
            views.setOnClickPendingIntent(
                R.id.btn_ai,
                makePendingIntent(context, "inventario://voice-transaction", 1)
            )
            views.setOnClickPendingIntent(
                R.id.btn_sales,
                makePendingIntent(context, "inventario://sales", 2)
            )
            views.setOnClickPendingIntent(
                R.id.btn_products,
                makePendingIntent(context, "inventario://products", 3)
            )
            views.setOnClickPendingIntent(
                R.id.btn_inventory,
                makePendingIntent(context, "inventario://inventory", 4)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun makePendingIntent(context: Context, uriString: String, requestCode: Int): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        intent?.data = Uri.parse(uriString)
        intent?.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
