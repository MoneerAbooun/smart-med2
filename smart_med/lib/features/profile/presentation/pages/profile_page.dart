import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/core/firebase/image_storage_repository.dart';
import 'package:smart_med/features/auth/data/repositories/auth_repository.dart';
import 'package:smart_med/features/auth/data/repositories/auth_user_flow_repository.dart';
import 'package:smart_med/features/medications/presentation/pages/add_medication_page.dart';
import 'package:smart_med/features/medications/presentation/pages/medication_list_page.dart';
import 'package:smart_med/features/profile/data/repositories/profile_repository.dart';
import 'package:smart_med/features/profile/domain/models/user_profile_record.dart';

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
      nextDiseaseLoadError = 'Unable to load the disease list';
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
      nextMedicineLoadError = 'Unable to load the medicine list';
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

  String _diseaseHintText() {
    if (!isEditing) {
      return "Enable edit mode to add diseases";
    }
    if (isLoadingSelectorData) {
      return "Loading diseases...";
    }
    if (diseaseLoadError != null) {
      return diseaseLoadError!;
    }
    if (availableDiseases.isEmpty) {
      return "No diseases available";
    }
    return "Select a disease";
  }

  String _allergyHintText() {
    if (!isEditing) {
      return "Enable edit mode to add allergies";
    }
    if (isLoadingSelectorData) {
      return "Loading medicines...";
    }
    if (medicineLoadError != null) {
      return medicineLoadError!;
    }
    if (availableMedicines.isEmpty) {
      return "No medicines available";
    }
    return "Select a medicine";
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e, 'Failed to load profile'))),
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

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    if (!isEditing) {
      showMessage('Enable edit mode to change the profile image');
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
      showMessage('This disease is already added');
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
      showMessage('This allergy is already added');
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
    final messenger = ScaffoldMessenger.of(context);

    try {
      FocusScope.of(context).unfocus();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMessage('Please sign in again');
        return;
      }

      final username = nameController.text.trim();
      final ageText = ageController.text.trim();

      if (username.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Please enter your name"),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (ageText.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Please enter your age"),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final age = int.tryParse(ageText);
      if (age == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Age must be a valid number"),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (age < 1 || age > 120) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Please enter a valid age"),
            duration: Duration(seconds: 2),
          ),
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

      messenger.showSnackBar(
        const SnackBar(
          content: Text("Profile data saved successfully"),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(_errorMessage(e, "Failed to save profile data")),
          duration: Duration(seconds: 2),
        ),
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
            title: "Chronic diseases",
            subtitle:
                "Track long-term conditions that can affect medication safety.",
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedDisease,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: _diseaseHintText(),
              prefixIcon: const Icon(Icons.medical_information_outlined),
            ),
            items: _canSelectDiseaseOptions
                ? availableDiseases.map((disease) {
                    return DropdownMenuItem<String>(
                      value: disease,
                      child: Text(
                        disease,
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
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _retrySelectorDataLoad,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading diseases'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (isEditing && selectedDisease != null)
            ElevatedButton.icon(
              onPressed: addDisease,
              icon: const Icon(Icons.add),
              label: const Text("Add Disease"),
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
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "No chronic diseases added",
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(chronicDiseases.length, (index) {
                      final disease = chronicDiseases[index];

                      return Chip(
                        label: Text(disease),
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
            title: "Drug allergies",
            subtitle:
                "Add medicines that may cause an allergic reaction for this patient.",
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedAllergy,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: _allergyHintText(),
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
                        displayText,
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
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _retrySelectorDataLoad,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading medicines'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (isEditing && selectedAllergy != null)
            ElevatedButton.icon(
              onPressed: addAllergy,
              icon: const Icon(Icons.add),
              label: const Text("Add Allergy"),
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
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "No drug allergies added",
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(drugAllergies.length, (index) {
                      final allergy = drugAllergies[index];

                      return Chip(
                        label: Text(allergy),
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
            title: "Patient Medical Info",
            subtitle:
                "These details help later in calculating a safer medication dose.",
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: biologicalSex,
            decoration: buildMedicalFieldDecoration(
              "Biological Sex",
              Icons.wc_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
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
                  label: "Weight (kg)",
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMedicalNumberField(
                  controller: heightController,
                  label: "Height (cm)",
                  icon: Icons.height_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const SizedBox(height: 12),

          Text(
            "Blood Pressure",
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            "SYS = upper number, DIA = lower number",
            softWrap: true,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 10),

          buildMedicalNumberField(
            controller: systolicPressureController,
            label: "SYS / Upper",
            icon: Icons.favorite_border,
            allowDecimal: false,
          ),

          const SizedBox(height: 12),

          buildMedicalNumberField(
            controller: diastolicPressureController,
            label: "DIA / Lower",
            icon: Icons.favorite,
            allowDecimal: false,
          ),

          const SizedBox(height: 12),

          Text(
            "Blood Glucose",
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),
          buildMedicalNumberField(
            controller: bloodGlucoseController,
            label: "Blood Glucose",
            icon: Icons.bloodtype_outlined,
          ),
          if (biologicalSex == 'female') ...[
            const SizedBox(height: 8),
            buildSwitchTile(
              title: "Pregnant",
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
              title: "Breastfeeding",
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
      missingFields.add('Age');
    }
    if (drugAllergies.isEmpty) {
      missingFields.add('Allergies');
    }
    if (chronicDiseases.isEmpty) {
      missingFields.add('Conditions');
    }
    if (weightController.text.trim().isEmpty) {
      missingFields.add('Weight');
    }
    if (systolicPressureController.text.trim().isEmpty ||
        diastolicPressureController.text.trim().isEmpty) {
      missingFields.add('Blood Pressure');
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
    final missingFields = _missingSafetyReadinessFields();
    final labels = <String>[
      'Age',
      'Allergies',
      'Conditions',
      'Weight',
      'Blood Pressure',
      if (biologicalSex == 'female') 'Pregnancy Status',
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
            title: 'Safety Profile Readiness',
            subtitle: missingFields.isEmpty
                ? 'Your profile is complete enough to support stronger medication warnings.'
                : 'Missing profile details may reduce warning accuracy. Smart Med uses this profile to personalize medication cautions and safer-use advice.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels
                .map(
                  (label) => _buildReadinessChip(
                    context,
                    label,
                    missingFields.contains(label),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profileImageProvider = _currentProfileImageProvider();

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          title: const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              "Profile",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 8),
              child: IconButton(
                icon: const Icon(Icons.medication_outlined, size: 28),
                tooltip: 'Medications',
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
                                                  ? 'Change photo'
                                                  : 'Add photo',
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
                                              decoration: const InputDecoration(
                                                hintText: "User Name",
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
                                                  "Age: ",
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
                                    label: const Text("Add Medication"),
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
                                        : const Text("Save"),
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
