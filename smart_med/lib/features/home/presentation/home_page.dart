import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/alternative_drug/alternative_drug.dart';
import 'package:smart_med/features/interactions/interactions.dart';
import 'package:smart_med/features/medications/medications.dart';
import 'package:smart_med/features/medicine_search/medicine_search.dart';
import 'package:smart_med/features/profile/profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();

  bool isCameraOpened = false;
  bool isCapturing = false;
  bool _isScanPanelExpanded = false;

  CameraController? controller;
  Future<void>? initializeControllerFuture;
  XFile? selectedImage;
  final Set<String> _handledDoseKeys = <String>{};
  final Map<String, DateTime> _snoozedDoses = <String, DateTime>{};

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _openInteractionChecker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckInteractionsPage()),
    );
  }

  Future<void> _openMedicationList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicationListPage()),
    );
  }

  Future<void> _openAlternativeDrugSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AlternativeDrugSearchPage(),
      ),
    );
  }

  Future<void> _openProfilePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  Future<void> _openAddMedication() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMedicationPage()),
    );
  }

  Future<void> _openMedicineSearch({XFile? initialImage}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicineSearchPage(initialImage: initialImage),
      ),
    );
  }

  Future<void> _continueWithSelectedImage() async {
    final image = selectedImage;
    if (image == null) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicationPage(initialMedicationImage: image),
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      await backToPlaceholder();
    }
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw Exception('No cameras available');
    }

    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    initializeControllerFuture = controller!.initialize();
    await initializeControllerFuture;
  }

  Future<void> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        isCameraOpened = false;
        isCapturing = false;
        _isScanPanelExpanded = true;
      });
    }
  }

  Future<void> openCamera() async {
    try {
      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }

      await _setupCamera();

      if (!mounted) return;

      setState(() {
        isCameraOpened = true;
        selectedImage = null;
        isCapturing = false;
        _isScanPanelExpanded = true;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open camera: $e')));
    }
  }

  Future<void> captureImage() async {
    if (controller == null) return;
    if (!controller!.value.isInitialized) return;
    if (controller!.value.isTakingPicture || isCapturing) return;

    try {
      setState(() {
        isCapturing = true;
      });

      await initializeControllerFuture;

      final XFile image = await controller!.takePicture();

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        isCameraOpened = false;
        isCapturing = false;
      });

      await controller!.dispose();
      controller = null;
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isCapturing = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to capture image: $e')));
    }
  }

  Future<void> backToPlaceholder() async {
    if (controller != null) {
      await controller!.dispose();
      controller = null;
    }

    if (!mounted) return;

    setState(() {
      selectedImage = null;
      isCameraOpened = false;
      isCapturing = false;
    });
  }

  String _displayName([UserProfileRecord? profile]) {
    final profileName = profile?.displayName.trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName.split(' ').first;
    }

    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name.split(' ').first;
    }

    final email = user?.email?.trim();
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'there';
  }

  List<_HomeActionItem> _actionItems() {
    return <_HomeActionItem>[
      _HomeActionItem(
        icon: Icons.search_outlined,
        title: 'Find Medicine Details',
        subtitle: 'Look up names or photos',
        tooltip:
            'Find medicine details by name or image, then review key information before you take it.',
        onTap: () => _openMedicineSearch(),
      ),
      _HomeActionItem(
        icon: Icons.compare_arrows_outlined,
        title: 'Check Drug Interactions',
        subtitle: 'See if medicines conflict',
        tooltip:
            'Compare medicines to catch interaction warnings and safety risks before combining them.',
        onTap: _openInteractionChecker,
      ),
      _HomeActionItem(
        icon: Icons.medication_outlined,
        title: 'My Active Medications',
        subtitle: 'Review current medicines',
        tooltip:
            'Open your current medication list to review details, reminders, and any edits you need to make.',
        onTap: _openMedicationList,
      ),
      _HomeActionItem(
        icon: Icons.find_replace_outlined,
        title: 'Related Medicines',
        subtitle: 'Discuss alternatives safely',
        tooltip:
            'Search for related medicines you can discuss with a doctor or pharmacist before changing treatment.',
        onTap: _openAlternativeDrugSearch,
      ),
    ];
  }

  Widget _buildGreetingCard(BuildContext context, UserProfileRecord? profile) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AppIconBadge(
            icon: Icons.health_and_safety_outlined,
            accentColor: colorScheme.primary,
            size: 50,
            iconSize: 26,
            borderRadius: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${_displayName(profile)}',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here is what needs attention today.',
                  style: textTheme.bodyMedium?.copyWith(
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  bool _isMedicationActiveOn(MedicationRecord medication, DateTime date) {
    if (medication.status.trim().toLowerCase() != 'active') {
      return false;
    }

    if (medication.scheduledTimes.isEmpty) {
      return false;
    }

    final dayStart = _startOfDay(date);
    final dayEnd = _endOfDay(date);
    final startDate = medication.startDate;
    final endDate = medication.endDate;

    if (startDate != null && startDate.isAfter(dayEnd)) {
      return false;
    }

    if (endDate != null && endDate.isBefore(dayStart)) {
      return false;
    }

    return true;
  }

  List<MedicationRecord> _activeMedications(List<MedicationRecord> items) {
    final now = DateTime.now();
    return items
        .where((medication) => _isMedicationActiveOn(medication, now))
        .toList(growable: false);
  }

  String _doseKey(MedicationRecord medication, DateTime scheduledAt) {
    final medicationKey = medication.id ?? medication.name;
    return '$medicationKey-${scheduledAt.year}-${scheduledAt.month}-${scheduledAt.day}-${scheduledAt.hour}-${scheduledAt.minute}';
  }

  List<_HomeDose> _buildDoseTimeline(List<MedicationRecord> medications) {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final doses = <_HomeDose>[];

    for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));
      for (final medication in medications) {
        if (!_isMedicationActiveOn(medication, date)) {
          continue;
        }

        for (final scheduledTime in medication.scheduledTimes) {
          final scheduledAt = DateTime(
            date.year,
            date.month,
            date.day,
            scheduledTime.hour,
            scheduledTime.minute,
          );
          final key = _doseKey(medication, scheduledAt);

          if (_handledDoseKeys.contains(key)) {
            continue;
          }

          final snoozedUntil = _snoozedDoses[key];
          doses.add(
            _HomeDose(
              medication: medication,
              scheduledAt: scheduledAt,
              displayAt: snoozedUntil ?? scheduledAt,
              key: key,
              isSnoozed: snoozedUntil != null,
            ),
          );
        }
      }
    }

    doses.sort((left, right) => left.displayAt.compareTo(right.displayAt));
    return doses;
  }

  List<_HomeDose> _buildTodayDoses(List<MedicationRecord> medications) {
    final now = DateTime.now();
    final today = _startOfDay(now);

    return _buildDoseTimeline(medications)
        .where((dose) {
          return _startOfDay(dose.scheduledAt) == today;
        })
        .toList(growable: false);
  }

  String _formatDoseTime(BuildContext context, DateTime value) {
    return TimeOfDay.fromDateTime(value).format(context);
  }

  String _relativeDoseLabel(_HomeDose dose) {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final doseDay = _startOfDay(dose.displayAt);

    if (dose.isSnoozed) {
      return 'Snoozed';
    }

    if (dose.displayAt.isBefore(now)) {
      return 'Overdue';
    }

    if (doseDay == today) {
      return 'Today';
    }

    return 'Tomorrow';
  }

  void _showHomeMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _markDoseHandled(_HomeDose dose, String action) {
    setState(() {
      _handledDoseKeys.add(dose.key);
      _snoozedDoses.remove(dose.key);
    });

    _showHomeMessage('${dose.medication.name} marked as $action.');
  }

  void _snoozeDose(_HomeDose dose) {
    final snoozedUntil = DateTime.now().add(const Duration(minutes: 15));

    setState(() {
      _snoozedDoses[dose.key] = snoozedUntil;
    });

    _showHomeMessage(
      '${dose.medication.name} snoozed until ${_formatDoseTime(context, snoozedUntil)}.',
    );
  }

  Widget _buildNextDoseCard({
    required BuildContext context,
    required List<MedicationRecord> medications,
    required bool isLoading,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final activeMedications = _activeMedications(medications);
    final timeline = _buildDoseTimeline(activeMedications);
    final nextDose = timeline.isEmpty ? null : timeline.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isLoading
          ? Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Loading today\'s medication schedule...',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          : nextDose == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIconBadge(
                      icon: activeMedications.isEmpty
                          ? Icons.add_box_outlined
                          : Icons.check_circle_outline,
                      accentColor: colorScheme.onPrimary,
                      size: 54,
                      iconSize: 28,
                      borderRadius: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        activeMedications.isEmpty
                            ? 'No active medications yet'
                            : 'No more doses today',
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  activeMedications.isEmpty
                      ? 'Add your first medicine to see your next dose here.'
                      : 'You are clear for the rest of today based on your current schedule.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openAddMedication,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medication'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.onPrimary,
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconBadge(
                      icon: Icons.notifications_active_outlined,
                      accentColor: colorScheme.onPrimary,
                      size: 54,
                      iconSize: 28,
                      borderRadius: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Dose',
                            style: textTheme.titleSmall?.copyWith(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.9,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nextDose.medication.name,
                            style: textTheme.titleLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _relativeDoseLabel(nextDose),
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${nextDose.medication.dosage} at ${_formatDoseTime(context, nextDose.displayAt)}',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((nextDose.medication.instructions ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      nextDose.medication.instructions!.trim(),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _markDoseHandled(nextDose, 'taken'),
                      icon: const Icon(Icons.check),
                      label: const Text('Taken'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.onPrimary,
                        foregroundColor: colorScheme.primary,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _snoozeDose(nextDose),
                      icon: const Icon(Icons.snooze),
                      label: const Text('Snooze'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onPrimary,
                        side: BorderSide(
                          color: colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _markDoseHandled(nextDose, 'skipped'),
                      icon: const Icon(Icons.close),
                      label: const Text('Skip'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onPrimary,
                        side: BorderSide(
                          color: colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  int _profileReadinessCount(
    UserProfileRecord? profile,
    int activeMedicationCount,
  ) {
    if (profile == null) {
      return activeMedicationCount > 0 ? 1 : 0;
    }

    return <bool>[
      profile.age != null,
      profile.allergyNames.isNotEmpty,
      profile.medicalConditionNames.isNotEmpty,
      profile.weightKg != null,
      profile.systolicPressure != null && profile.diastolicPressure != null,
      activeMedicationCount > 0,
    ].where((item) => item).length;
  }

  List<String> _missingSafetyItems(
    UserProfileRecord? profile,
    int activeMedicationCount,
  ) {
    return <String>[
      if (profile?.age == null) 'Age',
      if (profile == null || profile.allergyNames.isEmpty) 'Allergies',
      if (profile == null || profile.medicalConditionNames.isEmpty)
        'Conditions',
      if (profile?.weightKg == null) 'Weight',
      if (profile?.systolicPressure == null ||
          profile?.diastolicPressure == null)
        'Blood Pressure',
      if (activeMedicationCount == 0) 'Active Meds',
    ];
  }

  Widget _buildSafetyStatusCard({
    required BuildContext context,
    required UserProfileRecord? profile,
    required List<MedicationRecord> activeMedications,
    required bool isLoading,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final completed = _profileReadinessCount(profile, activeMedications.length);
    final missing = _missingSafetyItems(profile, activeMedications.length);
    final isComplete = completed == 6;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                icon: isComplete
                    ? Icons.verified_user_outlined
                    : Icons.shield_outlined,
                accentColor: isComplete
                    ? const Color(0xFF2E7D6F)
                    : colorScheme.primary,
                size: 46,
                iconSize: 23,
                borderRadius: 15,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safety Status',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoading
                          ? 'Loading your safety profile...'
                          : isComplete
                          ? 'Your profile has the key details for stronger warnings.'
                          : 'Profile $completed/6 complete. Add missing details for better safety checks.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLoading) ...[
            const SizedBox(height: 12),
            Text(
              '${profile?.allergyNames.length ?? 0} allergies, '
              '${profile?.medicalConditionNames.length ?? 0} conditions, '
              '${activeMedications.length} active meds',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: missing
                    .take(4)
                    .map((label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openProfilePage,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Complete Profile'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openInteractionChecker,
                    icon: const Icon(Icons.compare_arrows_outlined),
                    label: const Text('Check Meds'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStartCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Start',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openAddMedication,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Med'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isScanPanelExpanded = !_isScanPanelExpanded;
                    });
                  },
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMedicationsCard({
    required BuildContext context,
    required List<MedicationRecord> activeMedications,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final todayDoses = _buildTodayDoses(activeMedications);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.today_outlined,
                size: 42,
                iconSize: 22,
                borderRadius: 14,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Today\'s Medications',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openMedicationList,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (todayDoses.isEmpty)
            Text(
              activeMedications.isEmpty
                  ? 'No active medications yet.'
                  : 'No more scheduled doses today.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              children: todayDoses
                  .take(5)
                  .map((dose) {
                    final isHandled = _handledDoseKeys.contains(dose.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isHandled
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Icon(
                              isHandled
                                  ? Icons.check_circle_outline
                                  : Icons.medication_outlined,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dose.medication.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dose.medication.dosage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatDoseTime(context, dose.displayAt),
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    final List<_HomeActionItem> actionItems = _actionItems();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.06,
      children: actionItems
          .map(
            (_HomeActionItem item) => _buildActionTile(
              context: context,
              icon: item.icon,
              title: item.title,
              subtitle: item.subtitle,
              tooltip: item.tooltip,
              onTap: item.onTap,
            ),
          )
          .toList(),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String tooltip,
    required Future<void> Function() onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconBadge(
                      icon: icon,
                      accentColor: colorScheme.primary,
                      size: 46,
                      iconSize: 23,
                      borderRadius: 15,
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _TileTooltipButton(message: tooltip),
          ),
        ],
      ),
    );
  }

  Widget _buildScanMedicineCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.document_scanner_outlined,
                size: 42,
                iconSize: 22,
                borderRadius: 14,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search by Image',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use the camera or gallery to identify a medicine from its label or package, then search it or add it to your list.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _buildPreviewCard(context),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!isCameraOpened && selectedImage == null)
                  SizedBox(
                    width: 125,
                    child: ElevatedButton.icon(
                      onPressed: openCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),

                if (!isCameraOpened && selectedImage == null)
                  SizedBox(
                    width: 125,
                    child: ElevatedButton.icon(
                      onPressed: pickImageFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),

                if (isCameraOpened)
                  SizedBox(
                    width: 125,
                    child: ElevatedButton.icon(
                      onPressed: isCapturing ? null : captureImage,
                      icon: const Icon(Icons.camera),
                      label: Text(isCapturing ? 'Wait...' : 'Capture'),
                    ),
                  ),

                if (selectedImage != null || isCameraOpened)
                  SizedBox(
                    width: 125,
                    child: OutlinedButton.icon(
                      onPressed: backToPlaceholder,
                      icon: const Icon(Icons.close),
                      label: const Text('Clear'),
                    ),
                  ),
              ],
            ),
          ),
          if (selectedImage != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.image_outlined,
                    size: 38,
                    iconSize: 20,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Image selected and ready.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _openMedicineSearch(initialImage: selectedImage),
                    icon: const Icon(Icons.image_search_outlined),
                    label: const Text('Search'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _continueWithSelectedImage,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Med'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: selectedImage != null
            ? Image.file(
                File(selectedImage!.path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : isCameraOpened
            ? FutureBuilder<void>(
                future: initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      controller != null) {
                    return CameraPreview(controller!);
                  }

                  return const Center(child: CircularProgressIndicator());
                },
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIconBadge(
                        icon: Icons.photo_camera_back_outlined,
                        accentColor: colorScheme.onSurfaceVariant,
                        size: 64,
                        iconSize: 32,
                        borderRadius: 22,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No image selected',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use the camera or gallery to search by image.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No logged in user found')),
      );
    }

    return SafeArea(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          toolbarHeight: 70,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leadingWidth: 56,
          leading: const SizedBox(),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/Capsule.png', fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              const Text(
                'Smart Med',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: 56,
              child: IconButton(
                icon: const Icon(Icons.medication_outlined, size: 28),
                tooltip: 'Medications',
                onPressed: _openMedicationList,
              ),
            ),
          ],
        ),
        body: StreamBuilder<List<MedicationRecord>>(
          stream: medicationRepository.watchMedicationRecords(uid: user.uid),
          builder: (context, medicationSnapshot) {
            final medications =
                medicationSnapshot.data ?? const <MedicationRecord>[];
            final isLoadingMedications =
                medicationSnapshot.connectionState == ConnectionState.waiting &&
                !medicationSnapshot.hasData;

            return StreamBuilder<UserProfileRecord?>(
              stream: profileRepository.watchProfile(uid: user.uid),
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data;
                final isLoadingProfile =
                    profileSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !profileSnapshot.hasData;
                final activeMedications = _activeMedications(medications);

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        children: [
                          _buildGreetingCard(context, profile),
                          const SizedBox(height: 14),
                          _buildNextDoseCard(
                            context: context,
                            medications: medications,
                            isLoading: isLoadingMedications,
                          ),
                          const SizedBox(height: 14),
                          _buildSafetyStatusCard(
                            context: context,
                            profile: profile,
                            activeMedications: activeMedications,
                            isLoading: isLoadingProfile,
                          ),
                          const SizedBox(height: 14),
                          _buildQuickStartCard(context),
                          if (_isScanPanelExpanded) ...[
                            const SizedBox(height: 14),
                            _buildScanMedicineCard(context),
                          ],
                          const SizedBox(height: 14),
                          _buildTodayMedicationsCard(
                            context: context,
                            activeMedications: activeMedications,
                          ),
                          const SizedBox(height: 18),
                          _buildSectionTitle(context, 'Tools'),
                          const SizedBox(height: 12),
                          _buildActionGrid(context),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HomeDose {
  const _HomeDose({
    required this.medication,
    required this.scheduledAt,
    required this.displayAt,
    required this.key,
    required this.isSnoozed,
  });

  final MedicationRecord medication;
  final DateTime scheduledAt;
  final DateTime displayAt;
  final String key;
  final bool isSnoozed;
}

class _TileTooltipButton extends StatelessWidget {
  const _TileTooltipButton({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 4),
      preferBelow: false,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.info_outline,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _HomeActionItem {
  const _HomeActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String tooltip;
  final Future<void> Function() onTap;
}
