import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/data/medicine/medicine_name_entry.dart';
import 'package:smart_med/data/medicine/medicine_name_repository.dart';
import 'package:smart_med/features/interactions/data/drug_interaction_lookup_repository.dart';
import 'package:smart_med/features/interactions/data/drug_interaction_repository.dart';
import 'package:smart_med/features/interactions/data/interaction_history_repository.dart';
import 'package:smart_med/features/interactions/data/models/drug_interaction_record.dart';
import 'package:smart_med/features/interactions/data/models/interaction_history_record.dart';
import 'package:smart_med/features/interactions/domain/models/drug_interaction_lookup_result.dart';
import 'package:smart_med/features/interactions/presentation/widgets/interaction_severity_chip.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_search_history_repository.dart';
import 'package:smart_med/features/medicine_search/presentation/widgets/medicine_name_suggestion_helpers.dart';
import 'package:smart_med/features/medications/data/repositories/medication_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/presentation/pages/add_medication_page.dart';

class PatientMedicationInteractionPage extends StatefulWidget {
  const PatientMedicationInteractionPage({super.key});

  @override
  State<PatientMedicationInteractionPage> createState() =>
      _PatientMedicationInteractionPageState();
}

class _PatientMedicationInteractionPageState
    extends State<PatientMedicationInteractionPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _newDrugController = TextEditingController();
  final FocusNode _newDrugFocusNode = FocusNode();

  final DrugInteractionLookupRepository _lookupRepository =
      drugInteractionLookupRepository;
  final DrugInteractionRepository _drugInteractionRepository =
      drugInteractionRepository;
  final InteractionHistoryRepository _interactionHistoryRepository =
      interactionHistoryRepository;
  final MedicationRepository _medicationRepository = medicationRepository;
  final MedicineSearchHistoryRepository _medicineSearchHistoryRepository =
      medicineSearchHistoryRepository;
  final MedicineNameRepository _medicineNameRepository = medicineNameRepository;

  bool _isChecking = false;
  String? _errorMessage;
  List<String> _selectedMedicationKeys = const <String>[];
  List<_PatientMedicationInteractionResult> _results =
      const <_PatientMedicationInteractionResult>[];
  List<String> _recentMedicineSearches = const <String>[];
  List<MedicineNameEntry> _medicineNameEntries = const <MedicineNameEntry>[];

  @override
  void initState() {
    super.initState();
    _newDrugController.addListener(_onInputChanged);
    _newDrugFocusNode.addListener(_onInputChanged);
    _loadSearchHistory();
    _loadMedicineNameEntries();
  }

  @override
  void dispose() {
    _newDrugController.removeListener(_onInputChanged);
    _newDrugFocusNode.removeListener(_onInputChanged);
    _newDrugController.dispose();
    _newDrugFocusNode.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadSearchHistory() async {
    final history = await _medicineSearchHistoryRepository.loadHistory();

    if (!mounted) return;

    setState(() {
      _recentMedicineSearches = history;
    });
  }

  Future<void> _loadMedicineNameEntries() async {
    try {
      final entries = await _medicineNameRepository.loadEntries();

      if (!mounted) return;

      setState(() {
        _medicineNameEntries = entries;
      });
    } catch (_) {
      // Suggestions are optional. The backend check still works without them.
    }
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

  String _medicationKey(MedicationRecord medication) {
    return medication.id ?? medication.name.trim().toLowerCase();
  }

  String _medicationSearchName(MedicationRecord medication) {
    final genericName = medication.genericName?.trim();
    if (genericName != null && genericName.isNotEmpty) {
      return genericName;
    }

    final brandName = medication.brandName?.trim();
    if (brandName != null && brandName.isNotEmpty) {
      return brandName;
    }

    return medication.name.trim();
  }

  String _medicationSubtitle(MedicationRecord medication) {
    final parts = <String>[];

    final genericName = medication.genericName?.trim();
    if (genericName != null &&
        genericName.isNotEmpty &&
        genericName.toLowerCase() != medication.name.trim().toLowerCase()) {
      parts.add(genericName);
    }

    final dosage = medication.dosage.trim();
    if (dosage.isNotEmpty && dosage != '0 mg') {
      parts.add(dosage);
    }

    return parts.join(' | ');
  }

  void _syncSelectedMedications(List<MedicationRecord> medications) {
    final availableKeys = medications.map(_medicationKey).toSet();
    final selected = _selectedMedicationKeys
        .where(availableKeys.contains)
        .toList(growable: false);

    if (selected.length != _selectedMedicationKeys.length) {
      _selectedMedicationKeys = selected;
    }
  }

  List<MedicineNameEntry> _filteredMedicineSuggestions() {
    if (!_newDrugFocusNode.hasFocus) {
      return const <MedicineNameEntry>[];
    }

    return filterMedicineNameSuggestions(
      _medicineNameEntries,
      _newDrugController.text,
    );
  }

  void _applyMedicineSuggestion(MedicineNameEntry entry) {
    final value = medicineEntrySearchValue(entry);

    setState(() {
      _newDrugController.text = value;
      _newDrugController.selection = TextSelection.collapsed(
        offset: value.length,
      );
      _errorMessage = null;
    });
  }

  Future<void> _saveMedicineSearch(String value) async {
    final history = await _medicineSearchHistoryRepository.saveSearch(value);

    if (!mounted) return;

    setState(() {
      _recentMedicineSearches = history;
    });
  }

  void _applyRecentMedicine(String medicine) {
    setState(() {
      _newDrugController.text = medicine;
      _newDrugController.selection = TextSelection.collapsed(
        offset: medicine.length,
      );
      _errorMessage = null;
    });
  }

  String? _validateNewDrugName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return context.l10n.text('patientInteractions.new.validation');
    }

    return null;
  }

  Future<void> _checkAgainstPatientMedications(
    List<MedicationRecord> medications,
  ) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedMedications = medications
        .where((medication) {
          return _selectedMedicationKeys.contains(_medicationKey(medication));
        })
        .toList(growable: false);

    if (selectedMedications.isEmpty) {
      setState(() {
        _errorMessage = context.l10n.text(
          'patientInteractions.new.selectSaved',
        );
      });
      return;
    }

    final newMedicineName = _newDrugController.text.trim();

    setState(() {
      _isChecking = true;
      _results = const <_PatientMedicationInteractionResult>[];
    });

    final checkedResults = <_PatientMedicationInteractionResult>[];

    for (final medication in selectedMedications) {
      try {
        final result = await _lookupRepository.checkInteraction(
          firstDrugName: _medicationSearchName(medication),
          secondDrugName: newMedicineName,
        );

        checkedResults.add(
          _PatientMedicationInteractionResult(
            medication: medication,
            result: result,
          ),
        );

        unawaited(_persistResult(result));
      } on DrugInteractionLookupRepositoryException catch (error) {
        checkedResults.add(
          _PatientMedicationInteractionResult(
            medication: medication,
            errorMessage: error.message,
          ),
        );
      } catch (error) {
        checkedResults.add(
          _PatientMedicationInteractionResult(
            medication: medication,
            errorMessage: error.toString(),
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _results = checkedResults;
      _isChecking = false;
    });

    unawaited(_saveMedicineSearch(newMedicineName));
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
      // Keep the live API result visible even if history persistence fails.
    }
  }

  String _sourceSummary(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('rxnorm') &&
        normalized.contains('openfda') &&
        normalized.contains('dailymed')) {
      return context.l10n.text('interactions.source.public');
    }

    return source;
  }

  Widget _buildIntroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

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
            icon: Icons.health_and_safety_outlined,
            size: 52,
            iconSize: 28,
            borderRadius: 16,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.text('patientInteractions.intro.title'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('patientInteractions.intro.subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _selectPatientMedication(String key) {
    setState(() {
      _selectedMedicationKeys = <String>[key];
      _errorMessage = null;
    });
  }

  Widget _buildPatientMedicationSelectionTile(
    BuildContext context,
    MedicationRecord medication,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final key = _medicationKey(medication);
    final isSelected = _selectedMedicationKeys.contains(key);
    final subtitle = _medicationSubtitle(medication);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isChecking ? null : () => _selectPatientMedication(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.55)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.medication_outlined,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.isolate(medication.name),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.isolate(subtitle),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientMedicationCard(
    BuildContext context,
    List<MedicationRecord> medications,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    if (medications.isEmpty) {
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
            Text(
              l10n.text('patientInteractions.saved.title'),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.text('patientInteractions.saved.empty'),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isChecking
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddMedicationPage(),
                          ),
                        );
                      },
                icon: const Icon(Icons.add),
                label: Text(l10n.text('common.addMedicine')),
              ),
            ),
          ],
        ),
      );
    }

    final selectedCount = _selectedMedicationKeys.length;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.text('patientInteractions.saved.title'),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selectedCount > 0
                      ? colorScheme.primaryContainer
                      : colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  selectedCount == 1
                      ? l10n.text('patientInteractions.saved.oneSelected')
                      : l10n.text('patientInteractions.saved.selectOne'),
                  style: textTheme.labelMedium?.copyWith(
                    color: selectedCount > 0
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('patientInteractions.saved.choose'),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ...medications.map(
            (medication) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPatientMedicationSelectionTile(context, medication),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHistoryChips() {
    if (_recentMedicineSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text('common.recentSearches'),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _recentMedicineSearches
              .map((medicine) {
                return ActionChip(
                  label: Text(context.l10n.isolate(medicine)),
                  avatar: const Icon(Icons.history, size: 18),
                  onPressed: _isChecking
                      ? null
                      : () => _applyRecentMedicine(medicine),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildMedicineSuggestionsOrHistory() {
    if (_newDrugFocusNode.hasFocus &&
        _newDrugController.text.trim().isNotEmpty) {
      return MedicineNameSuggestionsList(
        suggestions: _filteredMedicineSuggestions(),
        onSelected: _applyMedicineSuggestion,
        disabled: _isChecking,
      );
    }

    return _buildSearchHistoryChips();
  }

  Widget _buildNewMedicineCard(
    BuildContext context,
    List<MedicationRecord> medications,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

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
              l10n.text('patientInteractions.new.title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.text('patientInteractions.new.subtitle'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newDrugController,
              focusNode: _newDrugFocusNode,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(
                context,
                label: l10n.text('common.medicineName'),
                hint: l10n.text('common.exampleIbuprofen'),
              ),
              validator: _validateNewDrugName,
              onFieldSubmitted: (_) {
                if (!_isChecking) {
                  _checkAgainstPatientMedications(medications);
                }
              },
            ),
            const SizedBox(height: 14),
            _buildMedicineSuggestionsOrHistory(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isChecking || medications.isEmpty
                    ? null
                    : () => _checkAgainstPatientMedications(medications),
                icon: _isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _isChecking
                      ? l10n.text('common.checking')
                      : l10n.text('patientInteractions.new.button'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    _PatientMedicationInteractionResult item,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final result = item.result;

    if (result == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconBadge(
              icon: Icons.error_outline,
              accentColor: colorScheme.error,
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
                    context.l10n.isolate(item.medication.name),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.errorMessage ??
                        context.l10n.text('patientInteractions.result.error'),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(
                icon: Icons.compare_arrows_outlined,
                accentColor: colorScheme.primary,
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
                      '${context.l10n.isolate(result.firstDrug)} + ${context.l10n.isolate(result.secondDrug)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InteractionSeverityChip(severity: result.severity),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(result.summary, style: Theme.of(context).textTheme.bodyMedium),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              context.l10n.text('interactions.result.warnings'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...result.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(warning)),
                  ],
                ),
              ),
            ),
          ],
          if (result.recommendations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              context.l10n.text('interactions.result.next'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...result.recommendations.map(
              (recommendation) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(recommendation)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _sourceSummary(result.source),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_results.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeCount = _results.where((item) {
      final severity = item.result?.severity.toLowerCase() ?? '';
      return severity.contains('none') || severity.contains('low');
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text('patientInteractions.results.title'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n
              .format('patientInteractions.results.summary', <String, String>{
                'safeCount': safeCount.toString(),
                'totalCount': _results.length.toString(),
              }),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ..._results.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildResultCard(context, item),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.text('patientInteractions.title')),
        ),
        body: Center(
          child: Text(context.l10n.text('patientInteractions.signIn')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.text('patientInteractions.title')),
        centerTitle: true,
      ),
      body: StreamBuilder<List<MedicationRecord>>(
        stream: _medicationRepository.watchMedicationRecords(uid: user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  context.l10n.format(
                    'patientInteractions.loadError',
                    <String, String>{
                      'error': context.l10n.isolate(snapshot.error.toString()),
                    },
                  ),
                ),
              ),
            );
          }

          final medications = List<MedicationRecord>.from(
            snapshot.data ?? const <MedicationRecord>[],
          );
          _syncSelectedMedications(medications);

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    _buildIntroCard(context),
                    const SizedBox(height: 14),
                    _buildPatientMedicationCard(context, medications),
                    const SizedBox(height: 14),
                    _buildNewMedicineCard(context, medications),
                    const SizedBox(height: 14),
                    _buildResults(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PatientMedicationInteractionResult {
  const _PatientMedicationInteractionResult({
    required this.medication,
    this.result,
    this.errorMessage,
  });

  final MedicationRecord medication;
  final DrugInteractionLookupResult? result;
  final String? errorMessage;
}
