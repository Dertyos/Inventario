import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../products/data/products_repository.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);
    await _controller.stop();

    final barcodeValue = barcode.rawValue!;
    await _lookupProduct(barcodeValue);
  }

  Future<void> _lookupProduct(String barcodeValue) async {
    if (!mounted) return;

    try {
      final teamId = ref.read(authProvider).teamId;
      final products = await ref
          .read(productsRepositoryProvider)
          .getProducts(teamId, search: barcodeValue);

      // Find exact barcode match
      final match = products
          .where((p) =>
              p.barcode != null &&
              p.barcode!.toLowerCase() == barcodeValue.toLowerCase())
          .toList();

      if (!mounted) return;

      if (match.isNotEmpty) {
        _showProductFoundSheet(match.first, barcodeValue);
      } else {
        _showProductNotFoundSheet(barcodeValue);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSheet(barcodeValue, e.toString());
    }
  }

  void _showProductFoundSheet(ProductModel product, String barcodeValue) {
    final colorScheme = Theme.of(context).colorScheme;
    final cop =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.successBg(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Producto encontrado',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Product card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                product.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (product.categoryName != null)
                                  Text(
                                    product.categoryName!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _InfoChip(
                            label: 'Precio',
                            value: cop.format(product.price),
                            color: colorScheme.primary,
                          ),
                          _InfoChip(
                            label: 'Stock',
                            value: '${product.stock}',
                            color: product.isLowStock
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          _InfoChip(
                            label: 'SKU',
                            value: product.sku.isNotEmpty ? product.sku : '-',
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pop(); // close scanner
                        context.go('/inventory');
                      },
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Agregar stock'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pop(); // close scanner
                        context.go('/sales/new');
                      },
                      icon: const Icon(Icons.point_of_sale_rounded),
                      label: const Text('Vender'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resumeScanner();
                },
                child: const Text('Escanear otro'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(_resumeScanner);
  }

  void _showProductNotFoundSheet(String barcodeValue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.warningBg(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: AppColors.warning,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Producto no encontrado',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No se encontró un producto con el código:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  barcodeValue,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop(); // close scanner
                  context.push('/products/new', extra: barcodeValue);
                },
                icon: const Icon(Icons.add),
                label: const Text('Crear nuevo producto'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resumeScanner();
                },
                child: const Text('Escanear otro'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(_resumeScanner);
  }

  void _showErrorSheet(String barcodeValue, String error) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.dangerBg(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Error al buscar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No se pudo buscar el código $barcodeValue. Verifica tu conexión e intenta de nuevo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resumeScanner();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(_resumeScanner);
  }

  void _resumeScanner() {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),

          // Semi-transparent overlay with cutout
          _ScannerOverlay(
            isProcessing: _isProcessing,
          ),

          // Top bar with close and flash buttons
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
                    _CircleButton(
                      icon: Icons.close,
                      onPressed: () => context.pop(),
                    ),
                    // Title
                    Text(
                      'Escanear código',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    // Flash toggle
                    _CircleButton(
                      icon: Icons.flash_on,
                      onPressed: () => _controller.toggleTorch(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom hint
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Buscando producto...',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: const Text(
                          'Apunta la cámara al código de barras',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Semi-transparent overlay with a rectangular cutout for the scan area.
class _ScannerOverlay extends StatelessWidget {
  final bool isProcessing;

  const _ScannerOverlay({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaWidth = constraints.maxWidth * 0.75;
        final scanAreaHeight = scanAreaWidth * 0.6;
        final left = (constraints.maxWidth - scanAreaWidth) / 2;
        final top = (constraints.maxHeight - scanAreaHeight) / 2 - 40;

        return Stack(
          children: [
            // Dark overlay with cutout
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: scanAreaWidth,
                      height: scanAreaHeight,
                      decoration: BoxDecoration(
                        color: Colors.red, // any opaque color for cutout
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scan area border with animated corners
            Positioned(
              left: left,
              top: top,
              child: Container(
                width: scanAreaWidth,
                height: scanAreaHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isProcessing
                        ? AppColors.info
                        : Colors.white.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Corner accents
                    ..._buildCorners(scanAreaWidth, scanAreaHeight),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildCorners(double width, double height) {
    const cornerSize = 24.0;
    const cornerWidth = 3.0;
    const color = Colors.white;

    return [
      // Top-left
      Positioned(
        top: -1,
        left: -1,
        child: _Corner(
          size: cornerSize,
          width: cornerWidth,
          color: color,
          topLeft: true,
        ),
      ),
      // Top-right
      Positioned(
        top: -1,
        right: -1,
        child: _Corner(
          size: cornerSize,
          width: cornerWidth,
          color: color,
          topRight: true,
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: -1,
        left: -1,
        child: _Corner(
          size: cornerSize,
          width: cornerWidth,
          color: color,
          bottomLeft: true,
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: -1,
        right: -1,
        child: _Corner(
          size: cornerSize,
          width: cornerWidth,
          color: color,
          bottomRight: true,
        ),
      ),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double size;
  final double width;
  final Color color;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _Corner({
    required this.size,
    required this.width,
    required this.color,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          width: width,
          color: color,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double width;
  final Color color;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  _CornerPainter({
    required this.width,
    required this.color,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (topLeft) {
      canvas.drawLine(Offset(0, size.height), Offset.zero, paint);
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(0, 0), Offset(size.width, 0), paint);
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint);
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), paint);
    }
    if (bottomRight) {
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), paint);
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
