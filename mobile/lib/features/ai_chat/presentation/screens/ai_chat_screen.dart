import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ai/ai_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../suppliers/data/suppliers_repository.dart';

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
  ParsedCommand? _parsed;
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
      _parsed = null;
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
      setState(() {
        _parsed = result;
        _isProcessing = false;
      });
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

  Future<void> _confirmAction() async {
    if (_parsed == null) return;

    final teamId = ref.read(authProvider).teamId;
    final dio = ref.read(dioProvider);

    // For sales, navigate to the sales screen
    if (_parsed!.action == CommandAction.createSale) {
      context.push('/sales/new');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String successMsg;

      switch (_parsed!.action) {
        case CommandAction.createProduct:
          final p = _parsed!.product!;
          await dio.post('/teams/$teamId/products', data: {
            'name': p.name,
            'sku': p.sku ?? '${p.name.substring(0, 3).toUpperCase()}-001',
            'price': p.price,
            if (p.cost != null) 'cost': p.cost,
            if (p.categoryId != null) 'categoryId': p.categoryId,
            'minStock': p.minStock ?? 5,
          });
          successMsg = 'Producto "${p.name}" creado';

        case CommandAction.createCategory:
          final c = _parsed!.category!;
          await dio.post('/teams/$teamId/categories', data: {
            'name': c.name,
            if (c.description != null) 'description': c.description,
          });
          successMsg = 'Categoria "${c.name}" creada';

        case CommandAction.createCustomer:
          final c = _parsed!.customer!;
          await dio.post('/teams/$teamId/customers', data: {
            'name': c.name,
            if (c.phone != null) 'phone': c.phone,
            if (c.email != null) 'email': c.email,
            if (c.documentType != null) 'documentType': c.documentType,
            if (c.documentNumber != null) 'documentNumber': c.documentNumber,
            if (c.address != null) 'address': c.address,
          });
          successMsg = 'Cliente "${c.name}" creado';

        case CommandAction.createSupplier:
          final s = _parsed!.supplier!;
          await dio.post('/teams/$teamId/suppliers', data: {
            'name': s.name,
            if (s.nit != null) 'nit': s.nit,
            if (s.contactName != null) 'contactName': s.contactName,
            if (s.phone != null) 'phone': s.phone,
            if (s.email != null) 'email': s.email,
            if (s.address != null) 'address': s.address,
          });
          successMsg = 'Proveedor "${s.name}" creado';

        case CommandAction.addStock:
          final inv = _parsed!.inventory!;
          if (inv.productId == null) {
            throw Exception(
                'Producto "${inv.productName}" no encontrado en el catalogo');
          }
          await dio.post('/teams/$teamId/inventory/movements', data: {
            'type': 'in',
            'productId': inv.productId,
            'quantity': inv.quantity,
            if (inv.reason != null) 'reason': inv.reason,
          });
          successMsg = 'Entrada de ${inv.quantity}x ${inv.productName}';

        case CommandAction.removeStock:
          final inv = _parsed!.inventory!;
          if (inv.productId == null) {
            throw Exception(
                'Producto "${inv.productName}" no encontrado en el catalogo');
          }
          await dio.post('/teams/$teamId/inventory/movements', data: {
            'type': 'out',
            'productId': inv.productId,
            'quantity': inv.quantity,
            if (inv.reason != null) 'reason': inv.reason,
          });
          successMsg = 'Salida de ${inv.quantity}x ${inv.productName}';

        case CommandAction.inviteMember:
          final m = _parsed!.member!;
          await dio.post('/teams/$teamId/members', data: {
            'email': m.email,
            if (m.role != null) 'role': m.role,
          });
          successMsg = 'Invitacion enviada a ${m.email}';

        case CommandAction.createPurchase:
          final t = _parsed!.transaction!;
          // Resolve supplier by name from cached list
          String? supplierId;
          if (t.customerOrSupplier != null) {
            final suppliers =
                await ref.read(suppliersProvider(teamId).future);
            final normalizedInput = t.customerOrSupplier!.toLowerCase();
            try {
              final match = suppliers.firstWhere(
                (s) =>
                    s.name.toLowerCase().contains(normalizedInput) ||
                    normalizedInput.contains(s.name.toLowerCase()),
              );
              supplierId = match.id;
            } catch (_) {
              // No match found
            }
          }
          if (supplierId == null) {
            throw Exception(
              t.customerOrSupplier != null
                  ? 'Proveedor "${t.customerOrSupplier}" no encontrado. Créalo primero en Proveedores.'
                  : 'Indica el proveedor para registrar la compra.',
            );
          }
          await dio.post('/teams/$teamId/purchases', data: {
            'supplierId': supplierId,
            'items': t.items
                .where((i) => i.matchedProductId != null)
                .map((i) => {
                      'productId': i.matchedProductId,
                      'quantity': i.quantity,
                      'unitCost': i.unitPrice ?? 0,
                    })
                .toList(),
            if (t.customerOrSupplier != null)
              'notes': 'Proveedor: ${t.customerOrSupplier}',
          });
          successMsg = 'Compra registrada';

        case CommandAction.createSale:
          successMsg = '';
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _successMsg = successMsg;
          _parsed = null;
        });
        _showSnack(successMsg);
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
  }

  void _reset() {
    setState(() {
      _controller.clear();
      _parsed = null;
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
            child: _parsed != null
                ? _buildParsedResult(context)
                : _buildInputArea(context),
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

  // ---------------------------------------------------------------------------
  // Parsed result display
  // ---------------------------------------------------------------------------

  Widget _buildParsedResult(BuildContext context) {
    final parsed = _parsed!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionHeader(context, parsed),
          const SizedBox(height: AppSpacing.md),

          // Action-specific content
          switch (parsed.action) {
            CommandAction.createSale ||
            CommandAction.createPurchase =>
              _buildTransactionResult(context, parsed),
            CommandAction.createProduct =>
              _buildProductResult(context, parsed.product!),
            CommandAction.createCategory =>
              _buildCategoryResult(context, parsed.category!),
            CommandAction.createCustomer =>
              _buildCustomerResult(context, parsed.customer!),
            CommandAction.createSupplier =>
              _buildSupplierResult(context, parsed.supplier!),
            CommandAction.addStock ||
            CommandAction.removeStock =>
              _buildInventoryResult(context, parsed),
            CommandAction.inviteMember =>
              _buildMemberResult(context, parsed.member!),
          },

          const SizedBox(height: AppSpacing.lg),

          // Actions row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Otra vez'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _confirmAction,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: Text(_confirmLabel(parsed.action)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _confirmLabel(CommandAction action) {
    switch (action) {
      case CommandAction.createSale:
        return 'Ir a nueva venta';
      case CommandAction.createPurchase:
        return 'Confirmar compra';
      case CommandAction.createProduct:
        return 'Crear producto';
      case CommandAction.createCategory:
        return 'Crear categoria';
      case CommandAction.createCustomer:
        return 'Crear cliente';
      case CommandAction.createSupplier:
        return 'Crear proveedor';
      case CommandAction.addStock:
        return 'Registrar entrada';
      case CommandAction.removeStock:
        return 'Registrar salida';
      case CommandAction.inviteMember:
        return 'Enviar invitacion';
    }
  }

  Widget _buildActionHeader(BuildContext context, ParsedCommand parsed) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, label, color) = _actionMeta(parsed.action);

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                _confidenceBadge(parsed.confidence),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '"${parsed.rawText}"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String, Color) _actionMeta(CommandAction action) {
    switch (action) {
      case CommandAction.createSale:
        return (Icons.sell_rounded, 'Venta', Colors.green);
      case CommandAction.createPurchase:
        return (Icons.shopping_cart_rounded, 'Compra', Colors.blue);
      case CommandAction.createProduct:
        return (Icons.inventory_2_rounded, 'Nuevo producto', Colors.purple);
      case CommandAction.createCategory:
        return (Icons.category_rounded, 'Nueva categoria', Colors.teal);
      case CommandAction.createCustomer:
        return (Icons.person_add_rounded, 'Nuevo cliente', Colors.indigo);
      case CommandAction.createSupplier:
        return (Icons.business_rounded, 'Nuevo proveedor', Colors.orange);
      case CommandAction.addStock:
        return (Icons.add_box_rounded, 'Entrada de stock', Colors.green);
      case CommandAction.removeStock:
        return (Icons.outbox_rounded, 'Salida de stock', Colors.red);
      case CommandAction.inviteMember:
        return (Icons.group_add_rounded, 'Invitar miembro', Colors.cyan);
    }
  }

  Widget _confidenceBadge(double confidence) {
    final isHigh = confidence >= 0.8;
    return Chip(
      label: Text(isHigh ? 'Alta confianza' : 'Verificar datos'),
      labelStyle: const TextStyle(fontSize: 10),
      backgroundColor: isHigh
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.orange.withValues(alpha: 0.1),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  // ---------------------------------------------------------------------------
  // Action-specific result builders
  // ---------------------------------------------------------------------------

  Widget _buildTransactionResult(BuildContext context, ParsedCommand parsed) {
    final t = parsed.transaction!;
    final cop =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Productos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        ...t.items.map((item) => _itemTile(context, item, cop)),
        if (t.customerOrSupplier != null) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ListTile(
              leading: Icon(
                parsed.action == CommandAction.createSale
                    ? Icons.person_outline
                    : Icons.business_outlined,
              ),
              title: Text(t.customerOrSupplier!),
              subtitle: Text(parsed.action == CommandAction.createSale
                  ? 'Cliente'
                  : 'Proveedor'),
            ),
          ),
        ],
        if (t.totalAmount != null) ...[
          const SizedBox(height: AppSpacing.md),
          _totalCard(context, cop.format(t.totalAmount)),
        ],
      ],
    );
  }

  Widget _buildProductResult(BuildContext context, ProductData p) {
    final cop =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    return Column(
      children: [
        _detailTile(context, 'Nombre', p.name, Icons.inventory_2_outlined),
        if (p.sku != null) _detailTile(context, 'Código interno', p.sku!, Icons.qr_code),
        _detailTile(
            context, 'Precio', cop.format(p.price), Icons.attach_money),
        if (p.cost != null)
          _detailTile(context, 'Costo', cop.format(p.cost), Icons.money_off),
        if (p.categoryName != null)
          _detailTile(context, 'Categoria', p.categoryName!,
              Icons.category_outlined),
        _detailTile(context, 'Stock minimo', '${p.minStock ?? 5}',
            Icons.warning_amber),
      ],
    );
  }

  Widget _buildCategoryResult(BuildContext context, CategoryData c) {
    return Column(
      children: [
        _detailTile(context, 'Nombre', c.name, Icons.category_outlined),
        if (c.description != null)
          _detailTile(
              context, 'Descripcion', c.description!, Icons.description),
      ],
    );
  }

  Widget _buildCustomerResult(BuildContext context, CustomerData c) {
    return Column(
      children: [
        _detailTile(context, 'Nombre', c.name, Icons.person_outline),
        if (c.phone != null)
          _detailTile(context, 'Telefono', c.phone!, Icons.phone),
        if (c.email != null)
          _detailTile(context, 'Email', c.email!, Icons.email_outlined),
        if (c.documentType != null)
          _detailTile(
              context,
              'Documento',
              '${c.documentType} ${c.documentNumber ?? ''}',
              Icons.badge_outlined),
        if (c.address != null)
          _detailTile(
              context, 'Direccion', c.address!, Icons.location_on_outlined),
      ],
    );
  }

  Widget _buildSupplierResult(BuildContext context, SupplierData s) {
    return Column(
      children: [
        _detailTile(context, 'Nombre', s.name, Icons.business_outlined),
        if (s.nit != null)
          _detailTile(context, 'NIT', s.nit!, Icons.badge_outlined),
        if (s.contactName != null)
          _detailTile(
              context, 'Contacto', s.contactName!, Icons.person_outline),
        if (s.phone != null)
          _detailTile(context, 'Telefono', s.phone!, Icons.phone),
        if (s.email != null)
          _detailTile(context, 'Email', s.email!, Icons.email_outlined),
        if (s.address != null)
          _detailTile(
              context, 'Direccion', s.address!, Icons.location_on_outlined),
      ],
    );
  }

  Widget _buildInventoryResult(BuildContext context, ParsedCommand parsed) {
    final inv = parsed.inventory!;
    final isEntry = parsed.action == CommandAction.addStock;
    return Column(
      children: [
        _detailTile(context, 'Producto', inv.productName,
            Icons.inventory_2_outlined),
        _detailTile(context, 'Cantidad', '${inv.quantity}',
            isEntry ? Icons.add_box_outlined : Icons.outbox_outlined),
        _detailTile(
            context, 'Tipo', isEntry ? 'Entrada' : 'Salida', Icons.swap_vert),
        if (inv.reason != null)
          _detailTile(context, 'Razon', inv.reason!, Icons.notes),
        if (inv.productId == null)
          Card(
            color: Colors.orange.withValues(alpha: 0.1),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Producto no encontrado en el catalogo. Crealo primero.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberResult(BuildContext context, MemberData m) {
    return Column(
      children: [
        _detailTile(context, 'Email', m.email, Icons.email_outlined),
        _detailTile(context, 'Rol', m.role ?? 'STAFF', Icons.shield_outlined),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _detailTile(
      BuildContext context, String label, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(value),
        subtitle: Text(label),
      ),
    );
  }

  Widget _itemTile(BuildContext context, ParsedItem item, NumberFormat cop) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${item.quantity}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        title: Text(item.name),
        subtitle: item.unitPrice != null
            ? Text('${cop.format(item.unitPrice)} c/u')
            : null,
        trailing: item.unitPrice != null
            ? Text(
                cop.format(item.unitPrice! * item.quantity),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              )
            : null,
      ),
    );
  }

  Widget _totalCard(BuildContext context, String formatted) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: Theme.of(context).textTheme.titleMedium),
            Text(
              formatted,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
