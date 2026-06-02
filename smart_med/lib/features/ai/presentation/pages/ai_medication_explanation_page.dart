import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/features/ai/data/repositories/ai_preferences_repository.dart';
import 'package:smart_med/features/ai/data/repositories/personalized_explanation_repository.dart';
import 'package:smart_med/features/ai/domain/models/personalized_explanation_models.dart';
import 'package:smart_med/features/ai/presentation/widgets/ai_severity_chip.dart';

class AiMedicationExplanationPage extends StatefulWidget {
  const AiMedicationExplanationPage({
    super.key,
    this.medicationIds = const <String>[],
  });

  final List<String> medicationIds;

  @override
  State<AiMedicationExplanationPage> createState() =>
      _AiMedicationExplanationPageState();
}

class _AiMedicationExplanationPageState
    extends State<AiMedicationExplanationPage> {
  final AiPreferencesRepository _aiPreferencesRepository =
      aiPreferencesRepository;

  Future<PersonalizedExplanationResponse>? _future;

  bool _isPreparing = true;
  bool _simpleLanguage = true;
  bool _showSaferUseTips = true;
  bool _showQuestionsForClinician = true;
  bool _showEvidenceByDefault = false;
  bool _selectedScopeOnly = false;

  @override
  void initState() {
    super.initState();
    _selectedScopeOnly = widget.medicationIds.isNotEmpty;
    _initializePage();
  }

  Future<void> _initializePage() async {
    final preferences = await _aiPreferencesRepository.loadPreferences();
    final nextFuture = _loadExplanation(
      simpleLanguage: preferences.simpleLanguageMode,
      selectedScopeOnly: _selectedScopeOnly,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _simpleLanguage = preferences.simpleLanguageMode;
      _showSaferUseTips = preferences.showSaferUseTips;
      _showQuestionsForClinician = preferences.showQuestionsForClinician;
      _showEvidenceByDefault = preferences.showEvidenceByDefault;
      _future = nextFuture;
      _isPreparing = false;
    });
  }

  Future<PersonalizedExplanationResponse> _loadExplanation({
    bool? simpleLanguage,
    bool? selectedScopeOnly,
  }) {
    final shouldUseSelectedScope = selectedScopeOnly ?? _selectedScopeOnly;
    return personalizedExplanationRepository.generateExplanation(
      medicationIds: shouldUseSelectedScope
          ? widget.medicationIds
          : const <String>[],
      simpleLanguage: simpleLanguage ?? _simpleLanguage,
    );
  }

  Future<void> _refresh() async {
    final nextFuture = _loadExplanation();
    setState(() {
      _future = nextFuture;
    });
    await nextFuture;
  }

  Future<void> _toggleSimpleLanguage(bool value) async {
    await _aiPreferencesRepository.setSimpleLanguageMode(value);
    final nextFuture = _loadExplanation(simpleLanguage: value);

    if (!mounted) {
      return;
    }

    setState(() {
      _simpleLanguage = value;
      _future = nextFuture;
    });
  }

  void _changeScope(bool selectedScopeOnly) {
    final nextFuture = _loadExplanation(selectedScopeOnly: selectedScopeOnly);
    setState(() {
      _selectedScopeOnly = selectedScopeOnly;
      _future = nextFuture;
    });
  }

  Color _severityColor(BuildContext context, String severity) {
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

  Widget _buildControls(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.text('ai.guideSettings'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(value: _simpleLanguage, onChanged: _toggleSimpleLanguage),
            ],
          ),
          Text(
            _simpleLanguage
                ? l10n.text('ai.simpleOn')
                : l10n.text('ai.simpleOff'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.medicationIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: Text(l10n.text('ai.selectedMedicine')),
                  selected: _selectedScopeOnly,
                  onSelected: (_) => _changeScope(true),
                ),
                ChoiceChip(
                  label: Text(l10n.text('ai.allMedicines')),
                  selected: !_selectedScopeOnly,
                  onSelected: (_) => _changeScope(false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    PersonalizedExplanationResponse response,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.text('ai.quickSummary'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      response.quickSummary.isNotEmpty
                          ? response.quickSummary
                          : response.overview,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AiSeverityChip(severity: response.overallSeverity),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSummaryMetric(
                context,
                label: l10n.text('ai.interactions'),
                value: response.interactionCount.toString(),
                icon: Icons.compare_arrows,
              ),
              _buildSummaryMetric(
                context,
                label: l10n.text('ai.cautions'),
                value: response.cautionCount.toString(),
                icon: Icons.warning_amber_rounded,
              ),
              _buildSummaryMetric(
                context,
                label: l10n.text('ai.source'),
                value: response.groundedOnly
                    ? l10n.text('ai.rules')
                    : l10n.text('ai.aiRules'),
                icon: Icons.dataset_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            l10n.format('ai.metric', {
              'label': label,
              'value': l10n.isolate(value),
            }),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCompletenessCard(
    BuildContext context,
    ProfileCompletenessItem profileCompleteness,
  ) {
    if (profileCompleteness.summary.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final hasMissingFields = profileCompleteness.missingFields.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasMissingFields
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasMissingFields
                ? l10n.text('ai.profileDetailsToAdd')
                : l10n.text('ai.profileReady'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(profileCompleteness.summary),
          if (hasMissingFields) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profileCompleteness.missingFields
                  .map(
                    (item) => Chip(
                      label: Text(l10n.isolate(item.replaceAll('_', ' '))),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAlertSection(
    BuildContext context,
    String title,
    List<ExplanationAlertItem> alerts,
  ) {
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, title),
        ...alerts.map(
          (alert) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _severityColor(
                  context,
                  alert.severity,
                ).withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AiSeverityChip(severity: alert.severity),
                const SizedBox(height: 10),
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(alert.detail),
                if (alert.sourceIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.format('ai.whyAppears', {
                      'sources': l10n.isolate(alert.sourceIds.join(', ')),
                    }),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationSection(
    BuildContext context,
    PersonalizedExplanationResponse response,
  ) {
    if (response.medicationExplanations.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final badgeByMedicationId = {
      for (final badge in response.medicationBadges) badge.medicationId: badge,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, l10n.text('ai.medicineOverview')),
        ...response.medicationExplanations.map(
          (item) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isolate(item.name),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (item.genericName != null &&
                              item.genericName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              l10n.format('ai.generic', {
                                'name': l10n.isolate(item.genericName!),
                              }),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (badgeByMedicationId[item.medicationId] != null)
                      AiSeverityChip(
                        severity:
                            badgeByMedicationId[item.medicationId]!.severity,
                      ),
                  ],
                ),
                if (badgeByMedicationId[item.medicationId] != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    badgeByMedicationId[item.medicationId]!.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(item.explanation),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStringSection(
    BuildContext context,
    String title,
    List<String> values,
    IconData icon,
  ) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, title),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: values
                .map(
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
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildEvidenceSection(
    BuildContext context,
    List<EvidenceItem> evidence,
  ) {
    if (evidence.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, l10n.text('ai.evidence')),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: ExpansionTile(
            initiallyExpanded: _showEvidenceByDefault,
            title: Text(
              _showEvidenceByDefault
                  ? l10n.text('ai.evidenceDetails')
                  : l10n.text('ai.showEvidence'),
            ),
            children: evidence
                .map(
                  (item) => ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.detail),
                    trailing: Text(
                      item.sourceType,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataCard(
    BuildContext context,
    PersonalizedExplanationResponse response,
  ) {
    final generatedAt = response.generatedAt?.toLocal();
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final generatedAtText = generatedAt == null
        ? null
        : '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} ${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: response.groundedOnly
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            response.groundedOnly
                ? l10n.text('ai.rulesGuide')
                : l10n.text('ai.aiGuide'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            response.groundedOnly
                ? l10n.text('ai.rulesGuideBody')
                : l10n.text('ai.aiGuideBody'),
          ),
          const SizedBox(height: 10),
          Text(
            [
              l10n.format('ai.sourceLine', {
                'value': l10n.isolate(response.source),
              }),
              if (response.model != null && response.model!.isNotEmpty)
                l10n.format('ai.modelLine', {
                  'value': l10n.isolate(response.model!),
                }),
              if (generatedAtText != null)
                l10n.format('ai.generatedLine', {
                  'value': l10n.isolate(generatedAtText),
                }),
            ].join('  |  '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PersonalizedExplanationResponse response,
  ) {
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildControls(context),
          const SizedBox(height: 16),
          _buildSummaryCard(context, response),
          const SizedBox(height: 16),
          _buildProfileCompletenessCard(context, response.profileCompleteness),
          const SizedBox(height: 16),
          _buildAlertSection(
            context,
            l10n.text('ai.warningsForYou'),
            response.personalizedRisks,
          ),
          if (response.personalizedRisks.isNotEmpty) const SizedBox(height: 8),
          _buildAlertSection(
            context,
            l10n.text('ai.interactionSummary'),
            response.interactionAlerts,
          ),
          if (response.interactionAlerts.isNotEmpty) const SizedBox(height: 8),
          _buildMedicationSection(context, response),
          if (response.medicationExplanations.isNotEmpty)
            const SizedBox(height: 8),
          if (_showSaferUseTips)
            _buildStringSection(
              context,
              l10n.text('ai.saferSteps'),
              response.saferBehaviorTips,
              Icons.shield_outlined,
            ),
          if (_showSaferUseTips && response.saferBehaviorTips.isNotEmpty)
            const SizedBox(height: 16),
          if (_showQuestionsForClinician)
            _buildStringSection(
              context,
              l10n.text('ai.questionsForClinician'),
              response.questionsForClinician,
              Icons.help_outline,
            ),
          if (_showQuestionsForClinician &&
              response.questionsForClinician.isNotEmpty)
            const SizedBox(height: 16),
          _buildStringSection(
            context,
            l10n.text('ai.informationToAdd'),
            response.missingInformation,
            Icons.info_outline,
          ),
          if (response.missingInformation.isNotEmpty)
            const SizedBox(height: 16),
          _buildMetadataCard(context, response),
          const SizedBox(height: 16),
          _buildEvidenceSection(context, response.evidence),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final l10n = context.l10n;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.error_outline,
          size: 56,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.text('ai.errorTitle'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(error.toString(), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _future = _loadExplanation();
            });
          },
          child: Text(l10n.text('common.retry')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.text('ai.title')),
        centerTitle: true,
      ),
      body: _isPreparing || _future == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<PersonalizedExplanationResponse>(
              future: _future!,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildErrorState(context, snapshot.error!);
                }

                final response = snapshot.data;
                if (response == null) {
                  return _buildErrorState(
                    context,
                    context.l10n.text('ai.emptyGuide'),
                  );
                }

                return _buildContent(context, response);
              },
            ),
    );
  }
}
