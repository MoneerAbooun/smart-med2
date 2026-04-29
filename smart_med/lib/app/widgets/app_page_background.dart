import 'package:flutter/material.dart';

class AppPageBackground extends StatelessWidget {
  const AppPageBackground({super.key, required this.child});

  final Widget child;

  static LinearGradient gradientOf(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surface = colorScheme.surface;

    final topGlow = Color.alphaBlend(
      colorScheme.primary.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.26 : 0.18,
      ),
      surface,
    );

    final middleTone = Color.alphaBlend(
      colorScheme.secondary.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.12 : 0.07,
      ),
      surface,
    );

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const <double>[0, 0.46, 1],
      colors: <Color>[topGlow, middleTone, surface],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradientOf(context)),
      child: child,
    );
  }
}
