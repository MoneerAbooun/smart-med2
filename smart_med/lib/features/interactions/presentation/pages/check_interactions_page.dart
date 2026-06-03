import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/data/medicine/medicine_name_entry.dart';
import 'package:smart_med/data/medicine/medicine_name_repository.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/interactions/data/drug_interaction_lookup_repository.dart';
import 'package:smart_med/features/interactions/data/drug_interaction_repository.dart';
import 'package:smart_med/features/interactions/data/interaction_history_repository.dart';
import 'package:smart_med/features/interactions/data/models/drug_interaction_record.dart';
import 'package:smart_med/features/interactions/data/models/interaction_history_record.dart';
import 'package:smart_med/features/interactions/domain/models/drug_interaction_lookup_result.dart';
import 'package:smart_med/features/interactions/presentation/interaction_result_localization.dart';
import 'package:smart_med/features/interactions/presentation/widgets/interaction_severity_chip.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_search_history_repository.dart';
import 'package:smart_med/features/medicine_search/presentation/widgets/medicine_name_suggestion_helpers.dart';

class CheckInteractionsPage extends StatefulWidget {
  const CheckInteractionsPage({super.key});

  @override
  State<CheckInteractionsPage> createState() => _CheckInteractionsPageState();
}

class _CheckInteractionsPageState extends State<CheckInteractionsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstDrugController = TextEditingController();
  final TextEditingController _secondDrugController = TextEditingController();
  final FocusNode _firstDrugFocusNode = FocusNode();
  final FocusNode _secondDrugFocusNode = FocusNode();
  final DrugInteractionLookupRepository _lookupRepository =
      drugInteractionLookupRepository;
  final DrugInteractionRepository _drugInteractionRepository =
      drugInteractionRepository;
  final InteractionHistoryRepository _interactionHistoryRepository =
      interactionHistoryRepository;
  final MedicineSearchHistoryRepository _medicineSearchHistoryRepository =
      medicineSearchHistoryRepository;
  final MedicineNameRepository _medicineNameRepository = medicineNameRepository;

  bool _isChecking = false;
  String? _errorMessage;
  DrugInteractionLookupResult? _result;
  List<String> _recentMedicineSearches = const <String>[];
  List<MedicineNameEntry> _medicineNameEntries = const <MedicineNameEntry>[];

  @override
  void initState() {
    super.initState();
    _firstDrugController.addListener(_onInteractionInputChanged);
    _secondDrugController.addListener(_onInteractionInputChanged);
    _firstDrugFocusNode.addListener(_onInteractionInputChanged);
    _secondDrugFocusNode.addListener(_onInteractionInputChanged);
    _loadSearchHistory();
    _loadMedicineNameEntries();
  }

  @override
  void dispose() {
    _firstDrugController.removeListener(_onInteractionInputChanged);
    _secondDrugController.removeListener(_onInteractionInputChanged);
    _firstDrugFocusNode.removeListener(_onInteractionInputChanged);
    _secondDrugFocusNode.removeListener(_onInteractionInputChanged);
    _firstDrugController.dispose();
    _secondDrugController.dispose();
    _firstDrugFocusNode.dispose();
    _secondDrugFocusNode.dispose();
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

  Future<void> _loadSearchHistory() async {
    final history = await _medicineSearchHistoryRepository.loadHistory();

    if (!mounted) return;

    setState(() {
      _recentMedicineSearches = history;
    });
  }

  void _onInteractionInputChanged() {
    if (!mounted) return;

    setState(() {});
  }

  Future<void> _loadMedicineNameEntries() async {
    try {
      final entries = await _medicineNameRepository.loadEntries();

      if (!mounted) return;

      setState(() {
        _medicineNameEntries = entries;
      });
    } catch (_) {
      // Suggestions are a helper only. Checking still works if the local list fails.
    }
  }

  TextEditingController? get _activeDrugController {
    if (_secondDrugFocusNode.hasFocus) {
      return _secondDrugController;
    }

    if (_firstDrugFocusNode.hasFocus) {
      return _firstDrugController;
    }

    return null;
  }

  List<MedicineNameEntry> _filteredMedicineSuggestions() {
    final controller = _activeDrugController;
    if (controller == null) {
      return const <MedicineNameEntry>[];
    }

    return filterMedicineNameSuggestions(_medicineNameEntries, controller.text);
  }

  void _applyMedicineSuggestion(MedicineNameEntry entry) {
    final value = medicineEntrySearchValue(entry);
    final controller =
        _activeDrugController ??
        (_firstDrugController.text.trim().isEmpty
            ? _firstDrugController
            : _secondDrugController);

    setState(() {
      controller.text = value;
      controller.selection = TextSelection.collapsed(offset: value.length);
      _errorMessage = null;
    });
  }

  Future<void> _saveMedicineSearches(Iterable<String> values) async {
    var history = _recentMedicineSearches;

    for (final value in values) {
      history = await _medicineSearchHistoryRepository.saveSearch(value);
    }

    if (!mounted) return;

    setState(() {
      _recentMedicineSearches = history;
    });
  }

  void _applyRecentMedicine(String medicine) {
    setState(() {
      final firstText = _firstDrugController.text.trim();
      final secondText = _secondDrugController.text.trim();

      if (firstText.isEmpty) {
        _firstDrugController.text = medicine;
      } else if (secondText.isEmpty &&
          firstText.toLowerCase() != medicine.toLowerCase()) {
        _secondDrugController.text = medicine;
      } else {
        _firstDrugController.text = medicine;
      }

      _errorMessage = null;
    });
  }

  String? _validateDrugName(String? value, {String? otherValue}) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return context.l10n.text('interactions.validation.enterName');
    }

    final otherNormalized = otherValue?.trim() ?? '';
    if (otherNormalized.isNotEmpty &&
        normalized.toLowerCase() == otherNormalized.toLowerCase()) {
      return context.l10n.text('interactions.validation.different');
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
      unawaited(
        _saveMedicineSearches(<String>[
          result.firstEnteredName,
          result.secondEnteredName,
        ]),
      );
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
            icon: Icons.compare_arrows_outlined,
            size: 52,
            iconSize: 28,
            borderRadius: 16,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.text('interactions.intro.title'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('interactions.intro.subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
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
    final activeController = _activeDrugController;

    if (activeController != null && activeController.text.trim().isNotEmpty) {
      return MedicineNameSuggestionsList(
        suggestions: _filteredMedicineSuggestions(),
        onSelected: _applyMedicineSuggestion,
        disabled: _isChecking,
      );
    }

    return _buildSearchHistoryChips();
  }

  Widget _buildFormCard(BuildContext context) {
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
              l10n.text('interactions.form.title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.text('interactions.form.subtitle'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstDrugController,
              focusNode: _firstDrugFocusNode,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                context,
                label: l10n.text('interactions.firstMedicine'),
                hint: 'warfarin',
              ),
              validator: (value) => _validateDrugName(
                value,
                otherValue: _secondDrugController.text,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _secondDrugController,
              focusNode: _secondDrugFocusNode,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(
                context,
                label: l10n.text('interactions.secondMedicine'),
                hint: l10n.text('common.exampleIbuprofen'),
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
            _buildMedicineSuggestionsOrHistory(),
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
                  _isChecking
                      ? l10n.text('common.checking')
                      : l10n.text('interactions.checkButton'),
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
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
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

  String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  bool _sameText(String? first, String? second) {
    final normalizedFirst = _cleanText(first)?.toLowerCase();
    final normalizedSecond = _cleanText(second)?.toLowerCase();
    return normalizedFirst != null && normalizedFirst == normalizedSecond;
  }

  List<String> _medicineDetailLines({
    required String enteredName,
    required String checkedQuery,
    String? localBrandName,
    String? localGenericName,
    String? apiGenericName,
  }) {
    final l10n = context.l10n;
    final lines = <String>[];
    final localParts = <String>[];
    final brandName = _cleanText(localBrandName);
    final localGeneric = _cleanText(localGenericName);
    final checkedName = _cleanText(checkedQuery);
    final apiGeneric = _cleanText(apiGenericName);

    if (brandName != null) {
      localParts.add(
        '${l10n.text('common.brand')}: ${l10n.isolate(brandName)}',
      );
    }
    if (localGeneric != null) {
      localParts.add(
        '${l10n.text('common.generic')}: ${l10n.isolate(localGeneric)}',
      );
    }
    if (localParts.isNotEmpty) {
      lines.add(
        l10n.format('interactions.result.matchedAppList', <String, String>{
          'details': localParts.join(', '),
        }),
      );
    }

    if (checkedName != null && !_sameText(checkedName, enteredName)) {
      lines.add(
        l10n.format('interactions.result.checkedAs', <String, String>{
          'name': l10n.isolate(checkedName),
        }),
      );
    }

    if (apiGeneric != null &&
        !_sameText(apiGeneric, localGeneric) &&
        !_sameText(apiGeneric, checkedName)) {
      lines.add(
        l10n.format('interactions.result.publicGeneric', <String, String>{
          'name': l10n.isolate(apiGeneric),
        }),
      );
    }

    return lines;
  }

  Widget _buildMedicineResolutionRow(
    BuildContext context, {
    required String label,
    required String enteredName,
    required List<String> detailLines,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.medication_outlined, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: ${l10n.isolate(enteredName)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (detailLines.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  ...detailLines.map(
                    (line) => Text(
                      line,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineResolutionSection(
    BuildContext context,
    DrugInteractionLookupResult result,
  ) {
    final firstEnteredName =
        _cleanText(result.firstEnteredName) ??
        context.l10n.text('interactions.result.first');
    final secondEnteredName =
        _cleanText(result.secondEnteredName) ??
        context.l10n.text('interactions.result.second');
    final firstDetails = _medicineDetailLines(
      enteredName: firstEnteredName,
      checkedQuery: result.firstQuery,
      localBrandName: result.firstLocalBrandName,
      localGenericName: result.firstLocalGenericName,
      apiGenericName: result.firstGenericName,
    );
    final secondDetails = _medicineDetailLines(
      enteredName: secondEnteredName,
      checkedQuery: result.secondQuery,
      localBrandName: result.secondLocalBrandName,
      localGenericName: result.secondLocalGenericName,
      apiGenericName: result.secondGenericName,
    );

    if (firstDetails.isEmpty && secondDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.text('interactions.result.medicineNamesChecked'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          _buildMedicineResolutionRow(
            context,
            label: context.l10n.text('interactions.result.first'),
            enteredName: firstEnteredName,
            detailLines: firstDetails,
          ),
          _buildMedicineResolutionRow(
            context,
            label: context.l10n.text('interactions.result.second'),
            enteredName: secondEnteredName,
            detailLines: secondDetails,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    DrugInteractionLookupResult result,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasMechanism = (result.mechanism ?? '').trim().isNotEmpty;
    final l10n = context.l10n;

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
          Text(
            '${l10n.isolate(result.firstDrug)} + ${l10n.isolate(result.secondDrug)}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InteractionSeverityChip(severity: result.severity),
          const SizedBox(height: 12),
          Text(
            l10n.interactionResultText(result.summary),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          _buildMedicineResolutionSection(context, result),
          if (hasMechanism) ...[
            const SizedBox(height: 18),
            _buildBulletSection(
              context,
              icon: Icons.science_outlined,
              title: l10n.text('interactions.result.why'),
              items: [l10n.interactionResultText(result.mechanism!.trim())],
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildBulletSection(
              context,
              icon: Icons.warning_amber_rounded,
              title: l10n.text('interactions.result.warnings'),
              items: l10n.interactionResultTexts(result.warnings),
            ),
          ],
          if (result.recommendations.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildBulletSection(
              context,
              icon: Icons.health_and_safety_outlined,
              title: l10n.text('interactions.result.next'),
              items: l10n.interactionResultTexts(result.recommendations),
            ),
          ],
          if (result.evidence.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildBulletSection(
              context,
              icon: Icons.info_outline,
              title: l10n.text('interactions.result.evidence'),
              items: l10n.interactionResultTexts(result.evidence),
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
    final l10n = context.l10n;

    if (_errorMessage != null) {
      return _buildStateCard(
        context,
        icon: Icons.error_outline,
        title: l10n.text('interactions.result.errorTitle'),
        message: l10n.interactionResultText(_errorMessage!),
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
      title: l10n.text('interactions.result.readyTitle'),
      message: l10n.text('interactions.result.readyMessage'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('interactions.title'))),
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
