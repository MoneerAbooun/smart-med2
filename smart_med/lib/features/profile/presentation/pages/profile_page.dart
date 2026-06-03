import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/core/firebase/image_storage_repository.dart';
import 'package:smart_med/features/auth/data/repositories/auth_repository.dart';
import 'package:smart_med/features/auth/data/repositories/auth_user_flow_repository.dart';
import 'package:smart_med/features/medications/data/repositories/medication_dose_history_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_dose_history_record.dart';
import 'package:smart_med/features/medications/presentation/pages/add_medication_page.dart';
import 'package:smart_med/features/medications/presentation/pages/medication_list_page.dart';
import 'package:smart_med/features/profile/data/repositories/profile_repository.dart';
import 'package:smart_med/features/profile/domain/models/user_profile_record.dart';
import 'package:smart_med/core/widgets/app_snack_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController systolicPressureController =
      TextEditingController();
  final TextEditingController diastolicPressureController =
      TextEditingController();
  final TextEditingController bloodGlucoseController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final ProfileRepository _profileRepository = profileRepository;
  final ImageStorageRepository _imageStorageRepository = imageStorageRepository;
  final MedicationDoseHistoryRepository _doseHistoryRepository =
      medicationDoseHistoryRepository;

  bool isLoadingProfile = true;
  bool isSavingProfile = false;
  bool isEditing = false;

  List<String> chronicDiseases = [];
  List<String> drugAllergies = [];

  List<String> availableDiseases = [];
  List<Map<String, String>> availableMedicines = [];
  bool isLoadingSelectorData = true;
  String? diseaseLoadError;
  String? medicineLoadError;
  String? selectedDisease;
  String? selectedAllergy;

  String biologicalSex = 'male';
  bool isPregnant = false;
  bool isBreastfeeding = false;
  String? _profilePhotoUrl;
  XFile? _selectedProfileImage;
  Uint8List? _selectedProfileImageBytes;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadProfile();
  }

  Future<void> _loadData() async {
    List<String> loadedDiseases = [];
    List<Map<String, String>> loadedMedicines = [];
    String? nextDiseaseLoadError;
    String? nextMedicineLoadError;

    try {
      final diseasesString = await rootBundle.loadString(
        'assets/data/diseases.json',
      );
      final diseasesList = json.decode(diseasesString) as List<dynamic>;
      loadedDiseases = diseasesList.map((e) => e.toString()).toList();
    } catch (e) {
      nextDiseaseLoadError = 'profile.conditions.loadError';
      debugPrint('Error loading diseases: $e');
    }

    try {
      final medicinesString = await rootBundle.loadString(
        'assets/data/local_medicines.json',
      );
      final medicinesList = json.decode(medicinesString) as List<dynamic>;
      loadedMedicines = medicinesList
          .map((e) => Map<String, String>.from(e))
          .toList();
    } catch (e) {
      nextMedicineLoadError = 'profile.allergies.loadError';
      debugPrint('Error loading medicines: $e');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      availableDiseases = loadedDiseases;
      availableMedicines = loadedMedicines;
      diseaseLoadError = nextDiseaseLoadError;
      medicineLoadError = nextMedicineLoadError;
      isLoadingSelectorData = false;
    });
  }

  String _diseaseHintText(BuildContext context) {
    final l10n = context.l10n;

    if (!isEditing) {
      return l10n.text('profile.conditions.hint.view');
    }
    if (isLoadingSelectorData) {
      return l10n.text('profile.conditions.hint.loading');
    }
    if (diseaseLoadError != null) {
      return l10n.text(diseaseLoadError!);
    }
    if (availableDiseases.isEmpty) {
      return l10n.text('profile.conditions.hint.empty');
    }
    return l10n.text('profile.conditions.hint.select');
  }

  String _allergyHintText(BuildContext context) {
    final l10n = context.l10n;

    if (!isEditing) {
      return l10n.text('profile.allergies.hint.view');
    }
    if (isLoadingSelectorData) {
      return l10n.text('profile.allergies.hint.loading');
    }
    if (medicineLoadError != null) {
      return l10n.text(medicineLoadError!);
    }
    if (availableMedicines.isEmpty) {
      return l10n.text('profile.allergies.hint.empty');
    }
    return l10n.text('profile.allergies.hint.select');
  }

  bool get _canSelectDiseaseOptions =>
      isEditing &&
      !isLoadingSelectorData &&
      diseaseLoadError == null &&
      availableDiseases.isNotEmpty;

  bool get _canSelectMedicineOptions =>
      isEditing &&
      !isLoadingSelectorData &&
      medicineLoadError == null &&
      availableMedicines.isNotEmpty;

  Future<void> _retrySelectorDataLoad() async {
    if (!mounted) {
      return;
    }

    setState(() {
      isLoadingSelectorData = true;
      diseaseLoadError = null;
      medicineLoadError = null;
    });

    await _loadData();
  }

  String _valueToText(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  double? _parseDoubleOrNull(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  int? _parseIntOrNull(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  void _applyProfile(UserProfileRecord profile) {
    final data = profile.toLegacyProfileMap();
    final medicalInfo = Map<String, dynamic>.from(data['medicalInfo'] ?? {});

    nameController.text = data['username'] ?? '';
    ageController.text = data['age']?.toString() ?? '';
    chronicDiseases = List<String>.from(data['chronicDiseases'] ?? []);
    drugAllergies = List<String>.from(data['drugAllergies'] ?? []);
    weightController.text = _valueToText(medicalInfo['weightKg']);
    heightController.text = _valueToText(medicalInfo['heightCm']);
    systolicPressureController.text = _valueToText(
      medicalInfo['systolicPressure'],
    );
    diastolicPressureController.text = _valueToText(
      medicalInfo['diastolicPressure'],
    );
    bloodGlucoseController.text = _valueToText(medicalInfo['bloodGlucose']);

    final savedSex = (medicalInfo['biologicalSex'] ?? 'male')
        .toString()
        .toLowerCase();

    biologicalSex = savedSex == 'female' ? 'female' : 'male';
    isPregnant = biologicalSex == 'female' && medicalInfo['isPregnant'] == true;
    isBreastfeeding =
        biologicalSex == 'female' && medicalInfo['isBreastfeeding'] == true;
    _profilePhotoUrl = profile.photoUrl;
    _selectedProfileImage = null;
    _selectedProfileImageBytes = null;
  }

  ImageProvider<Object>? _currentProfileImageProvider() {
    if (_selectedProfileImageBytes != null) {
      return MemoryImage(_selectedProfileImageBytes!);
    }

    final photoUrl = _profilePhotoUrl?.trim();
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }

    return null;
  }

  String _errorMessage(Object error, String fallbackMessage) {
    if (error is ProfileRepositoryException) {
      return error.message;
    }

    if (error is AuthFlowException) {
      return error.message;
    }

    return fallbackMessage;
  }

  Future<void> _loadProfile({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        isLoadingProfile = true;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          isLoadingProfile = false;
        });
        return;
      }

      final profile = await authUserFlowRepository.ensureProfileForUser(
        user,
        fallbackEmail: user.email,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _applyProfile(profile);
        isLoadingProfile = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingProfile = false;
        });
        AppSnackBar.show(
          context,
          _errorMessage(e, context.l10n.text('profile.loadError')),
          type: AppSnackBarType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    weightController.dispose();
    heightController.dispose();
    systolicPressureController.dispose();
    diastolicPressureController.dispose();
    bloodGlucoseController.dispose();
    super.dispose();
  }

  void toggleEditMode() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  void showMessage(String message, {AppSnackBarType? type}) {
    AppSnackBar.show(context, message, type: type);
  }

  Future<void> _pickProfileImage() async {
    if (!isEditing) {
      showMessage(context.l10n.text('profile.photo.editRequired'));
      return;
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedProfileImage = image;
      _selectedProfileImageBytes = bytes;
    });
  }

  void addDisease() {
    if (selectedDisease == null || selectedDisease!.isEmpty) return;

    final alreadyExists = chronicDiseases.any(
      (item) => item.toLowerCase() == selectedDisease!.toLowerCase(),
    );

    if (alreadyExists) {
      showMessage(context.l10n.text('profile.condition.duplicate'));
      return;
    }

    setState(() {
      chronicDiseases.add(selectedDisease!);
      selectedDisease = null;
    });
  }

  void removeDisease(int index) {
    if (!isEditing) return;

    setState(() {
      chronicDiseases.removeAt(index);
    });
  }

  void addAllergy() {
    if (selectedAllergy == null || selectedAllergy!.isEmpty) return;

    final alreadyExists = drugAllergies.any(
      (item) => item.toLowerCase() == selectedAllergy!.toLowerCase(),
    );

    if (alreadyExists) {
      showMessage(context.l10n.text('profile.allergy.duplicate'));
      return;
    }

    setState(() {
      drugAllergies.add(selectedAllergy!);
      selectedAllergy = null;
    });
  }

  void removeAllergy(int index) {
    if (!isEditing) return;

    setState(() {
      drugAllergies.removeAt(index);
    });
  }

  Future<void> saveProfile() async {
    try {
      FocusScope.of(context).unfocus();
      final l10n = context.l10n;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMessage(l10n.text('profile.signInAgain'));
        return;
      }

      final username = nameController.text.trim();
      final ageText = ageController.text.trim();

      if (username.isEmpty) {
        AppSnackBar.show(
          context,
          l10n.text('profile.validation.nameRequired'),
          type: AppSnackBarType.warning,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      if (ageText.isEmpty) {
        AppSnackBar.show(
          context,
          l10n.text('profile.validation.ageRequired'),
          type: AppSnackBarType.warning,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final age = int.tryParse(ageText);
      if (age == null) {
        AppSnackBar.show(
          context,
          l10n.text('profile.validation.ageNumber'),
          type: AppSnackBarType.warning,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      if (age < 1 || age > 120) {
        AppSnackBar.show(
          context,
          l10n.text('profile.validation.ageRange'),
          type: AppSnackBarType.warning,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final medicalInfo = {
        'biologicalSex': biologicalSex,
        'weightKg': _parseDoubleOrNull(weightController.text),
        'heightCm': _parseDoubleOrNull(heightController.text),
        'systolicPressure': _parseIntOrNull(systolicPressureController.text),
        'diastolicPressure': _parseIntOrNull(diastolicPressureController.text),
        'bloodGlucose': _parseDoubleOrNull(bloodGlucoseController.text),
        'isPregnant': biologicalSex == 'female' ? isPregnant : false,
        'isBreastfeeding': biologicalSex == 'female' ? isBreastfeeding : false,
      };

      setState(() {
        isSavingProfile = true;
      });

      var photoUrl = _profilePhotoUrl;
      if (_selectedProfileImage != null) {
        photoUrl = await _imageStorageRepository.uploadProfileImage(
          uid: user.uid,
          image: _selectedProfileImage!,
        );
      }

      await _profileRepository.updateUserProfile(
        uid: user.uid,
        username: username,
        age: age,
        chronicDiseases: chronicDiseases,
        drugAllergies: drugAllergies,
        medicalInfo: medicalInfo,
        email: user.email,
        photoUrl: photoUrl,
      );
      await authRepository.updateUsername(username: username);

      if (!mounted) return;

      setState(() {
        isEditing = false;
        isLoadingProfile = true;
      });

      await _loadProfile(showLoader: false);

      if (!mounted) return;

      AppSnackBar.show(
        context,
        l10n.text('profile.saved'),
        type: AppSnackBarType.success,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.show(
        context,
        _errorMessage(e, context.l10n.text('profile.saveError')),
        type: AppSnackBarType.error,
        duration: const Duration(seconds: 2),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingProfile = false;
        });
      }
    }
  }

  InputDecoration buildMedicalFieldDecoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon));
  }

  Widget buildMedicalNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool allowDecimal = true,
  }) {
    return TextField(
      controller: controller,
      readOnly: !isEditing,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      decoration: buildMedicalFieldDecoration(label, icon),
    );
  }

  Widget buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  Widget buildSectionHeading({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconBadge(
          icon: icon,
          accentColor: accentColor ?? colorScheme.primary,
          size: 40,
          iconSize: 20,
          borderRadius: 14,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget buildChronicDiseasesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeading(
            icon: Icons.medical_information_outlined,
            title: l10n.text('profile.conditions.title'),
            subtitle: l10n.text('profile.conditions.subtitle'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedDisease,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: _diseaseHintText(context),
              prefixIcon: const Icon(Icons.medical_information_outlined),
            ),
            items: _canSelectDiseaseOptions
                ? availableDiseases.map((disease) {
                    return DropdownMenuItem<String>(
                      value: disease,
                      child: Text(
                        l10n.isolate(disease),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList()
                : [],
            onChanged: _canSelectDiseaseOptions
                ? (value) {
                    setState(() {
                      selectedDisease = value;
                    });
                  }
                : null,
          ),
          if (isEditing && diseaseLoadError != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _retrySelectorDataLoad,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.text('profile.conditions.retry')),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (isEditing && selectedDisease != null)
            ElevatedButton.icon(
              onPressed: addDisease,
              icon: const Icon(Icons.add),
              label: Text(l10n.text('profile.conditions.add')),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: chronicDiseases.isEmpty
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.text('profile.conditions.none'),
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(chronicDiseases.length, (index) {
                      final disease = chronicDiseases[index];

                      return Chip(
                        label: Text(l10n.isolate(disease)),
                        deleteIcon: isEditing
                            ? const Icon(Icons.close, size: 18)
                            : null,
                        onDeleted: isEditing
                            ? () => removeDisease(index)
                            : null,
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildDrugAllergiesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeading(
            icon: Icons.warning_amber_rounded,
            title: l10n.text('profile.allergies.title'),
            subtitle: l10n.text('profile.allergies.subtitle'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedAllergy,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: _allergyHintText(context),
              prefixIcon: const Icon(Icons.warning_amber_rounded),
            ),
            items: _canSelectMedicineOptions
                ? availableMedicines.map((medicine) {
                    final brandName = medicine['brandName'] ?? '';
                    final genericName = medicine['genericName'] ?? '';
                    final displayText = genericName.isNotEmpty
                        ? '$brandName ($genericName)'
                        : brandName;
                    return DropdownMenuItem<String>(
                      value: brandName,
                      child: Text(
                        l10n.isolate(displayText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList()
                : [],
            onChanged: _canSelectMedicineOptions
                ? (value) {
                    setState(() {
                      selectedAllergy = value;
                    });
                  }
                : null,
          ),
          if (isEditing && medicineLoadError != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _retrySelectorDataLoad,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.text('profile.allergies.retry')),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (isEditing && selectedAllergy != null)
            ElevatedButton.icon(
              onPressed: addAllergy,
              icon: const Icon(Icons.add),
              label: Text(l10n.text('profile.allergies.add')),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: drugAllergies.isEmpty
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.text('profile.allergies.none'),
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(drugAllergies.length, (index) {
                      final allergy = drugAllergies[index];

                      return Chip(
                        label: Text(l10n.isolate(allergy)),
                        deleteIcon: isEditing
                            ? const Icon(Icons.close, size: 18)
                            : null,
                        onDeleted: isEditing
                            ? () => removeAllergy(index)
                            : null,
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildMedicalInfoCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeading(
            icon: Icons.monitor_heart_outlined,
            title: l10n.text('profile.health.title'),
            subtitle: l10n.text('profile.health.subtitle'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: biologicalSex,
            decoration: buildMedicalFieldDecoration(
              l10n.text('profile.health.biologicalSex'),
              Icons.wc_outlined,
            ),
            items: [
              DropdownMenuItem(
                value: 'male',
                child: Text(l10n.text('profile.health.male')),
              ),
              DropdownMenuItem(
                value: 'female',
                child: Text(l10n.text('profile.health.female')),
              ),
            ],
            onChanged: !isEditing
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      biologicalSex = value;

                      if (biologicalSex != 'female') {
                        isPregnant = false;
                        isBreastfeeding = false;
                      }
                    });
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: buildMedicalNumberField(
                  controller: weightController,
                  label: l10n.text('profile.health.weight'),
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMedicalNumberField(
                  controller: heightController,
                  label: l10n.text('profile.health.height'),
                  icon: Icons.height_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const SizedBox(height: 12),

          Text(
            l10n.text('profile.health.bloodPressure'),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            l10n.text('profile.health.bloodPressureHelp'),
            softWrap: true,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 10),

          buildMedicalNumberField(
            controller: systolicPressureController,
            label: l10n.text('profile.health.systolic'),
            icon: Icons.favorite_border,
            allowDecimal: false,
          ),

          const SizedBox(height: 12),

          buildMedicalNumberField(
            controller: diastolicPressureController,
            label: l10n.text('profile.health.diastolic'),
            icon: Icons.favorite,
            allowDecimal: false,
          ),

          const SizedBox(height: 12),

          Text(
            l10n.text('profile.health.bloodGlucose'),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),
          buildMedicalNumberField(
            controller: bloodGlucoseController,
            label: l10n.text('profile.health.bloodGlucose'),
            icon: Icons.bloodtype_outlined,
          ),
          if (biologicalSex == 'female') ...[
            const SizedBox(height: 8),
            buildSwitchTile(
              title: l10n.text('profile.health.pregnant'),
              value: isPregnant,
              onChanged: !isEditing
                  ? null
                  : (value) {
                      setState(() {
                        isPregnant = value;
                      });
                    },
            ),
            buildSwitchTile(
              title: l10n.text('profile.health.breastfeeding'),
              value: isBreastfeeding,
              onChanged: !isEditing
                  ? null
                  : (value) {
                      setState(() {
                        isBreastfeeding = value;
                      });
                    },
            ),
          ],
        ],
      ),
    );
  }

  List<String> _missingSafetyReadinessFields() {
    final missingFields = <String>[];

    if (ageController.text.trim().isEmpty) {
      missingFields.add('profile.readiness.age');
    }
    if (drugAllergies.isEmpty) {
      missingFields.add('profile.readiness.allergies');
    }
    if (chronicDiseases.isEmpty) {
      missingFields.add('profile.readiness.conditions');
    }
    if (weightController.text.trim().isEmpty) {
      missingFields.add('profile.readiness.weight');
    }
    if (systolicPressureController.text.trim().isEmpty ||
        diastolicPressureController.text.trim().isEmpty) {
      missingFields.add('profile.readiness.bloodPressure');
    }
    return missingFields;
  }

  Widget _buildReadinessChip(BuildContext context, String label, bool missing) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: missing
            ? colorScheme.secondaryContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: missing
              ? colorScheme.onSecondaryContainer
              : colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildSafetyReadinessCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final missingFields = _missingSafetyReadinessFields();
    final labels = <String>[
      'profile.readiness.age',
      'profile.readiness.allergies',
      'profile.readiness.conditions',
      'profile.readiness.weight',
      'profile.readiness.bloodPressure',
      if (biologicalSex == 'female') 'profile.readiness.pregnancyStatus',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeading(
            icon: Icons.verified_user_outlined,
            title: l10n.text('profile.readiness.title'),
            subtitle: missingFields.isEmpty
                ? l10n.text('profile.readiness.complete')
                : l10n.text('profile.readiness.incomplete'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels
                .map(
                  (labelKey) => _buildReadinessChip(
                    context,
                    l10n.text(labelKey),
                    missingFields.contains(labelKey),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  String _formatHistoryDateTime(BuildContext context, DateTime value) {
    final localValue = value.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final l10n = context.l10n;

    return l10n.format('profile.history.dateTime', <String, String>{
      'date': l10n.isolate(localizations.formatShortDate(localValue)),
      'time': l10n.isolate(TimeOfDay.fromDateTime(localValue).format(context)),
    });
  }

  String _historyStatusLabel(
    BuildContext context,
    MedicationDoseHistoryRecord entry,
  ) {
    return context.l10n.text(
      entry.isTaken ? 'profile.history.taken' : 'profile.history.skipped',
    );
  }

  IconData _historyIcon(MedicationDoseHistoryRecord entry) {
    return entry.isTaken ? Icons.check_circle_outline : Icons.cancel_outlined;
  }

  Color _historyAccentColor(
    ColorScheme colorScheme,
    MedicationDoseHistoryRecord entry,
  ) {
    return entry.isTaken ? Colors.green.shade700 : colorScheme.error;
  }

  Widget _buildMedicationHistoryRow(
    BuildContext context,
    MedicationDoseHistoryRecord entry,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final accentColor = _historyAccentColor(colorScheme, entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: _historyIcon(entry),
            accentColor: accentColor,
            size: 40,
            iconSize: 20,
            borderRadius: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isolate(entry.medicationName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.isolate(entry.dosage),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.format('profile.history.scheduled', <String, String>{
                    'time': _formatHistoryDateTime(context, entry.scheduledAt),
                  }),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accentColor.withValues(alpha: 0.18)),
            ),
            child: Text(
              _historyStatusLabel(context, entry),
              style: textTheme.labelMedium?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMedicationHistoryCard(BuildContext context, String uid) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeading(
            icon: Icons.history_outlined,
            title: l10n.text('profile.history.title'),
            subtitle: l10n.text('profile.history.subtitle'),
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<MedicationDoseHistoryRecord>>(
            stream: _doseHistoryRepository.watchRecent(uid: uid, limit: 12),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.text('profile.history.loading'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Text(
                  l10n.text('profile.history.loadError'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                );
              }

              final history =
                  snapshot.data ?? const <MedicationDoseHistoryRecord>[];
              if (history.isEmpty) {
                return Text(
                  l10n.text('profile.history.empty'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              }

              return Column(
                children: history
                    .map((entry) => _buildMedicationHistoryRow(context, entry))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final profileImageProvider = _currentProfileImageProvider();
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          title: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l10n.text('profile.title'),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 10, end: 8),
              child: IconButton(
                icon: const Icon(Icons.medication_outlined, size: 28),
                tooltip: l10n.text('common.medications'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MedicationListPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: Center(
          child: isLoadingProfile
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 25,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 35,
                                          backgroundColor:
                                              colorScheme.secondaryContainer,
                                          backgroundImage: profileImageProvider,
                                          child: profileImageProvider == null
                                              ? Icon(
                                                  Icons.person_outline,
                                                  size: 35,
                                                  color: colorScheme
                                                      .onSecondaryContainer,
                                                )
                                              : null,
                                        ),
                                        if (isEditing) ...[
                                          const SizedBox(height: 8),
                                          TextButton.icon(
                                            onPressed: isSavingProfile
                                                ? null
                                                : _pickProfileImage,
                                            icon: const Icon(
                                              Icons.photo_library_outlined,
                                              size: 18,
                                            ),
                                            label: Text(
                                              (profileImageProvider != null)
                                                  ? l10n.text(
                                                      'profile.photo.change',
                                                    )
                                                  : l10n.text(
                                                      'profile.photo.add',
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                              controller: nameController,
                                              readOnly: !isEditing,
                                              decoration: InputDecoration(
                                                hintText: l10n.text(
                                                  'profile.yourName',
                                                ),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                filled: false,
                                              ),
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Text(
                                                  l10n.text('profile.ageLabel'),
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextField(
                                                    controller: ageController,
                                                    readOnly: !isEditing,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          isDense: true,
                                                          contentPadding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          filled: false,
                                                        ),
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: toggleEditMode,
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 25),

                                buildChronicDiseasesSection(context),
                                const SizedBox(height: 25),

                                buildDrugAllergiesSection(context),
                                const SizedBox(height: 25),

                                buildMedicalInfoCard(context),
                                const SizedBox(height: 25),

                                buildSafetyReadinessCard(context),
                                const SizedBox(height: 25),

                                if (user != null) ...[
                                  buildMedicationHistoryCard(context, user.uid),
                                  const SizedBox(height: 25),
                                ],

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AddMedicationPage(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.add),
                                    label: Text(
                                      l10n.text('common.addMedicine'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 25),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isEditing && !isSavingProfile
                                        ? saveProfile
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      disabledBackgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      disabledForegroundColor:
                                          colorScheme.onSurfaceVariant,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: isSavingProfile
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : Text(
                                            l10n.text('profile.saveProfile'),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
