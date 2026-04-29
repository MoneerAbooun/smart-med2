import 'package:flutter/material.dart';

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.accentColor,
    this.size = 48,
    this.iconSize = 24,
    this.borderRadius = 16,
  });

  final IconData icon;
  final Color? accentColor;
  final double size;
  final double iconSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.2 : 0.12,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: accent),
    );
  }
}
