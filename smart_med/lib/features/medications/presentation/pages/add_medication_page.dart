import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/core/firebase/image_storage_repository.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/interactions/presentation/interaction_result_localization.dart';
import 'package:smart_med/features/medications/data/services/medication_image_autofill_service.dart';
import 'package:smart_med/features/medications/data/repositories/medication_repository.dart';
import 'package:smart_med/features/medications/data/services/medication_safety_assessment_service.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';
import 'package:smart_med/features/medications/domain/models/medication_safety_assessment.dart';
import 'package:smart_med/features/medicine_search/presentation/medicine_result_localization.dart';
import 'package:smart_med/models/local_medicine.dart';
import 'package:smart_med/services/local_medicine_service.dart';
import 'package:smart_med/core/widgets/app_snack_bar.dart';

class AddMedicationPage extends StatefulWidget {
  const AddMedicationPage({
    super.key,
    this.initialMedicationImage,
    this.initialMedicationImageBytes,
  });

  final XFile? initialMedicationImage;
  final Uint8List? initialMedicationImageBytes;

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final MedicationRepository _medicationRepository = medicationRepository;
  final LocalMedicineService _localMedicineService = localMedicineService;
  final ImagePicker _imagePicker = ImagePicker();
  final ImageStorageRepository _imageStorageRepository = imageStorageRepository;
  final MedicationImageAutofillService _medicationImageAutofillService =
      medicationImageAutofillService;
  final MedicationSafetyAssessmentService _safetyAssessmentService =
      medicationSafetyAssessmentService;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController doseController = TextEditingController();
  final TextEditingController timesPerDayController = TextEditingController();
  final TextEditingController startDateController = TextEditingController();
  final TextEditingController finishDateController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController firstReminderTimeController =
      TextEditingController();
  final Duration _medicineSearchDelay = const Duration(milliseconds: 300);

  bool isLoading = false;
  bool isSearchingMedicines = false;
  bool _isCheckingSafety = false;
  bool _isAutofillingMedicationImage = false;
  int timesPerDay = 1;
  Timer? _medicineSearchDebounce;
  List<LocalMedicine> _medicineResults = const <LocalMedicine>[];
  LocalMedicine? selectedMedicine;
  MedicationSafetyAssessment? _safetyAssessment;
  String? _medicineSearchFeedback;
  String? _medicineSelectionError;
  String? _safetyAssessmentError;
  String? _imageAutofillFeedback;
  XFile? _selectedMedicationImage;
  Uint8List? _selectedMedicationImageBytes;
  int _safetyAssessmentRequest = 0;

  String selectedDoseUnit = 'mg';
  final List<String> doseUnits = [
    'mg',
    'mcg',
    'g',
    'ml',
    'iu',
    'tablet',
    'capsule',
  ];

  @override
  void initState() {
    super.initState();
    timesPerDay = 1;
    timesPerDayController.text = '1';

    _selectedMedicationImage = widget.initialMedicationImage;
    _selectedMedicationImageBytes = widget.initialMedicationImageBytes;

    if (_selectedMedicationImage != null &&
        _selectedMedicationImageBytes == null) {
      _loadInitialMedicationImageBytes();
    }

    if (_selectedMedicationImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autofillMedicationDetailsFromPhoto(_selectedMedicationImage!);
      });
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

  Future<void> _loadInitialMedicationImageBytes() async {
    final image = _selectedMedicationImage;
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted || _selectedMedicationImage != image) {
      return;
    }

    setState(() {
      _selectedMedicationImageBytes = bytes;
    });
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
      _imageAutofillFeedback = null;
    });

    await _autofillMedicationDetailsFromPhoto(image);
  }

  void _clearMedicationImage() {
    setState(() {
      _selectedMedicationImage = null;
      _selectedMedicationImageBytes = null;
      _imageAutofillFeedback = null;
      _isAutofillingMedicationImage = false;
    });
  }

  Widget _buildMedicationImageSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

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
            l10n.text('medication.photo.addSubtitle'),
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
                  _selectedMedicationImageBytes == null
                      ? l10n.text('common.addPhoto')
                      : l10n.text('common.changePhoto'),
                ),
              ),
              if (_selectedMedicationImageBytes != null)
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _clearMedicationImage,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.text('common.clear')),
                ),
            ],
          ),
          if (_isAutofillingMedicationImage) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.text('medication.photo.reading'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_imageAutofillFeedback != null) ...[
            const SizedBox(height: 12),
            Text(
              _imageAutofillFeedback!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
      final formattedTime = pickedTime.format(context);
      setState(() {
        firstReminderTimeController.text = formattedTime;
      });
    }
  }

  Future<void> pickStartDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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

  DateTime? _parseInputDate(String value) {
    return DateTime.tryParse(value.trim());
  }

  String _formatDateForInput(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
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

  void _resetSafetyAssessmentState() {
    _safetyAssessmentRequest++;
    _isCheckingSafety = false;
    _safetyAssessment = null;
    _safetyAssessmentError = null;
  }

  Future<MedicationSafetyAssessment?> _runSafetyAssessment(
    LocalMedicine medicine, {
    required String uid,
  }) async {
    final requestId = ++_safetyAssessmentRequest;

    setState(() {
      _isCheckingSafety = true;
      _safetyAssessment = null;
      _safetyAssessmentError = null;
    });

    try {
      final assessment = await _safetyAssessmentService.assessMedicine(
        uid: uid,
        medicine: medicine,
      );

      if (!mounted || requestId != _safetyAssessmentRequest) {
        return null;
      }

      setState(() {
        _isCheckingSafety = false;
        _safetyAssessment = assessment;
        _safetyAssessmentError = null;
      });

      return assessment;
    } catch (_) {
      if (!mounted || requestId != _safetyAssessmentRequest) {
        return null;
      }

      setState(() {
        _isCheckingSafety = false;
        _safetyAssessment = null;
        _safetyAssessmentError = context.l10n.text('medication.safety.error');
      });

      return null;
    }
  }

  Future<void> _refreshSafetyAssessment(LocalMedicine medicine) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    await _runSafetyAssessment(medicine, uid: user.uid);
  }

  Future<MedicationSafetyAssessment?> _ensureSafetyAssessment({
    required String uid,
    required LocalMedicine medicine,
  }) async {
    final existing = _safetyAssessment;
    if (existing != null &&
        existing.medicineKey == medicationSafetyKey(medicine) &&
        !_isCheckingSafety) {
      return existing;
    }

    return _runSafetyAssessment(medicine, uid: uid);
  }

  MedicationRecord _buildMedicationRecord(
    String uid,
    List<String> times, {
    String? imageUrl,
    MedicationSafetyAssessment? acknowledgedSafetyAssessment,
  }) {
    final medicine = selectedMedicine;
    if (medicine == null) {
      throw StateError('No medicine selected.');
    }
    final acknowledgedSafetyWarningCount =
        acknowledgedSafetyAssessment?.signals.length ?? 0;

    return MedicationRecord(
      userId: uid,
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
      notes: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
      imageUrl: imageUrl,
      remindersEnabled: true,
      status: 'active',
      safetyWarningsAcknowledged: acknowledgedSafetyWarningCount > 0,
      safetyWarningCount: acknowledgedSafetyWarningCount,
      notificationIds: const <int>[],
    );
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
        return l10n.text('medication.permissionSave');
      case 'unauthenticated':
        return l10n.text('medication.validation.signInSave');
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
        _resetSafetyAssessmentState();
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
        _resetSafetyAssessmentState();
      });
    }

    _scheduleMedicineSearch(trimmedValue);
  }

  void _applySelectedMedicine(LocalMedicine medicine, {bool unfocus = true}) {
    _medicineSearchDebounce?.cancel();

    final displayName = _displayMedicineName(medicine);
    nameController.text = displayName;
    nameController.selection = TextSelection.fromPosition(
      TextPosition(offset: displayName.length),
    );

    if (unfocus) {
      FocusScope.of(context).unfocus();
    }

    setState(() {
      selectedMedicine = medicine;
      _medicineResults = const <LocalMedicine>[];
      _medicineSearchFeedback = null;
      _medicineSelectionError = null;
      isSearchingMedicines = false;
    });

    unawaited(_refreshSafetyAssessment(medicine));
  }

  void _selectMedicine(LocalMedicine medicine) {
    _applySelectedMedicine(medicine);
  }

  void _clearMedicineSelection() {
    _medicineSearchDebounce?.cancel();

    nameController.clear();

    setState(() {
      selectedMedicine = null;
      _resetSafetyAssessmentState();
      _medicineResults = const <LocalMedicine>[];
      _medicineSearchFeedback = null;
      _medicineSelectionError = null;
      isSearchingMedicines = false;
    });
  }

  Future<void> _autofillMedicationDetailsFromPhoto(XFile image) async {
    setState(() {
      _isAutofillingMedicationImage = true;
      _imageAutofillFeedback = null;
    });

    try {
      final result = await _medicationImageAutofillService
          .identifyLocalMedicine(image: image);

      if (!mounted || _selectedMedicationImage != image) {
        return;
      }

      _applySelectedMedicine(result.medicine, unfocus: false);

      setState(() {
        _isAutofillingMedicationImage = false;

        final dosage = result.dosage;
        if (dosage != null) {
          doseController.text = dosage.formattedAmount;
          if (doseUnits.contains(dosage.unit)) {
            selectedDoseUnit = dosage.unit;
          }
          _imageAutofillFeedback = context.l10n.text(
            'medication.photo.filledNameDose',
          );
          return;
        }

        _imageAutofillFeedback = context.l10n.text(
          'medication.photo.filledName',
        );
      });
    } on MedicationImageAutofillException catch (error) {
      if (!mounted || _selectedMedicationImage != image) {
        return;
      }

      setState(() {
        _isAutofillingMedicationImage = false;
        _imageAutofillFeedback = error.message;
      });
    } catch (_) {
      if (!mounted || _selectedMedicationImage != image) {
        return;
      }

      setState(() {
        _isAutofillingMedicationImage = false;
        _imageAutofillFeedback = context.l10n.text(
          'medication.photo.unavailable',
        );
      });
    }
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

  Widget _buildSafetyAssessmentPanel() {
    final medicine = selectedMedicine;
    if (medicine == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final assessment = _safetyAssessment;
    final hasSignals = assessment?.hasSignals ?? false;
    final hasNotes = assessment?.notes.isNotEmpty ?? false;
    final hasError = _safetyAssessmentError != null;
    final backgroundColor = hasSignals
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHighest;
    final foregroundColor = hasSignals
        ? colorScheme.onErrorContainer
        : colorScheme.onSurfaceVariant;
    final icon = hasSignals
        ? Icons.warning_amber_rounded
        : hasError
        ? Icons.info_outline
        : Icons.verified_user_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasSignals ? colorScheme.error : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: foregroundColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.text('medication.safety.title'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasError)
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => unawaited(_refreshSafetyAssessment(medicine)),
                  child: Text(l10n.text('common.retry')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isCheckingSafety) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              l10n.text('medication.safety.checking'),
              style: TextStyle(color: foregroundColor),
            ),
          ] else if (hasError) ...[
            Text(
              _safetyAssessmentError!,
              style: TextStyle(color: foregroundColor),
            ),
          ] else if (assessment == null) ...[
            Text(
              l10n.text('medication.safety.pending'),
              style: TextStyle(color: foregroundColor),
            ),
          ] else if (hasSignals) ...[
            Text(
              l10n.text('medication.safety.signalsFound'),
              style: TextStyle(color: foregroundColor),
            ),
            const SizedBox(height: 10),
            _buildSafetySignalList(assessment, dense: true),
          ] else if (hasNotes) ...[
            Text(
              l10n.text('medication.safety.limited'),
              style: TextStyle(color: foregroundColor),
            ),
          ] else ...[
            Text(
              l10n.text('medication.safety.noSignals'),
              style: TextStyle(color: foregroundColor),
            ),
          ],
          if (assessment != null && assessment.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...assessment.notes
                .take(2)
                .map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: foregroundColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _localizedSafetyNote(note, assessment),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: foregroundColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetySignalList(
    MedicationSafetyAssessment assessment, {
    required bool dense,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: assessment.signals
          .map((signal) {
            final evidence = signal.evidence.take(dense ? 1 : 2).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: dense ? 8 : 12),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(dense ? 10 : 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _safetySignalIcon(signal.type),
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${context.l10n.severity(signal.severity)}: ${_localizedSafetySignalTitle(signal)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_localizedSafetySignalDetail(signal, assessment)),
                    if (evidence.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...evidence.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _localizedSafetyEvidence(signal, item),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  String _localizedSafetySignalTitle(MedicationSafetySignal signal) {
    final key = switch (signal.type) {
      MedicationSafetySignalType.directAllergy =>
        'medication.safety.signal.directAllergy.title',
      MedicationSafetySignalType.allergyInteraction =>
        'medication.safety.signal.allergyInteraction.title',
      MedicationSafetySignalType.allergyWarning =>
        'medication.safety.signal.allergyWarning.title',
      MedicationSafetySignalType.chronicConditionWarning =>
        'medication.safety.signal.conditionWarning.title',
    };

    return context.l10n.text(key);
  }

  String _localizedSafetySignalDetail(
    MedicationSafetySignal signal,
    MedicationSafetyAssessment assessment,
  ) {
    final l10n = context.l10n;
    final profileItem = signal.matchedProfileItem ?? '';
    final values = <String, String>{
      'medicine': l10n.isolate(assessment.medicineName),
      'allergy': l10n.isolate(profileItem),
      'condition': l10n.isolate(profileItem),
      'summary': l10n.interactionResultText(signal.sourceSummary ?? ''),
    };

    final key = switch (signal.type) {
      MedicationSafetySignalType.directAllergy =>
        'medication.safety.signal.directAllergy.detail',
      MedicationSafetySignalType.allergyInteraction =>
        'medication.safety.signal.allergyInteraction.detail',
      MedicationSafetySignalType.allergyWarning =>
        'medication.safety.signal.allergyWarning.detail',
      MedicationSafetySignalType.chronicConditionWarning =>
        'medication.safety.signal.conditionWarning.detail',
    };

    final detail = l10n.format(key, values);
    if (detail != key) {
      return detail;
    }

    return l10n.isArabic ? l10n.isolate(signal.detail) : signal.detail;
  }

  String _localizedSafetyEvidence(
    MedicationSafetySignal signal,
    String evidence,
  ) {
    final l10n = context.l10n;

    switch (signal.type) {
      case MedicationSafetySignalType.allergyInteraction:
        return l10n.interactionResultText(evidence);
      case MedicationSafetySignalType.directAllergy:
      case MedicationSafetySignalType.allergyWarning:
      case MedicationSafetySignalType.chronicConditionWarning:
        return l10n.medicineResultText(
          evidence,
          section: MedicineResultSection.warnings,
        );
    }
  }

  String _localizedSafetyNote(
    String note,
    MedicationSafetyAssessment assessment,
  ) {
    final l10n = context.l10n;
    if (!l10n.isArabic) {
      return note;
    }

    if (note == 'We could not find your safety profile for this check.') {
      return l10n.text('medication.safety.note.profileMissing');
    }

    const labelPrefix = 'Public medicine label warnings could not be checked: ';
    if (note.startsWith(labelPrefix)) {
      return l10n.format('medication.safety.note.labelUnavailable', {
        'error': l10n.medicineResultText(note.substring(labelPrefix.length)),
      });
    }

    final compareMatch = RegExp(
      r'^Could not compare (.+) with allergy "(.+)"(?:: (.+))?\.?$',
    ).firstMatch(note);
    if (compareMatch != null) {
      final error = compareMatch.group(3);
      if (error == null || error.trim().isEmpty) {
        return l10n.format('medication.safety.note.compareUnavailable', {
          'medicine': l10n.isolate(compareMatch.group(1)!),
          'allergy': l10n.isolate(compareMatch.group(2)!),
        });
      }

      return l10n.format('medication.safety.note.compareUnavailableDetail', {
        'medicine': l10n.isolate(compareMatch.group(1)!),
        'allergy': l10n.isolate(compareMatch.group(2)!),
        'error': l10n.interactionResultText(error),
      });
    }

    return l10n.isolate(note);
  }

  IconData _safetySignalIcon(MedicationSafetySignalType type) {
    switch (type) {
      case MedicationSafetySignalType.directAllergy:
      case MedicationSafetySignalType.allergyWarning:
        return Icons.warning_amber_rounded;
      case MedicationSafetySignalType.allergyInteraction:
        return Icons.sync_alt_rounded;
      case MedicationSafetySignalType.chronicConditionWarning:
        return Icons.health_and_safety_outlined;
    }
  }

  Future<bool> _confirmSafetyAssessment(
    MedicationSafetyAssessment assessment,
  ) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.text('medication.safety.confirmTitle')),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.format('medication.safety.confirmMessage', {
                      'medicine': l10n.isolate(assessment.medicineName),
                    }),
                  ),
                  const SizedBox(height: 14),
                  _buildSafetySignalList(assessment, dense: false),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.text('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.text('medication.safety.addAnyway')),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> addMedication() async {
    final l10n = context.l10n;
    if (selectedMedicine == null) {
      setState(() {
        _medicineSelectionError = l10n.text('medication.selectFromList');
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(l10n.text('medication.validation.signInSave'));
      return;
    }

    if (_isCheckingSafety) {
      _showMessage(
        l10n.text('medication.safety.wait'),
        type: AppSnackBarType.warning,
      );
      return;
    }

    final safetyAssessment = await _ensureSafetyAssessment(
      uid: user.uid,
      medicine: selectedMedicine!,
    );

    if (!mounted) return;

    if (safetyAssessment == null) {
      _showMessage(
        l10n.text('medication.safety.error'),
        type: AppSnackBarType.warning,
      );
      return;
    }

    MedicationSafetyAssessment? acknowledgedSafetyAssessment;
    if (safetyAssessment.needsConfirmation) {
      final confirmed = await _confirmSafetyAssessment(safetyAssessment);
      if (!mounted || !confirmed) {
        return;
      }
      acknowledgedSafetyAssessment = safetyAssessment;
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
      final medicationId = _medicationRepository.createMedicationId(
        uid: user.uid,
      );
      String? imageUrl;

      if (_selectedMedicationImage != null) {
        imageUrl = await _imageStorageRepository.uploadMedicationImage(
          image: _selectedMedicationImage!,
        );
      }

      final medication = _buildMedicationRecord(
        user.uid,
        times,
        imageUrl: imageUrl,
        acknowledgedSafetyAssessment: acknowledgedSafetyAssessment,
      );

      await _medicationRepository.saveMedicationRecord(
        uid: user.uid,
        medication: medication,
        medicationId: medicationId,
      );

      final notificationsEnabled =
          await NotificationService.areNotificationsEnabled();
      List<int> notificationIds = [];

      notificationIds = await NotificationService.scheduleMedicationReminders(
        medicineName: medication.name,
        times: medication.reminderTimes,
        body: l10n.format('medication.notificationBody', <String, String>{
          'medicine': medication.name,
        }),
        userId: user.uid,
        medicationId: medicationId,
        startDate: medication.startDate,
        endDate: medication.endDate,
      );

      await _medicationRepository.updateMedicationRecord(
        uid: user.uid,
        medicationId: medicationId,
        medication: medication.copyWith(
          id: medicationId,
          imageUrl: imageUrl,
          notificationIds: notificationIds,
        ),
      );

      if (!mounted) return;

      if (!notificationsEnabled) {
        _showMessage(
          l10n.text('medication.saved.off'),
          type: AppSnackBarType.success,
        );
      } else if (notificationIds.length >= times.length) {
        _showMessage(
          l10n.text('medication.saved'),
          type: AppSnackBarType.success,
        );
      } else if (notificationIds.isNotEmpty) {
        _showMessage(
          l10n.text('medication.saved.partial'),
          type: AppSnackBarType.warning,
        );
      } else {
        _showMessage(
          l10n.text('medication.saved.noReminders'),
          type: AppSnackBarType.warning,
        );
      }

      Navigator.pop(context, true);
    } on ImageStorageRepositoryException catch (e) {
      if (!mounted) return;

      _showMessage(e.message);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage(
        _firebaseErrorMessage(
          e,
          fallbackMessage: l10n.text('medication.saveError'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        l10n.format('medication.saveErrorDetail', <String, String>{
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
        title: Text(l10n.text('medication.add.title')),
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
                const SizedBox(height: 10),
                _buildSafetyAssessmentPanel(),
                const SizedBox(height: 14),
                _buildMedicationImageSection(),
                const SizedBox(height: 14),

                TextFormField(
                  controller: doseController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: customInputDecoration(
                    l10n.text('medication.doseAmountRequired'),
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
                  key: ValueKey<String>('dose-unit-$selectedDoseUnit'),
                  initialValue: selectedDoseUnit,
                  decoration: customInputDecoration(
                    l10n.text('medication.doseUnitRequired'),
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
                    l10n.text('medication.timesPerDayRequired'),
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
                      setState(() {
                        timesPerDay = 1;
                      });
                      return;
                    }

                    int parsed = int.tryParse(value) ?? 1;

                    if (parsed > 6) {
                      parsed = 6;
                      timesPerDayController.text = '6';
                      timesPerDayController.selection =
                          TextSelection.fromPosition(
                            const TextPosition(offset: 1),
                          );

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
                        l10n.text('medication.firstReminderRequired'),
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
                    l10n.text('medication.startDateRequired'),
                  ).copyWith(suffixIcon: const Icon(Icons.calendar_today)),
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
                    onPressed:
                        isLoading ||
                            _isAutofillingMedicationImage ||
                            _isCheckingSafety ||
                            selectedMedicine == null
                        ? null
                        : addMedication,
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isCheckingSafety
                                ? l10n.text('common.checking')
                                : l10n.text('common.addMedicine'),
                          ),
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
