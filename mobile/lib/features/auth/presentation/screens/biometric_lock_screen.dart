import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_lock_provider.dart';
import '../../../../shared/providers/auth_provider.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isAuthenticating = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger on show, after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _failed = false;
    });
    final success =
        await ref.read(appLockProvider.notifier).attemptBiometric();
    if (!mounted) return;
    setState(() {
      _isAuthenticating = false;
      _failed = !success;
    });
  }

  void _logout() {
    ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Inventario',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifica tu identidad para continuar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Fingerprint / Face ID icon button
                GestureDetector(
                  onTap: _isAuthenticating ? null : _authenticate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isAuthenticating
                          ? colorScheme.primaryContainer
                          : colorScheme.primary,
                    ),
                    child: _isAuthenticating
                        ? Padding(
                            padding: const EdgeInsets.all(22),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          )
                        : Icon(
                            Icons.fingerprint,
                            size: 40,
                            color: colorScheme.onPrimary,
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_failed) ...[
                  Text(
                    'No se pudo verificar. Intenta de nuevo.',
                    style: TextStyle(color: colorScheme.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                TextButton.icon(
                  onPressed: _isAuthenticating ? null : _authenticate,
                  icon: const Icon(Icons.fingerprint, size: 18),
                  label: const Text('Desbloquear'),
                ),
                const SizedBox(height: 60),
                TextButton(
                  onPressed: _logout,
                  child: Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
