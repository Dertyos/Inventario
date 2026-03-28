import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Normaliza un número de teléfono colombiano al formato wa.me (sin +).
/// Ejemplos:
///   "3001234567"         → "573001234567"
///   "+57 300 123 4567"   → "573001234567"
///   "573001234567"       → "573001234567"
///   Otros países         → dígitos tal cual
String normalizePhoneForWa(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('57') && digits.length == 12) return digits;
  if (digits.startsWith('3') && digits.length == 10) return '57$digits';
  return digits;
}

/// Genera una URL wa.me con mensaje pre-llenado.
String buildWaUrl(String phone, String message) {
  final normalized = normalizePhoneForWa(phone);
  return 'https://wa.me/$normalized?text=${Uri.encodeComponent(message)}';
}

/// Abre WhatsApp con un mensaje pre-llenado.
/// Si WhatsApp no está instalado, abre WhatsApp Web en el browser.
/// Si tampoco funciona, muestra un SnackBar.
Future<void> openWhatsApp(
  BuildContext context,
  String phone,
  String message,
) async {
  final uri = Uri.parse(buildWaUrl(phone, message));
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }
}

/// Abre el marcador telefónico con el número dado.
Future<void> openPhone(BuildContext context, String phone) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final uri = Uri.parse('tel:$digits');
  try {
    await launchUrl(uri);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el marcador')),
      );
    }
  }
}
