import 'package:flutter/material.dart';
import '../../core/utils/whatsapp_utils.dart';

const _waGreen = Color(0xFF25D366);

/// Botón de ícono de WhatsApp reutilizable.
///
/// - [phone] == null → ícono gris, deshabilitado, tooltip explicativo
/// - [phone] != null → ícono verde WhatsApp, abre chat al tocar
class WaIconButton extends StatelessWidget {
  final String? phone;
  final String message;
  final double iconSize;

  const WaIconButton({
    super.key,
    required this.phone,
    required this.message,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone != null && phone!.trim().isNotEmpty;

    return Tooltip(
      message: hasPhone ? 'Abrir en WhatsApp' : 'Agrega un teléfono primero',
      child: IconButton(
        icon: Icon(
          Icons.chat_rounded,
          color: hasPhone ? _waGreen : Colors.grey.shade400,
          size: iconSize,
        ),
        onPressed: hasPhone
            ? () => openWhatsApp(context, phone!, message)
            : null,
        splashRadius: 20,
      ),
    );
  }
}
