import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/core/firebase/image_storage_repository.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/medications/data/repositories/medication_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';
import 'package:smart_med/models/local_medicine.dart';
import 'package:smart_med/services/local_medicine_service.dart';
import 'package:smart_med/core/widgets/app_snack_bar.dart';

class EditMedicationPage extends StatefulWidget {
  final MedicationRecord medication;

  const EditMedicationPage({super.key, required this.medication});

  @override
  State<EditMedicationPage> createState() => _EditMedicationPageState();
}

class _EditMedicationPageState extends State<EditMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final MedicationRepository _medicationRepository = medicationRepository;
  final LocalMedicineService _localMedicineService = localMedicineService;
  final ImagePicker _imagePicker = ImagePicker();
  final ImageStorageRepository _imageStorageRepository = imageStorageRepository;

  late TextEditingController nameController;
  late TextEditingController doseController;
  late TextEditingController timesPerDayController;
  late TextEditingController startDateController;
  late TextEditingController finishDateController;
  late TextEditingController noteController;
  late TextEditingController firstReminderTimeController;
  final Duration _medicineSearchDelay = const Duration(milliseconds: 300);
  XFile? _selectedMedicationImage;
  Uint8List? _selectedMedicationImageBytes;

  bool isLoading = false;
  bool isSearchingMedicines = false;
  int timesPerDay = 1;
  Timer? _medicineSearchDebounce;
  List<LocalMedicine> _medicineResults = const <LocalMedicine>[];
  LocalMedicine? selectedMedicine;
  String? _medicineSearchFeedback;
  String? _medicineSelectionError;

  final List<String> doseUnits = [
    'mg',
    'mcg',
    'g',
    'ml',
    'iu',
    'tablet',
    'capsule',
  ];
  late String selectedDoseUnit;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.medication.name);
    doseController = TextEditingController(
      text: _formatDoseAmount(widget.medication.doseAmount),
    );
    timesPerDayController = TextEditingController(
      text: widget.medication.frequencyPerDay.toString(),
    );
    startDateController = TextEditingController(
      text: _formatDateForInput(widget.medication.startDate),
    );
    finishDateController = TextEditingController(
      text: _formatDateForInput(widget.medication.endDate),
    );
    noteController = TextEditingController(text: widget.medication.notes ?? '');
    firstReminderTimeController = TextEditingController(
      text: widget.medication.reminderTimes.isEmpty
          ? ''
          : widget.medication.reminderTimes.first,
    );

    selectedDoseUnit = doseUnits.contains(widget.medication.doseUnit)
        ? widget.medication.doseUnit
        : 'mg';
    _updateTimesPerDay(widget.medication.frequencyPerDay);

    selectedMedicine = _buildSelectedMedicineFromRecord(widget.medication);
    if (selectedMedicine == null) {
      _restoreInitialMedicineSelection();
    }
  }

  @override
  void dispose() {
    _medicineSearchDebounce?.cancel();
    nameController.dispose();
    doseController.dispose();
    timesPerDayController.dispose();
    startDateController.dispose();
    finishDateController.dispose();
    noteController.dispose();
    firstReminderTimeController.dispose();

    super.dispose();
  }

  void _updateTimesPerDay(int count) {
    if (count < 1) count = 1;
    if (count > 6) count = 6;

    timesPerDay = count;
  }

  List<String> _buildReminderTimes() {
    final firstTime = MedicationScheduleTime.fromDisplayString(
      firstReminderTimeController.text.trim(),
    );

    return MedicationScheduleTime.evenlySpaced(
      firstTime: firstTime,
      timesPerDay: timesPerDay,
    ).map((item) => item.toDisplayString()).toList(growable: false);
  }

  List<String> _previewReminderTimes() {
    if (firstReminderTimeController.text.trim().isEmpty) {
      return const <String>[];
    }

    try {
      return _buildReminderTimes();
    } on ArgumentError {
      return const <String>[];
    } on FormatException {
      return const <String>[];
    }
  }

  TimeOfDay _initialReminderPickerTime() {
    final parsedTime = MedicationScheduleTime.tryFromDisplayString(
      firstReminderTimeController.text,
    );

    if (parsedTime == null) {
      return TimeOfDay.now();
    }

    return TimeOfDay(hour: parsedTime.hour, minute: parsedTime.minute);
  }

  String _reminderIntervalText() {
    final l10n = context.l10n;
    final intervalMinutes =
        MedicationScheduleTime.intervalMinutesForDailyFrequency(timesPerDay);
    final hours = intervalMinutes ~/ 60;
    final minutes = intervalMinutes % 60;

    if (hours == 0) {
      return minutes == 1
          ? l10n.text('medication.interval.minute')
          : l10n.format('medication.interval.minutes', <String, String>{
              'count': minutes.toString(),
            });
    }

    if (minutes == 0) {
      return hours == 1
          ? l10n.text('medication.interval.hour')
          : l10n.format('medication.interval.hours', <String, String>{
              'count': hours.toString(),
            });
    }

    final hourText = hours == 1
        ? l10n.text('medication.interval.hour')
        : l10n.format('medication.interval.hours', <String, String>{
            'count': hours.toString(),
          });
    final minuteText = minutes == 1
        ? l10n.text('medication.interval.minute')
        : l10n.format('medication.interval.minutes', <String, String>{
            'count': minutes.toString(),
          });

    return l10n.format('medication.interval.hourMinute', <String, String>{
      'hours': hourText,
      'minutes': minuteText,
    });
  }

  Widget _buildReminderSchedulePreview() {
    final previewTimes = _previewReminderTimes();
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final message = previewTimes.isEmpty
        ? l10n.format('medication.reminderChoose', <String, String>{
            'interval': l10n.isolate(_reminderIntervalText()),
          })
        : l10n.format('medication.reminderTimes', <String, String>{
            'times': l10n.isolate(previewTimes.join(', ')),
          });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  InputDecoration customInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _pickMedicationImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMedicationImage = image;
      _selectedMedicationImageBytes = bytes;
    });
  }

  void _clearMedicationImage() {
    setState(() {
      _selectedMedicationImage = null;
      _selectedMedicationImageBytes = null;
    });
  }

  Widget _buildMedicationImageSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final imageUrl = widget.medication.imageUrl?.trim();
    final hasNetworkImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.text('medication.photo.title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.text('medication.photo.editSubtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 180,
              color: colorScheme.surface,
              child: _selectedMedicationImageBytes != null
                  ? Image.memory(
                      _selectedMedicationImageBytes!,
                      fit: BoxFit.cover,
                    )
                  : hasNetworkImage
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 42,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 42,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.text('common.noPhotoSelected'),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : _pickMedicationImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  (_selectedMedicationImageBytes != null || hasNetworkImage)
                      ? l10n.text('common.changePhoto')
                      : l10n.text('common.addPhoto'),
                ),
              ),
              if (_selectedMedicationImageBytes != null)
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _clearMedicationImage,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.text('common.resetPhoto')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickFirstReminderTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _initialReminderPickerTime(),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        firstReminderTimeController.text = pickedTime.format(context);
      });
    }
  }

  Future<void> pickStartDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(startDateController.text) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        startDateController.text = _formatDateForInput(pickedDate);

        final finishDate = _parseInputDate(finishDateController.text);
        if (finishDate != null && finishDate.isBefore(pickedDate)) {
          finishDateController.clear();
        }
      });
    }
  }

  Future<void> pickFinishDate() async {
    final startDate = _parseInputDate(startDateController.text);
    final currentFinishDate = _parseInputDate(finishDateController.text);
    final today = DateTime.now();
    final firstDate = startDate ?? DateTime(2024);
    DateTime initialDate = currentFinishDate ?? startDate ?? today;

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        finishDateController.text = _formatDateForInput(pickedDate);
      });
    }
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  String _displayMedicineName(LocalMedicine medicine) {
    return _cleanText(medicine.brandName) ??
        _cleanText(medicine.genericName) ??
        context.l10n.text('common.unknownMedicine');
  }

  String? _buildMedicineSuggestionSubtitle(LocalMedicine medicine) {
    final l10n = context.l10n;
    final genericName = _cleanText(medicine.genericName);
    final strength = _cleanText(medicine.strength);
    final form = _cleanText(medicine.form);
    final parts = <String>[
      if (genericName != null)
        '${l10n.text('common.generic')}: ${l10n.isolate(genericName)}',
      if (strength != null)
        '${l10n.text('common.strength')}: ${l10n.isolate(strength)}',
      if (form != null) '${l10n.text('common.form')}: ${l10n.isolate(form)}',
    ];

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' | ');
  }

  LocalMedicine? _buildSelectedMedicineFromRecord(MedicationRecord medication) {
    final medicineId = _cleanText(medication.medicineId);
    final brandName = _cleanText(medication.brandName);
    final genericName = _cleanText(medication.genericName);
    final storedName = _cleanText(medication.name);
    final strength = _cleanText(medication.strength);
    final form = _cleanText(medication.form);
    final activeIngredients = medication.activeIngredients
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final hasStructuredData =
        medicineId != null ||
        brandName != null ||
        genericName != null ||
        strength != null ||
        form != null ||
        activeIngredients.isNotEmpty;

    if (!hasStructuredData) {
      return null;
    }

    final candidate = LocalMedicine(
      id: medicineId,
      brandName: brandName,
      genericName: genericName,
      activeIngredients: activeIngredients,
      strength: strength,
      form: form,
    );

    if (storedName == null) {
      return candidate;
    }

    if (_displayMedicineName(candidate).toLowerCase() !=
        storedName.toLowerCase()) {
      return null;
    }

    return candidate;
  }

  Future<void> _restoreInitialMedicineSelection() async {
    final existingName = nameController.text.trim();
    if (existingName.isEmpty) {
      return;
    }

    try {
      final medicines = await _localMedicineService.loadMedicines();
      if (!mounted || nameController.text.trim() != existingName) {
        return;
      }

      LocalMedicine? exactMatch;
      for (final medicine in medicines) {
        final displayName = _displayMedicineName(medicine).toLowerCase();
        if (displayName == existingName.toLowerCase()) {
          exactMatch = medicine;
          break;
        }

        for (final term in medicine.searchableTerms) {
          if (term.trim().toLowerCase() == existingName.toLowerCase()) {
            exactMatch = medicine;
            break;
          }
        }

        if (exactMatch != null) {
          break;
        }
      }

      if (exactMatch == null) {
        return;
      }

      setState(() {
        selectedMedicine = exactMatch;
        _medicineSelectionError = null;
      });
    } catch (_) {
      // Leave legacy free-text medicines unselected so the user can re-pick.
    }
  }

  String _formatDoseAmount(double value) {
    final hasNoFraction = value == value.truncateToDouble();
    return hasNoFraction ? value.toStringAsFixed(0) : value.toString();
  }

  String _formatDateForInput(DateTime? value) {
    if (value == null) {
      return '';
    }

    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseInputDate(String value) {
    return DateTime.tryParse(value.trim());
  }

  void _showMessage(String message, {AppSnackBarType? type}) {
    AppSnackBar.show(context, message, type: type);
  }

  String _firebaseErrorMessage(
    FirebaseException exception, {
    required String fallbackMessage,
  }) {
    final l10n = context.l10n;
    switch (exception.code.trim()) {
      case 'permission-denied':
        return l10n.text('medication.permissionUpdate');
      case 'unauthenticated':
        return l10n.text('medication.validation.signInUpdate');
      case 'unavailable':
        return l10n.text('medication.serviceUnavailable');
      default:
        final message = exception.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }

        return fallbackMessage;
    }
  }

  void _scheduleMedicineSearch(String query) {
    _medicineSearchDebounce?.cancel();

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        isSearchingMedicines = false;
        _medicineResults = const <LocalMedicine>[];
        _medicineSearchFeedback = null;
        _medicineSelectionError = null;
      });
      return;
    }

    setState(() {
      isSearchingMedicines = true;
      _medicineSearchFeedback = null;
    });

    _medicineSearchDebounce = Timer(_medicineSearchDelay, () async {
      await _searchMedicines(trimmedQuery);
    });
  }

  Future<void> _searchMedicines(String query) async {
    try {
      final results = await _localMedicineService.searchMedicines(query);

      if (!mounted || nameController.text.trim() != query) {
        return;
      }

      setState(() {
        isSearchingMedicines = false;
        _medicineResults = results;
        _medicineSearchFeedback = results.isEmpty
            ? context.l10n.text('medication.noMatch')
            : null;
        _medicineSelectionError = selectedMedicine == null && query.isNotEmpty
            ? context.l10n.text('medication.selectFromList')
            : null;
      });
    } catch (_) {
      if (!mounted || nameController.text.trim() != query) {
        return;
      }

      setState(() {
        isSearchingMedicines = false;
        _medicineResults = const <LocalMedicine>[];
        _medicineSearchFeedback = context.l10n.text(
          'medication.searchListError',
        );
        _medicineSelectionError = context.l10n.text(
          'medication.selectFromList',
        );
      });
    }
  }

  void _handleMedicineNameChanged(String value) {
    final trimmedValue = value.trim();
    final selectedLabel = selectedMedicine == null
        ? null
        : _displayMedicineName(selectedMedicine!).toLowerCase();

    if (trimmedValue.isEmpty) {
      _medicineSearchDebounce?.cancel();
      setState(() {
        selectedMedicine = null;
        isSearchingMedicines = false;
        _medicineResults = const <LocalMedicine>[];
        _medicineSearchFeedback = null;
        _medicineSelectionError = null;
      });
      return;
    }

    if (selectedLabel != null && trimmedValue.toLowerCase() == selectedLabel) {
      setState(() {
        _medicineResults = const <LocalMedicine>[];
        _medicineSearchFeedback = null;
        _medicineSelectionError = null;
        isSearchingMedicines = false;
      });
      return;
    }

    if (selectedMedicine != null) {
      setState(() {
        selectedMedicine = null;
      });
    }

    _scheduleMedicineSearch(trimmedValue);
  }

  void _selectMedicine(LocalMedicine medicine) {
    _medicineSearchDebounce?.cancel();

    final displayName = _displayMedicineName(medicine);
    nameController.text = displayName;
    nameController.selection = TextSelection.fromPosition(
      TextPosition(offset: displayName.length),
    );

    FocusScope.of(context).unfocus();

    setState(() {
      selectedMedicine = medicine;
      _medicineResults = const <LocalMedicine>[];
      _medicineSearchFeedback = null;
      _medicineSelectionError = null;
      isSearchingMedicines = false;
    });
  }

  void _clearMedicineSelection() {
    _medicineSearchDebounce?.cancel();

    nameController.clear();

    setState(() {
      selectedMedicine = null;
      _medicineResults = const <LocalMedicine>[];
      _medicineSearchFeedback = null;
      _medicineSelectionError = null;
      isSearchingMedicines = false;
    });
  }

  Widget? _buildNameSuffixIcon() {
    if (isSearchingMedicines) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (selectedMedicine != null) {
      return const Icon(Icons.check_circle_outline);
    }

    return const Icon(Icons.search_rounded);
  }

  Widget _buildMedicineSelectionPanel() {
    final medicine = selectedMedicine;
    final l10n = context.l10n;

    if (medicine == null &&
        _medicineResults.isEmpty &&
        (_medicineSearchFeedback == null ||
            nameController.text.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (medicine != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${l10n.isolate(_displayMedicineName(medicine))} ${l10n.text('common.selected')}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading ? null : _clearMedicineSelection,
                      child: Text(l10n.text('common.change')),
                    ),
                  ],
                ),
                if (_cleanText(medicine.brandName) != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.text('common.brand')}: ${l10n.isolate(medicine.brandName!.trim())}',
                  ),
                ],
                if (_cleanText(medicine.genericName) != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.text('common.generic')}: ${l10n.isolate(medicine.genericName!.trim())}',
                  ),
                ],
                if (medicine.activeIngredients.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.text('common.activeIngredients')}: ${l10n.isolate(medicine.activeIngredients.join(', '))}',
                  ),
                ],
                if (_cleanText(medicine.strength) != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.text('common.strength')}: ${l10n.isolate(medicine.strength!.trim())}',
                  ),
                ],
                if (_cleanText(medicine.form) != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.text('common.form')}: ${l10n.isolate(medicine.form!.trim())}',
                  ),
                ],
              ],
            ),
          ),
        if (medicine == null && _medicineResults.isNotEmpty) ...[
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: List.generate(_medicineResults.length, (index) {
                final medicine = _medicineResults[index];
                final subtitle = _buildMedicineSuggestionSubtitle(medicine);

                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.search_outlined),
                      title: Text(l10n.isolate(_displayMedicineName(medicine))),
                      subtitle: subtitle == null ? null : Text(subtitle),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                      ),
                      onTap: () => _selectMedicine(medicine),
                    ),
                    if (index != _medicineResults.length - 1)
                      const Divider(height: 1),
                  ],
                );
              }),
            ),
          ),
        ],
        if (medicine == null &&
            _medicineSearchFeedback != null &&
            nameController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _medicineSearchFeedback!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> updateMedication() async {
    final l10n = context.l10n;
    if (selectedMedicine == null) {
      setState(() {
        _medicineSelectionError = l10n.text('medication.selectFromList');
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final medicationId = widget.medication.id;
    final medicine = selectedMedicine!;

    if (user == null || medicationId == null) {
      _showMessage(l10n.text('medication.validation.signInUpdate'));
      return;
    }

    final List<String> times;
    try {
      times = _buildReminderTimes();
    } on ArgumentError {
      _showMessage(l10n.text('medication.validation.timesRequired'));
      return;
    } on FormatException {
      _showMessage(l10n.text('medication.validation.firstReminder'));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String? imageUrl = widget.medication.imageUrl;

      if (_selectedMedicationImage != null) {
        imageUrl = await _imageStorageRepository.uploadMedicationImage(
          image: _selectedMedicationImage!,
        );
      }

      final updatedMedication = widget.medication.copyWith(
        id: medicationId,
        userId: user.uid,
        name: _displayMedicineName(medicine),
        medicineId: _cleanText(medicine.id),
        genericName: _cleanText(medicine.genericName),
        brandName: _cleanText(medicine.brandName),
        activeIngredients: medicine.activeIngredients,
        strength: _cleanText(medicine.strength),
        doseAmount: double.parse(doseController.text.trim()),
        doseUnit: selectedDoseUnit,
        form: _cleanText(medicine.form),
        frequencyPerDay: times.length,
        scheduledTimes: times
            .map(MedicationScheduleTime.fromDisplayString)
            .toList(growable: false),
        startDate: _parseInputDate(startDateController.text),
        endDate: _parseInputDate(finishDateController.text),
        clearEndDate: finishDateController.text.trim().isEmpty,
        notes: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        imageUrl: imageUrl,
        notificationIds: const <int>[],
      );

      await NotificationService.cancelNotifications(
        widget.medication.notificationIds,
      );

      await _medicationRepository.updateMedicationRecord(
        uid: user.uid,
        medicationId: medicationId,
        medication: updatedMedication,
      );
      final notificationsEnabled =
          await NotificationService.areNotificationsEnabled();
      final List<int> newNotificationIds =
          await NotificationService.scheduleMedicationReminders(
            medicineName: updatedMedication.name,
            times: updatedMedication.reminderTimes,
            body: l10n.format('medication.notificationBody', <String, String>{
              'medicine': updatedMedication.name,
            }),
            userId: user.uid,
            medicationId: medicationId,
            startDate: updatedMedication.startDate,
            endDate: updatedMedication.endDate,
          );

      await _medicationRepository.updateMedicationRecord(
        uid: user.uid,
        medicationId: medicationId,
        medication: updatedMedication.copyWith(
          notificationIds: newNotificationIds,
        ),
      );

      if (!mounted) return;

      if (!notificationsEnabled) {
        _showMessage(
          l10n.text('medication.updated.off'),
          type: AppSnackBarType.success,
        );
      } else if (newNotificationIds.length >= times.length) {
        _showMessage(
          l10n.text('medication.updated'),
          type: AppSnackBarType.success,
        );
      } else if (newNotificationIds.isNotEmpty) {
        _showMessage(
          l10n.text('medication.updated.partial'),
          type: AppSnackBarType.warning,
        );
      } else {
        _showMessage(
          l10n.text('medication.updated.noReminders'),
          type: AppSnackBarType.warning,
        );
      }

      Navigator.pop(context);
    } on ImageStorageRepositoryException catch (e) {
      if (!mounted) return;

      _showMessage(e.message);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage(
        _firebaseErrorMessage(
          e,
          fallbackMessage: l10n.text('medication.updateError'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        l10n.format('medication.updateErrorDetail', <String, String>{
          'error': l10n.isolate(e.toString()),
        }),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.text('medication.edit.title')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  decoration:
                      customInputDecoration(
                        l10n.text('medication.nameRequired'),
                      ).copyWith(
                        suffixIcon: _buildNameSuffixIcon(),
                        helperText: l10n.text('medication.nameHelper'),
                        errorText: _medicineSelectionError,
                      ),
                  textInputAction: TextInputAction.search,
                  onChanged: _handleMedicineNameChanged,
                ),
                const SizedBox(height: 10),
                _buildMedicineSelectionPanel(),
                const SizedBox(height: 14),
                _buildMedicationImageSection(),
                const SizedBox(height: 14),

                TextFormField(
                  controller: doseController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: customInputDecoration(
                    l10n.text('medication.doseAmount'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.text('medication.validation.doseRequired');
                    }

                    final number = double.tryParse(value.trim());
                    if (number == null || number <= 0) {
                      return l10n.text('medication.validation.validDose');
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: selectedDoseUnit,
                  decoration: customInputDecoration(
                    l10n.text('medication.doseUnit'),
                  ),
                  items: doseUnits.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedDoseUnit = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: timesPerDayController,
                  keyboardType: TextInputType.number,
                  decoration: customInputDecoration(
                    l10n.text('medication.timesPerDay'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.text('medication.validation.timesRequired');
                    }

                    final number = int.tryParse(value.trim());
                    if (number == null) {
                      return l10n.text('medication.validation.enterNumber');
                    }

                    if (number < 1 || number > 6) {
                      return l10n.text('medication.validation.timesRange');
                    }

                    return null;
                  },
                  onChanged: (value) {
                    if (value.trim().isEmpty) {
                      return;
                    }

                    int parsed = int.tryParse(value) ?? 1;

                    if (parsed > 6) {
                      parsed = 6;
                      timesPerDayController.text = '6';
                      timesPerDayController.selection =
                          TextSelection.fromPosition(TextPosition(offset: 1));

                      AppSnackBar.show(
                        context,
                        l10n.text('medication.validation.maxTimes'),
                        type: AppSnackBarType.warning,
                      );
                    }

                    if (parsed < 1) {
                      parsed = 1;
                    }

                    setState(() {
                      _updateTimesPerDay(parsed);
                    });
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: firstReminderTimeController,
                  readOnly: true,
                  onTap: _pickFirstReminderTime,
                  decoration:
                      customInputDecoration(
                        l10n.text('medication.firstReminder'),
                      ).copyWith(
                        helperText: l10n.text('medication.reminderHelper'),
                        suffixIcon: const Icon(Icons.access_time),
                      ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.text('medication.validation.firstReminder');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                _buildReminderSchedulePreview(),
                const SizedBox(height: 14),

                TextFormField(
                  controller: startDateController,
                  readOnly: true,
                  onTap: pickStartDate,
                  decoration: customInputDecoration(
                    l10n.text('medication.startDate'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.text('medication.validation.startDate');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: finishDateController,
                  readOnly: true,
                  onTap: pickFinishDate,
                  decoration:
                      customInputDecoration(
                        l10n.text('medication.finishDate'),
                      ).copyWith(
                        helperText: l10n.text('medication.finishDateHelper'),
                        suffixIcon: finishDateController.text.trim().isEmpty
                            ? const Icon(Icons.calendar_today)
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: l10n.text(
                                  'medication.clearFinishDate',
                                ),
                                onPressed: () {
                                  setState(() {
                                    finishDateController.clear();
                                  });
                                },
                              ),
                      ),
                  validator: (value) {
                    final finishDate = _parseInputDate(value ?? '');
                    if ((value ?? '').trim().isEmpty) {
                      return null;
                    }

                    if (finishDate == null) {
                      return l10n.text('medication.validation.finishDate');
                    }

                    final startDate = _parseInputDate(startDateController.text);
                    if (startDate != null && finishDate.isBefore(startDate)) {
                      return l10n.text(
                        'medication.validation.finishBeforeStart',
                      );
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: customInputDecoration(
                    l10n.text('medication.notes'),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : updateMedication,
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.text('common.saveChanges')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
