import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_lookup_repository.dart';
import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';

enum AlternativeSearchMode { none, name, image }

class AlternativeDrugSearchPage extends StatefulWidget {
  const AlternativeDrugSearchPage({super.key});

  @override
  State<AlternativeDrugSearchPage> createState() =>
      _AlternativeDrugSearchPageState();
}

class _AlternativeDrugSearchPageState extends State<AlternativeDrugSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final MedicineLookupRepository _repository = medicineLookupRepository;

  bool _isLoading = false;
  String? _errorMessage;
  MedicineLookupResult? _result;

  AlternativeSearchMode _selectedMode = AlternativeSearchMode.none;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  bool _isCameraOpened = false;
  bool _isCapturing = false;
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;

  @override
  void dispose() {
    _controller.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _selectMode(AlternativeSearchMode mode) {
    setState(() {
      _selectedMode = mode;
      _errorMessage = null;
    });
  }

  void _switchMode() {
    setState(() {
      _selectedMode = _selectedMode == AlternativeSearchMode.name
          ? AlternativeSearchMode.image
          : AlternativeSearchMode.name;
      _errorMessage = null;
    });
  }

  Future<void> _searchAlternativesByName() async {
    FocusScope.of(context).unfocus();

    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a medicine name.';
      });
      return;
    }

    await _runSearch(() => _repository.searchByName(query));
  }

  Future<void> _searchAlternativesByImage() async {
    final image = _selectedImage;

    if (image == null) {
      setState(() {
        _errorMessage = 'Choose a medicine image before searching.';
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
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await loader();

      if (!mounted) return;

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } on MedicineLookupRepositoryException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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

      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();

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

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
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

  Future<void> _clearImageOrCamera() async {
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

  void _applyExample(String value) {
    _controller.text = value;
    _searchAlternativesByName();
  }

  Widget _buildModeChooser(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find substitute medicines',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how you want to search for substitute medicines.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _selectMode(AlternativeSearchMode.name),
              icon: const Icon(Icons.search),
              label: const Text('Search by Name'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _selectMode(AlternativeSearchMode.image),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find substitutes by name',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a medicine name to find possible related substitute medicines.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Medicine name',
              hintText: 'Example: ibuprofen',
              prefixIcon: const Icon(Icons.medication_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            onSubmitted: (_) {
              if (!_isLoading) _searchAlternativesByName();
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                label: const Text('Ibuprofen'),
                onPressed: _isLoading ? null : () => _applyExample('ibuprofen'),
              ),
              ActionChip(
                label: const Text('Tylenol'),
                onPressed: _isLoading ? null : () => _applyExample('Tylenol'),
              ),
              ActionChip(
                label: const Text('Amoxicillin'),
                onPressed: _isLoading
                    ? null
                    : () => _applyExample('amoxicillin'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _searchAlternativesByName,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.find_replace_outlined),
              label: Text(_isLoading ? 'Searching...' : 'Find Substitutes'),
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
            'Find substitutes by image',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Take or choose a medicine image. The app reads the medicine, then searches for substitute options.',
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
                          AppIconBadge(
                            icon: Icons.add_photo_alternate_outlined,
                            accentColor: colorScheme.onSurfaceVariant,
                            size: 54,
                            iconSize: 24,
                            borderRadius: 18,
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
                      onPressed: _isLoading ? null : _openInlineCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                if (!_isCameraOpened && _selectedImageBytes == null)
                  SizedBox(
                    width: 125,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickImage,
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
                      onPressed: _isLoading ? null : _clearImageOrCamera,
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
                onPressed: _isLoading ? null : _searchAlternativesByImage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.image_search_outlined),
                label: Text(_isLoading ? 'Searching...' : 'Search by Image'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedSearchCard(BuildContext context) {
    switch (_selectedMode) {
      case AlternativeSearchMode.name:
        return _buildNameSearchCard(context);
      case AlternativeSearchMode.image:
        return _buildImageSearchCard(context);
      case AlternativeSearchMode.none:
        return _buildModeChooser(context);
    }
  }

  Widget _buildResultCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_errorMessage != null) {
      return _buildInfoCard(
        context,
        icon: Icons.error_outline,
        title: 'Search failed',
        message: _errorMessage!,
        accentColor: colorScheme.error,
      );
    }

    final result = _result;
    if (result == null) {
      return _buildInfoCard(
        context,
        icon: Icons.find_replace_outlined,
        title: 'No search yet',
        message:
            'Search a medicine to show possible substitute medicines here.',
      );
    }

    if (result.alternatives.isEmpty) {
      return _buildInfoCard(
        context,
        icon: Icons.info_outline,
        title: 'No substitute medicines found',
        message:
            'No related alternative medicines were found in the public data checked for ${result.medicineName}.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Substitutes for ${result.medicineName}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if ((result.genericName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Generic name: ${result.genericName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...result.alternatives.map(
            (alternative) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.medication_liquid_outlined,
                    size: 42,
                    iconSize: 20,
                    borderRadius: 14,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      alternative.displayLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Important: alternatives are informational only. Ask a doctor or pharmacist before replacing any medication.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    Color? accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = accentColor ?? colorScheme.primary;

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
            accentColor: color,
            size: 44,
            iconSize: 22,
            borderRadius: 14,
          ),
          const SizedBox(width: 12),
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
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedMode = _selectedMode != AlternativeSearchMode.none;

    return Scaffold(
      appBar: AppBar(title: const Text('Find Substitute Medicines')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      onPressed: _isLoading ? null : _switchMode,
                      icon: Icon(
                        _selectedMode == AlternativeSearchMode.name
                            ? Icons.image_search_outlined
                            : Icons.search,
                      ),
                      label: Text(
                        _selectedMode == AlternativeSearchMode.name
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
                  child: _buildResultCard(context),
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
