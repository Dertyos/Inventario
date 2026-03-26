import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quick_actions/quick_actions.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';

/// Global key for navigating from quick actions / widget taps.
final globalNavigatorKey = GlobalKey<NavigatorState>();

/// Pending route from app shortcut or widget tap (set before router is ready).
String? _pendingRoute;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await initializeDateFormatting('es');
  await NotificationService().initialize();

  // Load saved server URL
  final storage = SecureStorage();
  final savedUrl = await loadServerUrl(storage);

  // Register home widget callback
  HomeWidget.setAppGroupId('group.com.inventario.inventario_mobile');
  HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);

  runApp(ProviderScope(child: _AppBootstrap(savedUrl: savedUrl)));
}

/// Called when user taps an interactive element on the home widget.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri != null) {
    _pendingRoute = uri.path.isNotEmpty ? uri.path : uri.host;
  }
}

/// Sets server URL before rendering the real app.
class _AppBootstrap extends ConsumerWidget {
  final String savedUrl;
  const _AppBootstrap({required this.savedUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set saved URL on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (savedUrl != AppConfig.baseUrl) {
        ref.read(serverUrlProvider.notifier).update(savedUrl);
      }
    });
    return const InventarioApp();
  }
}

class InventarioApp extends ConsumerStatefulWidget {
  const InventarioApp({super.key});

  @override
  ConsumerState<InventarioApp> createState() => _InventarioAppState();
}

class _InventarioAppState extends ConsumerState<InventarioApp> {
  final QuickActions _quickActions = const QuickActions();

  @override
  void initState() {
    super.initState();
    _setupQuickActions();
    _setupHomeWidgetLaunch();
  }

  void _setupQuickActions() {
    _quickActions.setShortcutItems([
      const ShortcutItem(
        type: 'new_sale',
        localizedTitle: 'Nueva venta',
        icon: 'ic_shortcut_sale',
      ),
      const ShortcutItem(
        type: 'ai_assistant',
        localizedTitle: 'Asistente IA',
        icon: 'ic_shortcut_ai',
      ),
      const ShortcutItem(
        type: 'new_product',
        localizedTitle: 'Nuevo producto',
        icon: 'ic_shortcut_product',
      ),
    ]);

    _quickActions.initialize((type) {
      switch (type) {
        case 'new_sale':
          _navigateTo('/sales/new');
        case 'ai_assistant':
          _navigateTo('/voice-transaction');
        case 'new_product':
          _navigateTo('/products/new');
      }
    });
  }

  void _setupHomeWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) {
        _pendingRoute = uri.path.isNotEmpty ? uri.path : uri.host;
      }
    });

    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        final route = uri.path.isNotEmpty ? uri.path : uri.host;
        _navigateTo(route);
      }
    });
  }

  void _navigateTo(String route) {
    Future.delayed(const Duration(milliseconds: 300), () {
      final ctx = globalNavigatorKey.currentContext;
      if (ctx != null) {
        try {
          GoRouter.of(ctx).push(route);
        } catch (_) {
          _pendingRoute = route;
        }
      } else {
        _pendingRoute = route;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Inventario',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        if (_pendingRoute != null) {
          final route = _pendingRoute!;
          _pendingRoute = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              router.push(route);
            } catch (_) {}
          });
        }

        final mediaQuery = MediaQuery.of(context);
        final cappedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.4,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: cappedTextScaler),
          child: child!,
        );
      },
    );
  }
}
