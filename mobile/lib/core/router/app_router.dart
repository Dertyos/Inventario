import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/create_team_screen.dart';
import '../../features/auth/presentation/screens/invitation_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/products/presentation/screens/product_form_screen.dart';
import '../../features/sales/presentation/screens/sales_screen.dart';
import '../../features/sales/presentation/screens/create_sale_screen.dart';
import '../../features/sales/presentation/screens/edit_sale_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/team_settings_screen.dart';
import '../../features/settings/presentation/screens/team_members_screen.dart';
import '../../features/settings/presentation/screens/role_permissions_screen.dart';
import '../../features/ai_chat/presentation/screens/ai_chat_screen.dart'
    show VoiceTransactionScreen;
import '../../features/scanner/presentation/screens/barcode_scanner_screen.dart';
import '../../features/credits/presentation/screens/credits_screen.dart';
import '../../features/credits/presentation/screens/credit_detail_screen.dart';
import '../../features/purchases/presentation/screens/purchases_screen.dart';
import '../../features/purchases/presentation/screens/create_purchase_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/lots/presentation/screens/lots_screen.dart';
import '../../features/lots/presentation/screens/create_lot_screen.dart';
import '../../features/suppliers/presentation/screens/suppliers_screen.dart';
import '../../features/suppliers/presentation/screens/supplier_detail_screen.dart';
import '../../features/customers/presentation/screens/customer_detail_screen.dart';
import '../../features/reminders/presentation/screens/reminders_screen.dart';
import '../../features/reports/presentation/screens/sales_report_screen.dart';
import '../../features/settings/presentation/screens/change_password_screen.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final location = state.matchedLocation;

      // Handle custom scheme deep links: inventario://...
      final uri = state.uri;
      if (uri.scheme == 'inventario') {
        if (uri.host == 'invite') {
          final token = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.first
              : uri.path.replaceAll('/', '');
          if (token.isNotEmpty) {
            ref.read(pendingInviteTokenProvider.notifier).state = token;
            return '/invite/$token';
          }
        }
        if (uri.host == 'voice-transaction') {
          return '/voice-transaction';
        }
        // Unknown deep link – go to dashboard
        return '/dashboard';
      }

      // Redirect root "/" to dashboard
      if (location == '/') return '/dashboard';

      final isAuthRoute =
          location == '/login' || location == '/register';
      final isCreateTeam = location == '/create-team';
      final isInvite = location.startsWith('/invite/');

      if (authState.status == AuthStatus.initial) return null;

      // Allow invite route for both authenticated and unauthenticated users
      if (isInvite) return null;

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) {
        // After login/register, check for pending invite
        final pendingToken = ref.read(pendingInviteTokenProvider);
        if (pendingToken != null) {
          return '/invite/$pendingToken';
        }
        return '/dashboard';
      }
      if (isAuth && authState.activeTeam == null && !isCreateTeam) {
        // Check for pending invite before forcing team creation
        final pendingToken = ref.read(pendingInviteTokenProvider);
        if (pendingToken != null) {
          return '/invite/$pendingToken';
        }
        return '/create-team';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/create-team',
        builder: (context, state) => const CreateTeamScreen(),
      ),
      GoRoute(
        path: '/invite/:token',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final token = state.pathParameters['token'];
          if (token == null || token.isEmpty) {
            return const _RouteErrorScreen(message: 'Token de invitación no válido');
          }
          return InvitationScreen(token: token);
        },
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/products',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProductsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => ProductFormScreen(
                  initialBarcode: state.extra as String?,
                ),
              ),
              GoRoute(
                path: ':id/edit',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  if (id == null || id.isEmpty) {
                    return const _RouteErrorScreen(message: 'ID de producto no válido');
                  }
                  return ProductFormScreen(productId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/sales',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SalesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const CreateSaleScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  if (id == null || id.isEmpty) {
                    return const _RouteErrorScreen(message: 'ID de venta no válido');
                  }
                  return EditSaleScreen(saleId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: InventoryScreen(),
            ),
          ),
          GoRoute(
            path: '/customers',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CustomersScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/team-settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeamSettingsScreen(),
      ),
      GoRoute(
        path: '/team-members',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeamMembersScreen(),
      ),
      GoRoute(
        path: '/role-permissions/:role',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final role = state.pathParameters['role'];
          if (role == null || role.isEmpty) {
            return const _RouteErrorScreen(message: 'Rol no válido');
          }
          return RolePermissionsScreen(role: role);
        },
      ),
      GoRoute(
        path: '/voice-transaction',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VoiceTransactionScreen(),
      ),
      GoRoute(
        path: '/scanner',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BarcodeScannerScreen(),
      ),
      GoRoute(
        path: '/credits',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreditsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null || id.isEmpty) {
                return const _RouteErrorScreen(message: 'ID de crédito no válido');
              }
              return CreditDetailScreen(creditId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/purchases',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PurchasesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const CreatePurchaseScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/lots',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LotsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const CreateLotScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/suppliers',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SuppliersScreen(),
        routes: [
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null || id.isEmpty) {
                return const _RouteErrorScreen(message: 'ID de proveedor no válido');
              }
              return SupplierDetailScreen(supplierId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/customers/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return const _RouteErrorScreen(message: 'ID de cliente no válido');
          }
          return CustomerDetailScreen(customerId: id);
        },
      ),
      GoRoute(
        path: '/reminders',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RemindersScreen(),
      ),
      GoRoute(
        path: '/reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SalesReportScreen(),
      ),
      GoRoute(
        path: '/change-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
    ],
  );
});

class _RouteErrorScreen extends StatelessWidget {
  final String message;
  const _RouteErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
