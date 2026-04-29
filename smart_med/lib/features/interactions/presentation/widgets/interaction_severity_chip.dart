import 'package:flutter/material.dart';

class InteractionSeverityChip extends StatelessWidget {
  const InteractionSeverityChip({
    super.key,
    required this.severity,
  });

  final String severity;

  Color _colorForSeverity(BuildContext context) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'major':
      case 'severe':
        return Colors.red.shade700;
      case 'moderate':
        return Colors.orange.shade700;
      case 'low':
        return Colors.green.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForSeverity(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
