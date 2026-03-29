import 'package:flutter/material.dart';

class AiPrefillBanner extends StatelessWidget {
  final double confidence;
  final String rawText;

  const AiPrefillBanner({
    super.key,
    required this.confidence,
    required this.rawText,
  });

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.8
        ? Colors.green
        : (confidence >= 0.5 ? Colors.orange : Colors.red);
        
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-completado por IA (Confianza: ${(confidence * 100).toInt()}%)',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '"$rawText"',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
