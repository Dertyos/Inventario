import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ai/ai_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/providers/auth_provider.dart';

class VoiceTransactionScreen extends ConsumerStatefulWidget {
  const VoiceTransactionScreen({super.key});

  @override
  ConsumerState<VoiceTransactionScreen> createState() =>
      _VoiceTransactionScreenState();
}

class _VoiceTransactionScreenState
    extends ConsumerState<VoiceTransactionScreen> {
  final _controller = TextEditingController();
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isProcessing = false;
  bool _speechAvailable = false;
  double _soundLevel = 0.0;
  String _localeId = 'es_CO';
  String? _error;
  String? _successMsg;

  final _examples = [
    'Venta de 5 tornillos a Pedro por 25 mil',
    'Crear producto Coca-Cola 350ml a 2500',
    'Agregar cliente Maria Garcia tel 3001234567',
    'Nuevo proveedor Distribuidora ABC nit 900123456',
    'Entrada de 100 tuercas a bodega',
    'Crear categoria Bebidas',
    'Invitar a juan@email.com como admin',
    'Compra de 20 clavos al proveedor Garcia',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        setState(() => _isListening = false);
      },
    );
    if (_speechAvailable) {
      final locales = await _speech.locales();
      final hasEsCO = locales.any((l) => l.localeId == 'es_CO');
      final hasEs = locales.any((l) => l.localeId.startsWith('es'));
      if (hasEsCO) {
        _localeId = 'es_CO';
      } else if (hasEs) {
        _localeId =
            locales.firstWhere((l) => l.localeId.startsWith('es')).localeId;
      }
    }
    setState(() {});
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      _showSnack('Microfono no disponible');
      return;
    }

    setState(() {
      _isListening = true;
      _error = null;
      _successMsg = null;
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
        if (result.finalResult) {
          setState(() => _isListening = false);
          if (_controller.text.trim().isNotEmpty) {
            _processText(_controller.text);
          }
        }
      },
      onSoundLevelChange: (level) {
        setState(() => _soundLevel = level);
      },
      localeId: _localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<void> _processText(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _isProcessing = true;
      _error = null;
      _successMsg = null;
    });

    final teamId = ref.read(authProvider).teamId;
    if (teamId.isEmpty) {
      setState(() {
        _error = 'No hay equipo activo. Crea uno en Configuracion.';
        _isProcessing = false;
      });
      return;
    }

    try {
      final result =
          await ref.read(aiServiceProvider).parseCommand(teamId, text);
      // Handle navigation commands
      if (result.action.isNavigation && result.navigateRoute != null) {
        setState(() => _isProcessing = false);
        if (!context.mounted) return;

        final route = _resolveRoute(result.navigateRoute!);
        final message = result.navigateMessage ?? 'Listo';

        Navigator.pop(context); // close AI screen
        if (_isTabRoute(route)) {
          context.go(route); // bottom tab — replace current screen
        } else {
          context.push(route); // other screens — push on stack
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Handle unsupported commands
      if (result.action == CommandAction.unsupported) {
        setState(() {
          _error = result.unsupportedMessage ??
              'No puedo hacer eso. Puedo crear ventas, productos, clientes, proveedores, o registrar movimientos de inventario.';
          _isProcessing = false;
        });
        return;
      }

      await _handleParsedResult(result);
    } catch (e) {
      final msg = e.toString();
      String errorMsg;
      if (msg.contains('conexion') ||
          msg.contains('internet') ||
          msg.contains('timeout') ||
          msg.contains('Connection')) {
        errorMsg =
            'No se pudo conectar al servidor. Verifica la URL en Configuracion > Servidor.';
      } else if (msg.contains('503') ||
          msg.contains('unavailable') ||
          msg.contains('no configurado') ||
          msg.contains('API key')) {
        errorMsg =
            'El servicio de IA no esta disponible. Verifica que AI_PROVIDER y su API key esten configurados en el backend.';
      } else if (msg.contains('403') || msg.contains('permisos') || msg.contains('permission')) {
        errorMsg = 'No tienes permisos para usar esta funcion.';
      } else {
        // Show the actual error from the backend for debugging
        errorMsg = msg;
      }
      setState(() {
        _error = errorMsg;
        _isProcessing = false;
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Routes inside ShellRoute (bottom tabs) use go(), others use push().
  static const _goRoutes = {
    '/products', '/sales', '/inventory', '/dashboard', '/settings',
  };

  String _resolveRoute(String backendRoute) {
    switch (backendRoute) {
      case '/inventory/low-stock':
        return '/inventory';
      default:
        return backendRoute;
    }
  }

  bool _isTabRoute(String route) => _goRoutes.contains(route);

  Future<void> _handleParsedResult(ParsedCommand parsed) async {
    final teamId = ref.read(authProvider).teamId;

    // For categories, keep direct API call (no dedicated form)
    if (parsed.action == CommandAction.createCategory) {
      try {
        final c = parsed.category!;
        final dio = ref.read(dioProvider);
        await dio.post('/teams/$teamId/categories', data: {
          'name': c.name,
          if (c.description != null) 'description': c.description,
        });
        if (mounted) {
          _showSnack('Categoria "${c.name}" creada');
          _reset();
          setState(() => _isProcessing = false);
        }
      } on DioException catch (e) {
        final data = e.response?.data;
        final msg = data is Map && data.containsKey('message')
            ? data['message'].toString()
            : 'Error del servidor';
        if (mounted) {
          setState(() => _isProcessing = false);
          _showSnack('Error: $msg');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showSnack('Error: $e');
        }
      }
      return;
    }

    // Navigate to the corresponding form with pre-filled AI data
    switch (parsed.action) {
      case CommandAction.createProduct:
        context.push('/products/new', extra: AiPrefill(data: parsed.product!, confidence: parsed.confidence, rawText: parsed.rawText));
        break;
      case CommandAction.createSale:
        context.push('/sales/new', extra: AiPrefill(data: parsed.transaction!, confidence: parsed.confidence, rawText: parsed.rawText));
        break;
      case CommandAction.createPurchase:
        context.push('/purchases/new', extra: AiPrefill(data: parsed.transaction!, confidence: parsed.confidence, rawText: parsed.rawText));
        break;
      case CommandAction.addStock:
      case CommandAction.removeStock:
        context.push('/inventory', extra: AiPrefill(data: parsed.inventory!, confidence: parsed.confidence, rawText: parsed.rawText));
        break;
      case CommandAction.createCustomer:
        context.push('/customers', extra: AiPrefill(data: parsed.customer!, confidence: parsed.confidence, rawText: parsed.rawText));
        break;
      case CommandAction.createSupplier:
        context.push('/suppliers', extra: AiPrefill(data: parsed.supplier!, confidence: parsed.confidence, rawText: parsed.rawText));
        break;
      case CommandAction.inviteMember:
        context.push('/team-members', extra: AiPrefill(data: parsed.member!, confidence: parsed.confidence, rawText: parsed.rawText));
        break;
      case CommandAction.createCategory:
        break;
    }
    
    _reset();
    setState(() => _isProcessing = false);
  }

  void _reset() {
    setState(() {
      _controller.clear();
      _error = null;
      _successMsg = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, size: 20, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            const Text('Asistente IA'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildInputArea(context),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              MediaQuery.of(context).padding.bottom + AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ej: Crear producto Coca-Cola a 2500...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _processText,
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filled(
                  onPressed: _isProcessing ? null : _toggleListening,
                  style: IconButton.styleFrom(
                    backgroundColor: _isListening
                        ? colorScheme.error
                        : colorScheme.primaryContainer,
                    foregroundColor: _isListening
                        ? colorScheme.onError
                        : colorScheme.onPrimaryContainer,
                  ),
                  icon: Icon(_isListening ? Icons.stop : Icons.mic),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  onPressed: _isProcessing
                      ? null
                      : () => _processText(_controller.text),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input area (idle / listening / processing)
  // ---------------------------------------------------------------------------

  Widget _buildInputArea(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Procesando...'),
          ],
        ),
      );
    }

    if (_isListening) {
      final scale = 1.0 + (_soundLevel.clamp(0, 10) / 10) * 0.3;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mic, size: 64, color: colorScheme.error),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Escuchando...',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Di lo que necesitas',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (_controller.text.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  _controller.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_successMsg != null) ...[
              Card(
                color: AppColors.successBg(context),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 24),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(_successMsg!,
                            style: const TextStyle(color: AppColors.success)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.auto_awesome, size: 48, color: colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Asistente IA',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Di o escribe lo que necesitas.\nVentas, compras, productos, clientes, inventario y mas.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: colorScheme.onErrorContainer, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                          child: Text(_error!,
                              style: TextStyle(
                                  color: colorScheme.onErrorContainer))),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ejemplos:',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: _examples
                  .map(
                    (s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        _controller.text = s;
                        _processText(s);
                      },
                      avatar: Icon(_iconForExample(s), size: 14),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForExample(String s) {
    final lower = s.toLowerCase();
    if (lower.startsWith('venta') || lower.startsWith('vend')) {
      return Icons.sell_outlined;
    }
    if (lower.startsWith('compra')) return Icons.shopping_cart_outlined;
    if (lower.contains('producto')) return Icons.inventory_2_outlined;
    if (lower.contains('cliente')) return Icons.person_add_outlined;
    if (lower.contains('proveedor')) return Icons.business_outlined;
    if (lower.contains('categoria')) return Icons.category_outlined;
    if (lower.contains('invitar')) return Icons.group_add_outlined;
    if (lower.contains('entrada') || lower.contains('stock')) {
      return Icons.add_box_outlined;
    }
    return Icons.chat_outlined;
  }

}
