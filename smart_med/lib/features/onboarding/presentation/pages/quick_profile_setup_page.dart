import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/medications/medications.dart';
import 'package:smart_med/features/profile/profile.dart';
import 'package:smart_med/core/widgets/app_snack_bar.dart';

class QuickProfileSetupPage extends StatefulWidget {
  const QuickProfileSetupPage({
    super.key,
    required this.profile,
    required this.onFinished,
  });

  final UserProfileRecord profile;
  final VoidCallback onFinished;

  @override
  State<QuickProfileSetupPage> createState() => _QuickProfileSetupPageState();
}

class _QuickProfileSetupPageState extends State<QuickProfileSetupPage> {
  static const int _maxConditionSuggestions = 10;
  static const int _maxAllergySuggestions = 8;

  final ProfileRepository _profileRepository = profileRepository;
  final MedicationRepository _medicationRepository = medicationRepository;
  final TextEditingController _conditionSearchController =
      TextEditingController();
  final TextEditingController _allergySearchController =
      TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _systolicPressureController =
      TextEditingController();
  final TextEditingController _diastolicPressureController =
      TextEditingController();
  final TextEditingController _bloodGlucoseController = TextEditingController();

  bool _isLoadingOptions = true;
  bool _isSaving = false;
  String? _conditionLoadError;
  String? _allergyLoadError;
  List<String> _availableConditions = const <String>[];
  List<_MedicineSearchOption> _availableAllergyOptions =
      const <_MedicineSearchOption>[];
  late List<String> _selectedConditions;
  late List<String> _selectedAllergies;
  late String _biologicalSex;
  late bool _isPregnant;
  late bool _isBreastfeeding;

  @override
  void initState() {
    super.initState();
    _selectedConditions = List<String>.from(
      widget.profile.medicalConditionNames,
    );
    _selectedAllergies = List<String>.from(widget.profile.allergyNames);
    _biologicalSex =
        (widget.profile.biologicalSex ?? 'male').trim().toLowerCase() ==
            'female'
        ? 'female'
        : 'male';
    _isPregnant = _biologicalSex == 'female' && widget.profile.isPregnant;
    _isBreastfeeding =
        _biologicalSex == 'female' && widget.profile.isBreastfeeding;
    _weightController.text = _valueToText(widget.profile.weightKg);
    _heightController.text = _valueToText(widget.profile.heightCm);
    _systolicPressureController.text = _valueToText(
      widget.profile.systolicPressure,
    );
    _diastolicPressureController.text = _valueToText(
      widget.profile.diastolicPressure,
    );
    _bloodGlucoseController.text = _valueToText(widget.profile.bloodGlucose);
    _loadSelectorOptions();
  }

  @override
  void dispose() {
    _conditionSearchController.dispose();
    _allergySearchController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _systolicPressureController.dispose();
    _diastolicPressureController.dispose();
    _bloodGlucoseController.dispose();
    super.dispose();
  }

  String _valueToText(Object? value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  double? _parseDoubleOrNull(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      return null;
    }

    return double.tryParse(cleaned);
  }

  int? _parseIntOrNull(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      return null;
    }

    return int.tryParse(cleaned);
  }

  Future<void> _loadSelectorOptions() async {
    List<String> conditions = const <String>[];
    List<_MedicineSearchOption> allergyOptions =
        const <_MedicineSearchOption>[];
    String? nextConditionLoadError;
    String? nextAllergyLoadError;

    try {
      final rawConditions = await rootBundle.loadString(
        'assets/data/diseases.json',
      );
      final decoded = json.decode(rawConditions) as List<dynamic>;
      conditions = decoded.map((item) => item.toString().trim()).where((item) {
        return item.isNotEmpty;
      }).toList()..sort();
    } catch (_) {
      nextConditionLoadError = 'quickProfile.conditions.loadError';
    }

    try {
      final rawMedicines = await rootBundle.loadString(
        'assets/data/local_medicines.json',
      );
      final decoded = json.decode(rawMedicines) as List<dynamic>;
      allergyOptions =
          decoded
              .map(_MedicineSearchOption.fromMap)
              .where((item) => item.storedValue.isNotEmpty)
              .toList()
            ..sort(
              (left, right) => left.displayLabel.toLowerCase().compareTo(
                right.displayLabel.toLowerCase(),
              ),
            );
    } catch (_) {
      nextAllergyLoadError = 'quickProfile.allergies.loadError';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _availableConditions = conditions;
      _availableAllergyOptions = allergyOptions;
      _conditionLoadError = nextConditionLoadError;
      _allergyLoadError = nextAllergyLoadError;
      _isLoadingOptions = false;
    });
  }

  void _showMessage(String message, {AppSnackBarType? type}) {
    AppSnackBar.show(context, message, type: type);
  }

  bool _containsIgnoreCase(List<String> values, String candidate) {
    final normalizedCandidate = candidate.trim().toLowerCase();
    return values.any(
      (value) => value.trim().toLowerCase() == normalizedCandidate,
    );
  }

  void _addCondition(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (_containsIgnoreCase(_selectedConditions, normalized)) {
      _showMessage(context.l10n.text('quickProfile.conditionDuplicate'));
      return;
    }

    setState(() {
      _selectedConditions = <String>[..._selectedConditions, normalized];
      _conditionSearchController.clear();
    });
  }

  void _removeCondition(String value) {
    setState(() {
      _selectedConditions = _selectedConditions
          .where((item) => item.toLowerCase() != value.toLowerCase())
          .toList(growable: false);
    });
  }

  void _addAllergy(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (_containsIgnoreCase(_selectedAllergies, normalized)) {
      _showMessage(context.l10n.text('quickProfile.allergyDuplicate'));
      return;
    }

    setState(() {
      _selectedAllergies = <String>[..._selectedAllergies, normalized];
      _allergySearchController.clear();
    });
  }

  void _removeAllergy(String value) {
    setState(() {
      _selectedAllergies = _selectedAllergies
          .where((item) => item.toLowerCase() != value.toLowerCase())
          .toList(growable: false);
    });
  }

  List<String> _filteredConditionSuggestions() {
    final query = _conditionSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const <String>[];
    }

    return _availableConditions
        .where((condition) {
          if (_containsIgnoreCase(_selectedConditions, condition)) {
            return false;
          }

          return condition.toLowerCase().contains(query);
        })
        .take(_maxConditionSuggestions)
        .toList(growable: false);
  }

  List<_MedicineSearchOption> _filteredAllergySuggestions() {
    final query = _allergySearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const <_MedicineSearchOption>[];
    }

    return _availableAllergyOptions
        .where((option) {
          if (_containsIgnoreCase(_selectedAllergies, option.storedValue)) {
            return false;
          }

          return option.matches(query);
        })
        .take(_maxAllergySuggestions)
        .toList(growable: false);
  }

  bool get _canAddCustomCondition {
    final query = _conditionSearchController.text.trim();
    if (query.isEmpty) {
      return false;
    }

    if (_containsIgnoreCase(_selectedConditions, query)) {
      return false;
    }

    return !_availableConditions.any(
      (condition) => condition.toLowerCase() == query.toLowerCase(),
    );
  }

  bool get _canAddCustomAllergy {
    final query = _allergySearchController.text.trim();
    if (query.isEmpty) {
      return false;
    }

    if (_containsIgnoreCase(_selectedAllergies, query)) {
      return false;
    }

    return !_availableAllergyOptions.any(
      (option) => option.storedValue.toLowerCase() == query.toLowerCase(),
    );
  }

  Future<void> _saveAndContinue() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final medicalInfo = <String, dynamic>{
        'biologicalSex': _biologicalSex,
        'weightKg': _parseDoubleOrNull(_weightController.text),
        'heightCm': _parseDoubleOrNull(_heightController.text),
        'systolicPressure': _parseIntOrNull(_systolicPressureController.text),
        'diastolicPressure': _parseIntOrNull(_diastolicPressureController.text),
        'bloodGlucose': _parseDoubleOrNull(_bloodGlucoseController.text),
        'isPregnant': _biologicalSex == 'female' ? _isPregnant : false,
        'isBreastfeeding': _biologicalSex == 'female'
            ? _isBreastfeeding
            : false,
      };

      await _profileRepository.saveQuickProfileSetup(
        uid: widget.profile.authUid,
        medicalConditionNames: _selectedConditions,
        allergyNames: _selectedAllergies,
        medicalInfo: medicalInfo,
      );

      if (!mounted) {
        return;
      }

      widget.onFinished();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is ProfileRepositoryException
          ? error.message
          : context.l10n.text('quickProfile.saveError');
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _skipForNow() async {
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;

        return AlertDialog(
          title: Text(l10n.text('quickProfile.skip.title')),
          content: Text(l10n.text('quickProfile.skip.body')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.text('common.goBack')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.text('quickProfile.skip.button')),
            ),
          ],
        );
      },
    );

    if (shouldSkip != true || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _profileRepository.markQuickProfileSetupCompleted(
        uid: widget.profile.authUid,
      );

      if (!mounted) {
        return;
      }

      widget.onFinished();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is ProfileRepositoryException
          ? error.message
          : context.l10n.text('quickProfile.skipError');
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openAddMedicationPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddMedicationPage()));
  }

  Future<void> _openMedicationListPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MedicationListPage()));
  }

  Widget _buildSelectedChips({
    required List<String> values,
    required ValueChanged<String> onDeleted,
    required String emptyMessage,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    if (values.isEmpty) {
      return Text(
        emptyMessage,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map((value) {
            return Chip(
              label: Text(l10n.isolate(value)),
              onDeleted: _isSaving ? null : () => onDeleted(value),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildConditionSection() {
    final suggestions = _filteredConditionSuggestions();
    final l10n = context.l10n;

    return _SetupSectionCard(
      title: l10n.text('quickProfile.conditions.title'),
      subtitle: l10n.text('quickProfile.conditions.subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _conditionSearchController,
            enabled: !_isSaving,
            onChanged: (_) => setState(() {}),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: l10n.text('quickProfile.conditions.search'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          if (_conditionLoadError != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              l10n.text(_conditionLoadError!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_isLoadingOptions) ...<Widget>[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (!_isLoadingOptions) ...<Widget>[
            const SizedBox(height: 12),
            _buildSelectedChips(
              values: _selectedConditions,
              onDeleted: _removeCondition,
              emptyMessage: l10n.text('quickProfile.conditions.none'),
            ),
            if (suggestions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Column(
                children: suggestions
                    .map((condition) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.isolate(condition)),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: _isSaving
                            ? null
                            : () => _addCondition(condition),
                      );
                    })
                    .toList(growable: false),
              ),
            ] else if (_conditionSearchController.text.trim().isNotEmpty &&
                _conditionLoadError == null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                l10n.text('quickProfile.noExact'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_canAddCustomCondition) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _addCondition(_conditionSearchController.text),
                icon: const Icon(Icons.add),
                label: Text(
                  l10n.format('quickProfile.addNamed', {
                    'name': l10n.isolate(
                      _conditionSearchController.text.trim(),
                    ),
                  }),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAllergySection() {
    final suggestions = _filteredAllergySuggestions();
    final l10n = context.l10n;

    return _SetupSectionCard(
      title: l10n.text('quickProfile.allergies.title'),
      subtitle: l10n.text('quickProfile.allergies.subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _allergySearchController,
            enabled: !_isSaving,
            onChanged: (_) => setState(() {}),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: l10n.text('quickProfile.allergies.search'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          if (_allergyLoadError != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              l10n.text(_allergyLoadError!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_isLoadingOptions) ...<Widget>[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (!_isLoadingOptions) ...<Widget>[
            const SizedBox(height: 12),
            _buildSelectedChips(
              values: _selectedAllergies,
              onDeleted: _removeAllergy,
              emptyMessage: l10n.text('quickProfile.allergies.none'),
            ),
            if (suggestions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Column(
                children: suggestions
                    .map((option) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.isolate(option.storedValue)),
                        subtitle: option.subtitle == null
                            ? null
                            : Text(
                                '${l10n.text('common.brand')}: '
                                '${l10n.isolate(option.subtitle!)}',
                              ),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: _isSaving
                            ? null
                            : () => _addAllergy(option.storedValue),
                      );
                    })
                    .toList(growable: false),
              ),
            ] else if (_allergySearchController.text.trim().isNotEmpty &&
                _allergyLoadError == null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                l10n.text('quickProfile.noExact'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_canAddCustomAllergy) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _addAllergy(_allergySearchController.text),
                icon: const Icon(Icons.add),
                label: Text(
                  l10n.format('quickProfile.addNamed', {
                    'name': l10n.isolate(_allergySearchController.text.trim()),
                  }),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationSection() {
    final l10n = context.l10n;

    return _SetupSectionCard(
      title: l10n.text('quickProfile.medicines.title'),
      subtitle: l10n.text('quickProfile.medicines.subtitle'),
      child: StreamBuilder<List<MedicationRecord>>(
        stream: _medicationRepository.watchMedicationRecords(
          uid: widget.profile.authUid,
        ),
        builder: (context, snapshot) {
          final medications = snapshot.data ?? const <MedicationRecord>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                medications.isEmpty
                    ? l10n.text('quickProfile.medicines.none')
                    : medications.length == 1
                    ? l10n.text('quickProfile.medicines.oneLinked')
                    : l10n.format('quickProfile.medicines.countLinked', {
                        'count': medications.length.toString(),
                      }),
              ),
              if (medications.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: medications
                      .take(4)
                      .map((medication) {
                        return Chip(label: Text(l10n.isolate(medication.name)));
                      })
                      .toList(growable: false),
                ),
                if (medications.length > 4) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    l10n.format('quickProfile.medicines.more', {
                      'count': (medications.length - 4).toString(),
                    }),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _openAddMedicationPage,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.text('common.addMedicine')),
                  ),
                  if (medications.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _openMedicationListPage,
                      icon: const Icon(Icons.list_alt_outlined),
                      label: Text(l10n.text('quickProfile.medicines.review')),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _buildMedicalFieldDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color),
      );
    }

    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon),
      filled: true,
      fillColor: colorScheme.surface.withValues(alpha: 0.45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border(colorScheme.outlineVariant),
      enabledBorder: border(colorScheme.outlineVariant),
      focusedBorder: border(colorScheme.primary),
      disabledBorder: border(colorScheme.outlineVariant),
    );
  }

  Widget _buildMedicalSectionLabel(String title, {String? helper}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (helper != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            helper,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMedicalNumberField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool allowDecimal = true,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isSaving,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: allowDecimal
          ? null
          : <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
      decoration: _buildMedicalFieldDecoration(
        hintText: hintText,
        prefixIcon: icon,
      ),
    );
  }

  Widget _buildMedicalToggle({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }

  Widget _buildMedicalInfoSection() {
    final l10n = context.l10n;

    return _SetupSectionCard(
      title: l10n.text('profile.health.title'),
      subtitle: l10n.text('profile.health.subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildMedicalSectionLabel(l10n.text('profile.health.biologicalSex')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _biologicalSex,
            decoration: _buildMedicalFieldDecoration(
              hintText: l10n.text('quickProfile.health.selectSex'),
              prefixIcon: Icons.wc_outlined,
            ),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem(
                value: 'male',
                child: Text(l10n.text('profile.health.male')),
              ),
              DropdownMenuItem(
                value: 'female',
                child: Text(l10n.text('profile.health.female')),
              ),
            ],
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _biologicalSex = value;
                      if (_biologicalSex != 'female') {
                        _isPregnant = false;
                        _isBreastfeeding = false;
                      }
                    });
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMedicalNumberField(
                  controller: _weightController,
                  hintText: l10n.text('profile.health.weight'),
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMedicalNumberField(
                  controller: _heightController,
                  hintText: l10n.text('profile.health.height'),
                  icon: Icons.height_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildMedicalSectionLabel(
            l10n.text('profile.health.bloodPressure'),
            helper: l10n.text('profile.health.bloodPressureHelp'),
          ),
          const SizedBox(height: 10),
          _buildMedicalNumberField(
            controller: _systolicPressureController,
            hintText: l10n.text('profile.health.systolic'),
            icon: Icons.favorite_border,
            allowDecimal: false,
          ),
          const SizedBox(height: 12),
          _buildMedicalNumberField(
            controller: _diastolicPressureController,
            hintText: l10n.text('profile.health.diastolic'),
            icon: Icons.favorite,
            allowDecimal: false,
          ),
          const SizedBox(height: 18),
          _buildMedicalSectionLabel(l10n.text('profile.health.bloodGlucose')),
          const SizedBox(height: 10),
          _buildMedicalNumberField(
            controller: _bloodGlucoseController,
            hintText: l10n.text('profile.health.bloodGlucose'),
            icon: Icons.bloodtype_outlined,
          ),
          if (_biologicalSex == 'female') ...<Widget>[
            const SizedBox(height: 12),
            _buildMedicalToggle(
              title: l10n.text('profile.health.pregnant'),
              value: _isPregnant,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _isPregnant = value;
                      });
                    },
            ),
            const SizedBox(height: 10),
            _buildMedicalToggle(
              title: l10n.text('profile.health.breastfeeding'),
              value: _isBreastfeeding,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _isBreastfeeding = value;
                      });
                    },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    final Widget footer = isKeyboardVisible
        ? const SizedBox.shrink(key: ValueKey('keyboard-open'))
        : Padding(
            key: const ValueKey('keyboard-closed'),
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAndContinue,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Text(l10n.text('quickProfile.saveContinue')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isSaving ? null : _skipForNow,
                      child: Text(l10n.text('quickProfile.skip.button')),
                    ),
                  ],
                ),
              ),
            ),
          );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(bottom: isKeyboardVisible ? 12 : 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.text('quickProfile.title'),
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.text('quickProfile.subtitle'),
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                AppIconBadge(
                                  icon: Icons.health_and_safety_outlined,
                                  accentColor: colorScheme.onSecondaryContainer,
                                  size: 44,
                                  iconSize: 22,
                                  borderRadius: 14,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.text('quickProfile.callout'),
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildMedicalInfoSection(),
                          const SizedBox(height: 16),
                          _buildConditionSection(),
                          const SizedBox(height: 16),
                          _buildAllergySection(),
                          const SizedBox(height: 16),
                          _buildMedicationSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: footer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupSectionCard extends StatelessWidget {
  const _SetupSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MedicineSearchOption {
  const _MedicineSearchOption({
    required this.displayLabel,
    required this.storedValue,
    this.subtitle,
    required String brandName,
    required String genericName,
  }) : _brandName = brandName,
       _genericName = genericName;

  final String displayLabel;
  final String storedValue;
  final String? subtitle;
  final String _brandName;
  final String _genericName;

  factory _MedicineSearchOption.fromMap(dynamic raw) {
    if (raw is! Map) {
      return const _MedicineSearchOption(
        displayLabel: '',
        storedValue: '',
        brandName: '',
        genericName: '',
      );
    }

    final map = raw.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
    final brandName = map['brandName']?.trim() ?? '';
    final genericName = map['genericName']?.trim() ?? '';
    final storedValue = genericName.isNotEmpty ? genericName : brandName;

    if (storedValue.isEmpty) {
      return const _MedicineSearchOption(
        displayLabel: '',
        storedValue: '',
        brandName: '',
        genericName: '',
      );
    }

    final subtitle = brandName.isNotEmpty && genericName.isNotEmpty
        ? brandName == genericName
              ? null
              : brandName
        : null;

    return _MedicineSearchOption(
      displayLabel: brandName.isNotEmpty && genericName.isNotEmpty
          ? '$brandName - $genericName'
          : storedValue,
      storedValue: storedValue,
      subtitle: subtitle,
      brandName: brandName,
      genericName: genericName,
    );
  }

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return false;
    }

    return displayLabel.toLowerCase().contains(normalizedQuery) ||
        storedValue.toLowerCase().contains(normalizedQuery) ||
        _brandName.toLowerCase().contains(normalizedQuery) ||
        _genericName.toLowerCase().contains(normalizedQuery);
  }
}
