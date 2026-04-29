import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_lookup_repository.dart';
import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';

enum MedicineSearchMode { none, name, image }

class MedicineSearchPage extends StatefulWidget {
  const MedicineSearchPage({super.key, this.initialImage});

  final XFile? initialImage;

  @override
  State<MedicineSearchPage> createState() => _MedicineSearchPageState();
}

class _MedicineSearchPageState extends State<MedicineSearchPage> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final MedicineLookupRepository _repository = medicineLookupRepository;

  bool _isSearching = false;
  String? _errorMessage;
  MedicineLookupResult? _result;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  MedicineSearchMode _selectedMode = MedicineSearchMode.none;
  bool _isCameraOpened = false;
  bool _isCapturing = false;
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  String? _expandedSectionId;

  @override
  void initState() {
    super.initState();

    _selectedImage = widget.initialImage;

    if (_selectedImage != null) {
      _selectedMode = MedicineSearchMode.image;
      _loadSelectedImageBytes();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedImageBytes() async {
    final image = _selectedImage;
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted || _selectedImage != image) return;

    setState(() {
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _openInlineCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      await _cameraController?.dispose();

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _initializeCameraFuture = _cameraController!.initialize();
      await _initializeCameraFuture;

      if (!mounted) return;

      setState(() {
        _isCameraOpened = true;
        _selectedImage = null;
        _selectedImageBytes = null;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to open camera: $e';
      });
    }
  }

  Future<void> _captureInlineImage() async {
    final controller = _cameraController;

    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (controller.value.isTakingPicture || _isCapturing) return;

    try {
      setState(() {
        _isCapturing = true;
      });

      await _initializeCameraFuture;

      final XFile image = await controller.takePicture();
      final Uint8List bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
        _isCameraOpened = false;
        _isCapturing = false;
        _errorMessage = null;
      });

      await Future.delayed(const Duration(milliseconds: 200));

      await controller.dispose();
      if (_cameraController == controller) {
        _cameraController = null;
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _errorMessage = 'Failed to capture image: $e';
      });
    }
  }

  Future<void> _closeInlineCameraOrClearImage() async {
    await _cameraController?.dispose();
    _cameraController = null;

    if (!mounted) return;

    setState(() {
      _isCameraOpened = false;
      _isCapturing = false;
      _selectedImage = null;
      _selectedImageBytes = null;
      _errorMessage = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
      _errorMessage = null;
    });
  }

  void _applyExample(String value) {
    setState(() {
      _nameController.text = value;
      _errorMessage = null;
    });
  }

  Future<void> _searchByName() async {
    FocusScope.of(context).unfocus();
    await _runSearch(() => _repository.searchByName(_nameController.text));
  }

  Future<void> _searchByImage() async {
    final image = _selectedImage;

    if (image == null) {
      setState(() {
        _errorMessage = 'Choose a medicine image before searching by image.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    await _runSearch(() => _repository.searchByImage(image: image));
  }

  Future<void> _runSearch(
    Future<MedicineLookupResult> Function() loader,
  ) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _expandedSectionId = null;
    });

    try {
      final result = await loader();

      if (!mounted) return;

      setState(() {
        _result = result;
        _isSearching = false;
        _expandedSectionId = null;
      });
    } on MedicineLookupRepositoryException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isSearching = false;
        _expandedSectionId = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isSearching = false;
        _expandedSectionId = null;
      });
    }
  }

  void _selectMode(MedicineSearchMode mode) {
    setState(() {
      _selectedMode = mode;
      _errorMessage = null;
      _expandedSectionId = null;
    });
  }

  void _switchMode() {
    setState(() {
      _selectedMode = _selectedMode == MedicineSearchMode.name
          ? MedicineSearchMode.image
          : MedicineSearchMode.name;
      _errorMessage = null;
      _expandedSectionId = null;
    });
  }

  void _toggleSection(String sectionId) {
    setState(() {
      _expandedSectionId = _expandedSectionId == sectionId ? null : sectionId;
    });
  }

  String _truncateText(String value, {int maxLength = 110}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }

    return '${normalized.substring(0, maxLength).trimRight()}...';
  }

  String _sectionPreview(List<String> items, String emptyMessage) {
    final previewSource = items.isEmpty ? emptyMessage : items.first;
    final preview = _truncateText(previewSource);

    if (items.length <= 1) {
      return preview;
    }

    return '$preview (+${items.length - 1} more)';
  }

  String _sectionCountLabel(List<String> items) {
    if (items.isEmpty) {
      return 'Not available';
    }

    return items.length == 1 ? '1 item' : '${items.length} items';
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

  Widget _buildSearchModeChooser(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            'How do you want to find medicine details?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose one method first. You can switch later.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _selectMode(MedicineSearchMode.name),
              icon: const Icon(Icons.search),
              label: const Text('Search by Name'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _selectMode(MedicineSearchMode.image),
              icon: const Icon(Icons.image_search_outlined),
              label: const Text('Search by Image'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSearchCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find details by medicine name',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Type a brand or generic name.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.search,
            decoration: _inputDecoration(
              context,
              label: 'Medicine name',
              hint: 'Example: ibuprofen',
            ),
            onSubmitted: (_) {
              if (!_isSearching) {
                _searchByName();
              }
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                label: const Text('Ibuprofen'),
                onPressed: _isSearching
                    ? null
                    : () => _applyExample('ibuprofen'),
              ),
              ActionChip(
                label: const Text('Tylenol'),
                onPressed: _isSearching ? null : () => _applyExample('Tylenol'),
              ),
              ActionChip(
                label: const Text('Amoxicillin'),
                onPressed: _isSearching
                    ? null
                    : () => _applyExample('amoxicillin'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSearching ? null : _searchByName,
              icon: _isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isSearching ? 'Searching...' : 'Search by Name'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSearchCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            'Find details by image',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a clear pill, bottle, or package photo. The app reads visible text, then searches the medicine.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 220,
              color: colorScheme.surface,
              child: _selectedImageBytes != null
                  ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                  : _isCameraOpened
                  ? FutureBuilder<void>(
                      future: _initializeCameraFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            _cameraController != null) {
                          return CameraPreview(_cameraController!);
                        }

                        return const Center(child: CircularProgressIndicator());
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 44,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No image selected',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!_isCameraOpened && _selectedImageBytes == null)
                  SizedBox(
                    width: 125,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : _openInlineCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),

                if (!_isCameraOpened && _selectedImageBytes == null)
                  SizedBox(
                    width: 125,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),

                if (_isCameraOpened)
                  SizedBox(
                    width: 125,
                    child: ElevatedButton.icon(
                      onPressed: _isCapturing ? null : _captureInlineImage,
                      icon: const Icon(Icons.camera),
                      label: Text(_isCapturing ? 'Wait...' : 'Capture'),
                    ),
                  ),

                if (_isCameraOpened || _selectedImageBytes != null)
                  SizedBox(
                    width: 125,
                    child: OutlinedButton.icon(
                      onPressed: _isSearching
                          ? null
                          : _closeInlineCameraOrClearImage,
                      icon: const Icon(Icons.close),
                      label: const Text('Clear'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_selectedImageBytes != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : _searchByImage,
                icon: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.image_search_outlined),
                label: Text(_isSearching ? 'Searching...' : 'Search by Image'),
              ),
            ),
        ],
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

  Widget _buildListSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> items,
    required String emptyMessage,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayItems = items.isEmpty ? <String>[emptyMessage] : items;
    final isPlaceholder = items.isEmpty;
    final isExpanded = _expandedSectionId == title;
    final canExpand = items.isNotEmpty;
    final preview = _sectionPreview(items, emptyMessage);
    final countLabel = _sectionCountLabel(items);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canExpand ? () => _toggleSection(title) : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(
              alpha: isExpanded ? 0.95 : 0.62,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isExpanded
                  ? colorScheme.primary.withValues(alpha: 0.35)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, size: 20, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            countLabel,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (canExpand) ...[
                          const SizedBox(height: 6),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: displayItems
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: isPlaceholder
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: isPlaceholder
                                                ? colorScheme.onSurfaceVariant
                                                : null,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  crossFadeState: canExpand && isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                  sizeCurve: Curves.easeInOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, MedicineLookupResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedDifferentFromQuery =
        result.query.trim().isNotEmpty &&
        result.medicineName.trim().toLowerCase() !=
            result.query.trim().toLowerCase();

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
            result.medicineName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if ((result.genericName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Generic name: ${result.genericName}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if (resolvedDifferentFromQuery) ...[
            const SizedBox(height: 6),
            Text(
              'Searched as: ${result.query}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Tap a section to show more details one by one.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (result.isImageSearch &&
              (result.identificationReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Image search note: ${result.identificationReason}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildListSection(
            context,
            icon: Icons.local_offer_outlined,
            title: 'Brand names',
            items: result.brandNames,
            emptyMessage: 'No brand names were found in the public data.',
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.science_outlined,
            title: 'Active ingredients',
            items: result.activeIngredients,
            emptyMessage:
                'No active ingredients were found in the public data.',
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.info_outline,
            title: 'Used for',
            items: result.usedFor,
            emptyMessage: 'No public label section for uses was found.',
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.straighten_outlined,
            title: 'Dose',
            items: result.dose,
            emptyMessage: 'No public dose section was found.',
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.warning_amber_rounded,
            title: 'Warnings',
            items: result.warnings,
            emptyMessage: 'No public warnings section was found.',
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.sick_outlined,
            title: 'Side effects',
            items: result.sideEffects,
            emptyMessage: 'No public side-effects section was found.',
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Storage',
            items: result.storage,
            emptyMessage: 'No public storage guidance was found.',
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.gpp_maybe_outlined,
            title: 'Disclaimer',
            items: result.disclaimer,
            emptyMessage:
                'Use a clinician or pharmacist for personal medical advice.',
          ),
        ],
      ),
    );
  }

  Widget _buildResultState(BuildContext context) {
    if (_errorMessage != null) {
      return _buildStateCard(
        context,
        icon: Icons.error_outline,
        title: 'Search failed',
        message: _errorMessage!,
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
      title: 'Ready to find details',
      message:
          'Choose a search method, then search for a medicine to see the details here.',
    );
  }

  Widget _buildSelectedSearchCard(BuildContext context) {
    switch (_selectedMode) {
      case MedicineSearchMode.name:
        return _buildNameSearchCard(context);
      case MedicineSearchMode.image:
        return _buildImageSearchCard(context);
      case MedicineSearchMode.none:
        return _buildSearchModeChooser(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedMode = _selectedMode != MedicineSearchMode.none;

    return Scaffold(
      appBar: AppBar(title: const Text('Find Medicine Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildSelectedSearchCard(context),
                ),

                if (hasSelectedMode) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : _switchMode,
                      icon: Icon(
                        _selectedMode == MedicineSearchMode.name
                            ? Icons.image_search_outlined
                            : Icons.search,
                      ),
                      label: Text(
                        _selectedMode == MedicineSearchMode.name
                            ? 'Use Image Search'
                            : 'Use Name Search',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

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
