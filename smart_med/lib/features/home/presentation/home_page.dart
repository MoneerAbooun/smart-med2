import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/alternative_drug/alternative_drug.dart';
import 'package:smart_med/features/interactions/interactions.dart';
import 'package:smart_med/features/medications/medications.dart';
import 'package:smart_med/features/medicine_search/medicine_search.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _cameraPermissionPromptHandledKey =
      'home_camera_permission_prompt_handled';

  final ImagePicker _picker = ImagePicker();

  bool isCameraOpened = false;
  bool isCapturing = false;
  bool _showCameraPermissionPrompt = false;

  CameraController? controller;
  Future<void>? initializeControllerFuture;
  XFile? selectedImage;

  @override
  void initState() {
    super.initState();
    _loadCameraPermissionPromptDecision();
  }

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

  String _cameraPermissionPromptPreferenceKey() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null || userId.isEmpty) {
      return _cameraPermissionPromptHandledKey;
    }

    return '${_cameraPermissionPromptHandledKey}_$userId';
  }

  Future<void> _loadCameraPermissionPromptDecision() async {
    final prefs = await SharedPreferences.getInstance();
    final hasHandledPrompt =
        prefs.getBool(_cameraPermissionPromptPreferenceKey()) ?? false;

    if (!mounted || hasHandledPrompt) {
      return;
    }

    setState(() {
      _showCameraPermissionPrompt = true;
    });
  }

  Future<void> _markCameraPermissionPromptHandled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cameraPermissionPromptPreferenceKey(), true);
  }

  Future<void> _dismissCameraPermissionPrompt() async {
    await _markCameraPermissionPromptHandled();

    if (!mounted) {
      return;
    }

    setState(() {
      _showCameraPermissionPrompt = false;
    });
  }

  Future<void> _handleAllowCameraPrompt() async {
    await _dismissCameraPermissionPrompt();
    await openCamera();
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

  String _displayName() {
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
        icon: Icons.add_box_outlined,
        title: 'Quick Add Med',
        subtitle: 'Save and set reminders',
        tooltip:
            'Add a medication to your list and schedule reminder times so Smart Med can notify you later.',
        onTap: _openAddMedication,
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
        title: 'Find Substitute Medicines',
        subtitle: 'Explore similar options',
        tooltip:
            'Search for possible substitute medicines you can discuss with a doctor or pharmacist.',
        onTap: _openAlternativeDrugSearch,
      ),
    ];
  }

  Widget _buildHeroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
      child: Row(
        children: [
          AppIconBadge(
            icon: Icons.health_and_safety_outlined,
            accentColor: colorScheme.onPrimary,
            size: 58,
            iconSize: 32,
            borderRadius: 18,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${_displayName()}',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your medications with reminders, interaction checks, and quick medicine lookup tools.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.92),
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

  Widget _buildCameraPermissionOverlay(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).shadowColor.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconBadge(
                      icon: Icons.photo_camera_outlined,
                      accentColor: colorScheme.onPrimaryContainer,
                      size: 56,
                      iconSize: 30,
                      borderRadius: 18,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Smart Med would like camera access',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Why? So you can scan medicine bottles instantly.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _dismissCameraPermissionPrompt,
                            child: const Text("I'll Skip"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _handleAllowCameraPrompt,
                            child: const Text('Allow Camera'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Scaffold(
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
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    children: [
                      _buildHeroCard(context),

                      const SizedBox(height: 16),

                      _buildScanMedicineCard(context),

                      const SizedBox(height: 18),

                      _buildSectionTitle(context, 'Quick Actions'),

                      const SizedBox(height: 12),

                      _buildActionGrid(context),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showCameraPermissionPrompt)
            _buildCameraPermissionOverlay(context),
        ],
      ),
    );
  }
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
