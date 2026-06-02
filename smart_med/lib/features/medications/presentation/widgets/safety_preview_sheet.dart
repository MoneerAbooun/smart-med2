import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/features/ai/domain/models/personalized_explanation_models.dart';
import 'package:smart_med/features/ai/presentation/widgets/ai_severity_chip.dart';

class SafetyPreviewSheet extends StatelessWidget {
  const SafetyPreviewSheet({
    super.key,
    required this.response,
    required this.confirmLabel,
  });

  final PersonalizedExplanationResponse response;
  final String confirmLabel;

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<String> values,
    required IconData icon,
  }) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...values.map(
            (value) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(value)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _alertStrings(
    BuildContext context,
    List<ExplanationAlertItem> alerts,
  ) {
    final l10n = context.l10n;

    return alerts
        .map(
          (item) =>
              '${l10n.severity(item.severity)}: '
              '${item.title}. ${item.detail}',
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final warningStrings = [
      ..._alertStrings(context, response.interactionAlerts),
      ..._alertStrings(context, response.personalizedRisks),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.text('ai.safetyPreview'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  AiSeverityChip(severity: response.overallSeverity),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                response.quickSummary.isNotEmpty
                    ? response.quickSummary
                    : response.overview,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              _buildSection(
                context,
                title: l10n.text('ai.warnings'),
                values: warningStrings,
                icon: Icons.warning_amber_rounded,
              ),
              _buildSection(
                context,
                title: l10n.text('ai.saferSteps'),
                values: response.saferBehaviorTips,
                icon: Icons.shield_outlined,
              ),
              if (response.profileCompleteness.missingFields.isNotEmpty)
                _buildSection(
                  context,
                  title: l10n.text('ai.profileDetailsToAdd'),
                  values: [response.profileCompleteness.summary],
                  icon: Icons.info_outline,
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.text('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
