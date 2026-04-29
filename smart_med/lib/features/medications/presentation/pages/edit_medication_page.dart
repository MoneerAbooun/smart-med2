import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/core/firebase/image_storage_repository.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/medications/data/repositories/medication_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';
import 'package:smart_med/models/local_medicine.dart';
import 'package:smart_med/services/local_medicine_service.dart';

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
    final intervalMinutes =
        MedicationScheduleTime.intervalMinutesForDailyFrequency(timesPerDay);
    final hours = intervalMinutes ~/ 60;
    final minutes = intervalMinutes % 60;

    if (hours == 0) {
      return '$minutes minute${minutes == 1 ? '' : 's'}';
    }

    if (minutes == 0) {
      return '$hours hour${hours == 1 ? '' : 's'}';
    }

    return '$hours hour${hours == 1 ? '' : 's'} '
        '$minutes minute${minutes == 1 ? '' : 's'}';
  }

  Widget _buildReminderSchedulePreview() {
    final previewTimes = _previewReminderTimes();
    final colorScheme = Theme.of(context).colorScheme;
    final message = previewTimes.isEmpty
        ? 'After you choose the first reminder time, the app will '
              'calculate the rest every ${_reminderIntervalText()}.'
        : 'Calculated reminder times: ${previewTimes.join(', ')}';

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
            'Medicine Photo',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Optional. Updating the photo uploads a new file to the Smart Med server.',
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
                            'No photo selected',
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
                      ? 'Change Photo'
                      : 'Upload Photo',
                ),
              ),
              if (_selectedMedicationImageBytes != null)
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _clearMedicationImage,
                  icon: const Icon(Icons.close),
                  label: const Text('Reset'),
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
        startDateController.text =
            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
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
        'Unknown medicine';
  }

  String? _buildMedicineSuggestionSubtitle(LocalMedicine medicine) {
    final genericName = _cleanText(medicine.genericName);
    final strength = _cleanText(medicine.strength);
    final form = _cleanText(medicine.form);
    final parts = <String>[
      if (genericName != null) 'Generic: $genericName',
      if (strength != null) 'Strength: $strength',
      if (form != null) 'Form: $form',
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

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _firebaseErrorMessage(
    FirebaseException exception, {
    required String fallbackMessage,
  }) {
    switch (exception.code.trim()) {
      case 'permission-denied':
        return 'You do not have permission to update this medication.';
      case 'unauthenticated':
        return 'Please sign in again before updating this medication.';
      case 'unavailable':
        return 'Firebase is temporarily unavailable. Please try again.';
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
            ? 'No matches found in the local medicine list.'
            : null;
        _medicineSelectionError = selectedMedicine == null && query.isNotEmpty
            ? 'Please select a medicine from the list.'
            : null;
      });
    } catch (_) {
      if (!mounted || nameController.text.trim() != query) {
        return;
      }

      setState(() {
        isSearchingMedicines = false;
        _medicineResults = const <LocalMedicine>[];
        _medicineSearchFeedback =
            'Could not search the local medicine list right now.';
        _medicineSelectionError = 'Please select a medicine from the list.';
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
                        '${_displayMedicineName(medicine)} selected from local medicines',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading ? null : _clearMedicineSelection,
                      child: const Text('Change'),
                    ),
                  ],
                ),
                if (_cleanText(medicine.brandName) != null) ...[
                  const SizedBox(height: 8),
                  Text('Brand: ${medicine.brandName!.trim()}'),
                ],
                if (_cleanText(medicine.genericName) != null) ...[
                  const SizedBox(height: 8),
                  Text('Generic: ${medicine.genericName!.trim()}'),
                ],
                if (medicine.activeIngredients.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Active ingredients: ${medicine.activeIngredients.join(', ')}',
                  ),
                ],
                if (_cleanText(medicine.strength) != null) ...[
                  const SizedBox(height: 6),
                  Text('Strength: ${medicine.strength!.trim()}'),
                ],
                if (_cleanText(medicine.form) != null) ...[
                  const SizedBox(height: 6),
                  Text('Form: ${medicine.form!.trim()}'),
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
                      title: Text(_displayMedicineName(medicine)),
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
            alignment: Alignment.centerLeft,
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
    if (selectedMedicine == null) {
      setState(() {
        _medicineSelectionError = 'Please select a medicine from the list.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final medicationId = widget.medication.id;
    final medicine = selectedMedicine!;

    if (user == null || medicationId == null) {
      _showMessage('Please sign in again before updating this medication.');
      return;
    }

    final List<String> times;
    try {
      times = _buildReminderTimes();
    } on ArgumentError {
      _showMessage('Please enter a valid daily frequency.');
      return;
    } on FormatException {
      _showMessage('Please select the first reminder time.');
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
        startDate: DateTime.tryParse(startDateController.text.trim()),
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
            body: 'Time to take ${updatedMedication.name}',
            userId: user.uid,
            medicationId: medicationId,
            startDate: updatedMedication.startDate,
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
          'Medication updated successfully. Reminders are off in Settings.',
        );
      } else if (newNotificationIds.length == times.length) {
        _showMessage('Medication updated successfully');
      } else if (newNotificationIds.isNotEmpty) {
        _showMessage(
          'Medication updated, but some reminders could not be scheduled.',
        );
      } else {
        _showMessage(
          'Medication updated, but reminders could not be scheduled.',
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
          fallbackMessage: 'Could not update the medication right now.',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not update the medication. ${e.toString()}');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Medication'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: customInputDecoration('Medication Name *')
                      .copyWith(
                        suffixIcon: _buildNameSuffixIcon(),
                        helperText:
                            'Search and select from the local medicine list.',
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
                  decoration: customInputDecoration('Dosage'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter dosage';
                    }

                    final number = double.tryParse(value.trim());
                    if (number == null || number <= 0) {
                      return 'Enter a valid dosage number';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: selectedDoseUnit,
                  decoration: customInputDecoration('Dose Unit'),
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
                  decoration: customInputDecoration('Frequency per day'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the daily frequency';
                    }

                    final number = int.tryParse(value.trim());
                    if (number == null) {
                      return 'Enter a valid number';
                    }

                    if (number < 1 || number > 6) {
                      return 'Times per day must be between 1 and 6';
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

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Maximum is 6 times per day'),
                        ),
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
                  decoration: customInputDecoration('First Reminder Time').copyWith(
                    helperText:
                        'The app will calculate the remaining reminders automatically.',
                    suffixIcon: const Icon(Icons.access_time),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please select the first reminder time';
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
                  decoration: customInputDecoration('Start Date'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please choose start date';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: customInputDecoration('Notes'),
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
                        : const Text('Save Changes'),
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
