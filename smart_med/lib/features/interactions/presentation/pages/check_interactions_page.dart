import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/interactions/data/drug_interaction_lookup_repository.dart';
import 'package:smart_med/features/interactions/data/drug_interaction_repository.dart';
import 'package:smart_med/features/interactions/data/interaction_history_repository.dart';
import 'package:smart_med/features/interactions/data/models/drug_interaction_record.dart';
import 'package:smart_med/features/interactions/data/models/interaction_history_record.dart';
import 'package:smart_med/features/interactions/domain/models/drug_interaction_lookup_result.dart';
import 'package:smart_med/features/interactions/presentation/widgets/interaction_severity_chip.dart';

class CheckInteractionsPage extends StatefulWidget {
  const CheckInteractionsPage({super.key});

  @override
  State<CheckInteractionsPage> createState() => _CheckInteractionsPageState();
}

class _CheckInteractionsPageState extends State<CheckInteractionsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstDrugController = TextEditingController();
  final TextEditingController _secondDrugController = TextEditingController();
  final DrugInteractionLookupRepository _lookupRepository =
      drugInteractionLookupRepository;
  final DrugInteractionRepository _drugInteractionRepository =
      drugInteractionRepository;
  final InteractionHistoryRepository _interactionHistoryRepository =
      interactionHistoryRepository;

  bool _isChecking = false;
  String? _errorMessage;
  DrugInteractionLookupResult? _result;

  @override
  void dispose() {
    _firstDrugController.dispose();
    _secondDrugController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
    );
  }

  void _applyExample(String firstDrug, String secondDrug) {
    setState(() {
      _firstDrugController.text = firstDrug;
      _secondDrugController.text = secondDrug;
      _errorMessage = null;
    });
  }

  String? _validateDrugName(String? value, {String? otherValue}) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Please enter a medicine name';
    }

    final otherNormalized = otherValue?.trim() ?? '';
    if (otherNormalized.isNotEmpty &&
        normalized.toLowerCase() == otherNormalized.toLowerCase()) {
      return 'Please enter two different medicines';
    }

    return null;
  }

  Future<void> _checkInteraction() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isChecking = true;
      _result = null;
    });

    try {
      final result = await _lookupRepository.checkInteraction(
        firstDrugName: _firstDrugController.text,
        secondDrugName: _secondDrugController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _isChecking = false;
      });

      unawaited(_persistResult(result));
    } on DrugInteractionLookupRepositoryException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isChecking = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isChecking = false;
      });
    }
  }

  Future<void> _persistResult(DrugInteractionLookupResult result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final interaction = DrugInteractionRecord(
      drugIds: result.queryDrugIds,
      drugNames: result.displayDrugNames,
      severity: result.severity,
      summary: result.summary,
      warnings: result.warnings,
      recommendations: result.recommendations,
      evidenceLevel: result.evidence.isEmpty ? null : result.evidence.first,
      source: result.source,
    );

    final history = InteractionHistoryRecord(
      userId: user.uid,
      medicationIds: result.queryDrugIds,
      drugNames: result.displayDrugNames,
      severity: result.severity,
      summary: result.summary,
      warnings: result.warnings,
      recommendations: result.recommendations,
      checkedAt: DateTime.now(),
      source: result.source,
    );

    try {
      await _drugInteractionRepository.saveInteraction(
        interaction: interaction,
      );
      await _interactionHistoryRepository.saveEntry(
        uid: user.uid,
        entry: history,
      );
    } catch (_) {
      // Keep the live API result visible even if local persistence fails.
    }
  }

  String _sourceSummary(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('rxnorm') &&
        normalized.contains('openfda') &&
        normalized.contains('dailymed')) {
      return 'Grounded with RxNorm, OpenFDA, and DailyMed public data.';
    }

    return source;
  }

  Widget _buildIntroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIconBadge(
            icon: Icons.compare_arrows_outlined,
            size: 52,
            iconSize: 28,
            borderRadius: 16,
          ),
          const SizedBox(height: 14),
          Text(
            'Check drug interactions with live backend data',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter any two medicine names to review interaction severity, warnings, and safer-use recommendations.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ActionChip(
          label: const Text('Warfarin + Ibuprofen'),
          onPressed: () => _applyExample('warfarin', 'ibuprofen'),
        ),
        ActionChip(
          label: const Text('Sildenafil + Nitroglycerin'),
          onPressed: () => _applyExample('sildenafil', 'nitroglycerin'),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medicines to compare',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You can type a brand or generic name.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstDrugController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                context,
                label: 'First medicine',
                hint: 'Example: warfarin',
              ),
              validator: (value) => _validateDrugName(
                value,
                otherValue: _secondDrugController.text,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _secondDrugController,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(
                context,
                label: 'Second medicine',
                hint: 'Example: ibuprofen',
              ),
              validator: (value) => _validateDrugName(
                value,
                otherValue: _firstDrugController.text,
              ),
              onFieldSubmitted: (_) {
                if (!_isChecking) {
                  _checkInteraction();
                }
              },
            ),
            const SizedBox(height: 14),
            _buildExampleChips(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkInteraction,
                icon: _isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _isChecking ? 'Checking interaction...' : 'Check Interaction',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    Color? accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedAccent = accentColor ?? colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: icon,
            accentColor: resolvedAccent,
            size: 44,
            iconSize: 22,
            borderRadius: 14,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    DrugInteractionLookupResult result,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasMechanism = (result.mechanism ?? '').trim().isNotEmpty;
    final resolvedDifferentFromQuery =
        result.firstDrug.trim().toLowerCase() !=
            result.firstQuery.trim().toLowerCase() ||
        result.secondDrug.trim().toLowerCase() !=
            result.secondQuery.trim().toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
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
                      '${result.firstDrug} + ${result.secondDrug}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.summary,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InteractionSeverityChip(severity: result.severity),
            ],
          ),
          if (resolvedDifferentFromQuery) ...[
            const SizedBox(height: 14),
            Text(
              'You entered "${result.firstQuery}" and "${result.secondQuery}".',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if ((result.firstGenericName ?? '').isNotEmpty ||
              (result.secondGenericName ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Generic names: ${result.firstGenericName ?? result.firstDrug} and ${result.secondGenericName ?? result.secondDrug}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (hasMechanism) ...[
            const SizedBox(height: 18),
            _buildBulletSection(
              context,
              icon: Icons.science_outlined,
              title: 'Mechanism',
              items: [result.mechanism!.trim()],
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildBulletSection(
              context,
              icon: Icons.warning_amber_rounded,
              title: 'Warnings',
              items: result.warnings,
            ),
          ],
          if (result.recommendations.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildBulletSection(
              context,
              icon: Icons.health_and_safety_outlined,
              title: 'Recommendations',
              items: result.recommendations,
            ),
          ],
          if (result.evidence.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildBulletSection(
              context,
              icon: Icons.info_outline,
              title: 'Evidence',
              items: result.evidence,
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _sourceSummary(result.source),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState(BuildContext context) {
    if (_errorMessage != null) {
      return _buildStateCard(
        context,
        icon: Icons.error_outline,
        title: 'Interaction check failed',
        message: _errorMessage!,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }

    final result = _result;
    if (result != null) {
      return _buildResultCard(context, result);
    }

    return _buildStateCard(
      context,
      icon: Icons.medication_outlined,
      title: 'Ready to check',
      message:
          'Search a pair to see real interaction data, warnings, and recommendations here.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check Drug Interactions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIntroCard(context),
                const SizedBox(height: 16),
                _buildFormCard(context),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildResultState(context),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
