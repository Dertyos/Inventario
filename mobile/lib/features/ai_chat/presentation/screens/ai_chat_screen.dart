import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ai/ai_service.dart';
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
  ParsedTransaction? _parsed;
  String? _error;

  final _examples = [
    'Venta de 5 tornillos a Pedro por 25 mil',
    'Compra de 20 clavos al proveedor García',
    'Vendí 3 martillos a 15 mil cada uno',
    'Entrada de 100 tuercas a bodega',
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
    setState(() {});
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      _showError('Micrófono no disponible');
      return;
    }

    setState(() {
      _isListening = true;
      _error = null;
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
      localeId: 'es_CO',
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _processText(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _isProcessing = true;
      _parsed = null;
      _error = null;
    });

    final teamId = ref.read(authProvider).teamId;

    try {
      final result =
          await ref.read(aiServiceProvider).parseTransaction(teamId, text);
      setState(() {
        _parsed = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No pude entender. Intenta de nuevo.';
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _confirmTransaction() {
    if (_parsed == null) return;

    // Navigate to the appropriate creation screen with pre-filled data
    if (_parsed!.type == TransactionType.sale) {
      context.push('/sales/new', extra: _parsed);
    } else {
      // TODO: Purchase flow when implemented
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compra registrada (flujo pendiente)')),
      );
    }
  }

  void _reset() {
    setState(() {
      _controller.clear();
      _parsed = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.mic, size: 20, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            const Text('Registrar con voz'),
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
                      hintText: 'Ej: Venta de 5 tornillos a Pedro...',
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
                // Mic button
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
                // Send button
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic,
                size: 64,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Escuchando...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Describe tu venta o compra',
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
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Registra con tu voz',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Di o escribe una venta o compra en lenguaje natural.\nLa IA la convierte en transacción.',
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
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _controller.text = s;
                        _processText(s);
                      },
                      avatar: Icon(
                        s.toLowerCase().startsWith('venta') ||
                                s.toLowerCase().startsWith('vendí')
                            ? Icons.sell_outlined
                            : Icons.shopping_cart_outlined,
                        size: 14,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedResult(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final parsed = _parsed!;
    final isSale = parsed.type == TransactionType.sale;
    final cop =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transaction type badge
          Card(
            color: isSale
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.blue.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSale
                            ? Icons.sell_rounded
                            : Icons.shopping_cart_rounded,
                        color: isSale ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        isSale ? 'Venta' : 'Compra',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: isSale ? Colors.green : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const Spacer(),
                      if (parsed.confidence >= 0.8)
                        Chip(
                          label: const Text('Alta confianza'),
                          labelStyle: const TextStyle(fontSize: 10),
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )
                      else
                        Chip(
                          label: const Text('Verificar datos'),
                          labelStyle: const TextStyle(fontSize: 10),
                          backgroundColor:
                              Colors.orange.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
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
          ),
          const SizedBox(height: AppSpacing.md),

          // Items
          Text('Productos',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          ...parsed.items.map(
            (item) => Card(
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
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      )
                    : null,
              ),
            ),
          ),

          // Customer/Supplier
          if (parsed.customerOrSupplier != null) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: Icon(
                  isSale ? Icons.person_outline : Icons.business_outlined,
                ),
                title: Text(parsed.customerOrSupplier!),
                subtitle: Text(isSale ? 'Cliente' : 'Proveedor'),
              ),
            ),
          ],

          // Total
          if (parsed.totalAmount != null) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      cop.format(parsed.totalAmount),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Actions
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
                  onPressed: _confirmTransaction,
                  icon: const Icon(Icons.check),
                  label: Text(
                      isSale ? 'Confirmar venta' : 'Confirmar compra'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
