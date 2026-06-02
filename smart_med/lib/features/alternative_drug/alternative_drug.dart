import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/data/medicine/medicine_name_entry.dart';
import 'package:smart_med/data/medicine/medicine_name_repository.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_lookup_repository.dart';
import 'package:smart_med/features/medicine_search/data/repositories/medicine_search_history_repository.dart';
import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';
import 'package:smart_med/features/medicine_search/presentation/widgets/medicine_name_suggestion_helpers.dart';

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
  final MedicineSearchHistoryRepository _historyRepository =
      medicineSearchHistoryRepository;
  final MedicineNameRepository _medicineNameRepository = medicineNameRepository;

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
  List<String> _recentMedicineSearches = const <String>[];
  List<MedicineNameEntry> _medicineNameEntries = const <MedicineNameEntry>[];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onMedicineNameInputChanged);
    _loadSearchHistory();
    _loadMedicineNameEntries();
  }

  @override
  void dispose() {
    _controller.removeListener(_onMedicineNameInputChanged);
    _controller.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _historyRepository.loadHistory();

    if (!mounted) return;

    setState(() {
      _recentMedicineSearches = history;
    });
  }

  void _onMedicineNameInputChanged() {
    if (!mounted) return;

    setState(() {});
  }

  Future<void> _loadMedicineNameEntries() async {
    try {
      final entries = await _medicineNameRepository.loadEntries();

      if (!mounted) return;

      setState(() {
        _medicineNameEntries = entries;
      });
    } catch (_) {
      // Suggestions are a helper only. Searching still works if the local list fails.
    }
  }

  List<MedicineNameEntry> _filteredMedicineSuggestions() {
    return filterMedicineNameSuggestions(
      _medicineNameEntries,
      _controller.text,
    );
  }

  void _applyMedicineSuggestion(MedicineNameEntry entry) {
    final value = medicineEntrySearchValue(entry);

    setState(() {
      _controller.text = value;
      _controller.selection = TextSelection.collapsed(offset: value.length);
      _errorMessage = null;
    });
  }

  Future<void> _saveMedicineSearch(String value) async {
    final history = await _historyRepository.saveSearch(value);

    if (!mounted) return;

    setState(() {
      _recentMedicineSearches = history;
    });
  }

  void _applyRecentMedicine(String value) {
    setState(() {
      _controller.text = value;
      _errorMessage = null;
    });
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
        _errorMessage = context.l10n.text('alternative.enterName');
      });
      return;
    }

    final result = await _runSearch(() => _repository.searchByName(query));

    if (result != null) {
      await _saveMedicineSearch(query);
    }
  }

  Future<void> _searchAlternativesByImage() async {
    final image = _selectedImage;

    if (image == null) {
      setState(() {
        _errorMessage = context.l10n.text('medicineSearch.choosePhoto');
      });
      return;
    }

    FocusScope.of(context).unfocus();
    await _runSearch(() => _repository.searchByImage(image: image));
  }

  Future<MedicineLookupResult?> _runSearch(
    Future<MedicineLookupResult> Function() loader,
  ) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await loader();

      if (!mounted) return null;

      setState(() {
        _result = result;
        _isLoading = false;
      });

      return result;
    } on MedicineLookupRepositoryException catch (e) {
      if (!mounted) return null;

      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });

      return null;
    } catch (e) {
      if (!mounted) return null;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });

      return null;
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
        _errorMessage = context.l10n.format(
          'home.camera.openError',
          <String, String>{'error': context.l10n.isolate(e.toString())},
        );
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
        _errorMessage = context.l10n.format(
          'home.camera.captureError',
          <String, String>{'error': context.l10n.isolate(e.toString())},
        );
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

  Widget _buildModeChooser(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

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
            l10n.text('alternative.mode.title'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('alternative.mode.subtitle'),
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
              label: Text(l10n.text('common.useName')),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _selectMode(AlternativeSearchMode.image),
              icon: const Icon(Icons.image_search_outlined),
              label: Text(l10n.text('common.usePhoto')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHistoryChips({required bool disabled}) {
    if (_recentMedicineSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text('common.recentSearches'),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _recentMedicineSearches
              .map((medicine) {
                return ActionChip(
                  label: Text(context.l10n.isolate(medicine)),
                  avatar: const Icon(Icons.history, size: 18),
                  onPressed: disabled
                      ? null
                      : () => _applyRecentMedicine(medicine),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildMedicineSuggestionsOrHistory({required bool disabled}) {
    final query = _controller.text.trim();

    if (query.isNotEmpty) {
      return MedicineNameSuggestionsList(
        suggestions: _filteredMedicineSuggestions(),
        onSelected: _applyMedicineSuggestion,
        disabled: disabled,
      );
    }

    return _buildSearchHistoryChips(disabled: disabled);
  }

  Widget _buildNameSearchCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

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
            l10n.text('alternative.name.title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('alternative.name.subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: l10n.text('common.medicineName'),
              hintText: l10n.text('common.exampleIbuprofen'),
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
          _buildMedicineSuggestionsOrHistory(disabled: _isLoading),
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
              label: Text(
                _isLoading
                    ? l10n.text('common.searching')
                    : l10n.text('alternative.name.button'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSearchCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

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
            l10n.text('alternative.image.title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('alternative.image.subtitle'),
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
                            l10n.text('common.noImageSelected'),
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
                      label: Text(l10n.text('common.camera')),
                    ),
                  ),
                if (!_isCameraOpened && _selectedImageBytes == null)
                  SizedBox(
                    width: 125,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(l10n.text('common.gallery')),
                    ),
                  ),
                if (_isCameraOpened)
                  SizedBox(
                    width: 125,
                    child: ElevatedButton.icon(
                      onPressed: _isCapturing ? null : _captureInlineImage,
                      icon: const Icon(Icons.camera),
                      label: Text(
                        _isCapturing
                            ? l10n.text('common.wait')
                            : l10n.text('common.capture'),
                      ),
                    ),
                  ),
                if (_isCameraOpened || _selectedImageBytes != null)
                  SizedBox(
                    width: 125,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _clearImageOrCamera,
                      icon: const Icon(Icons.close),
                      label: Text(l10n.text('common.clear')),
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
                label: Text(
                  _isLoading
                      ? l10n.text('common.searching')
                      : l10n.text('medicineSearch.image.button'),
                ),
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
    final l10n = context.l10n;

    if (_errorMessage != null) {
      return _buildInfoCard(
        context,
        icon: Icons.error_outline,
        title: l10n.text('medicineSearch.error.title'),
        message: _errorMessage!,
        accentColor: colorScheme.error,
      );
    }

    final result = _result;
    if (result == null) {
      return _buildInfoCard(
        context,
        icon: Icons.find_replace_outlined,
        title: l10n.text('alternative.ready.title'),
        message: l10n.text('alternative.ready.message'),
      );
    }

    if (result.alternatives.isEmpty) {
      return _buildInfoCard(
        context,
        icon: Icons.info_outline,
        title: l10n.text('alternative.empty.title'),
        message: l10n.format('alternative.empty.message', <String, String>{
          'medicine': l10n.isolate(result.medicineName),
        }),
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
            l10n.format('alternative.result.title', <String, String>{
              'medicine': l10n.isolate(result.medicineName),
            }),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if ((result.genericName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.format(
                'medicineSearch.details.genericName',
                <String, String>{
                  'name': l10n.isolate(result.genericName ?? ''),
                },
              ),
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
                      l10n.isolate(alternative.displayLabel),
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
            l10n.text('alternative.important'),
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('alternative.title'))),
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
                            ? l10n.text('common.usePhotoSearch')
                            : l10n.text('common.useNameSearch'),
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
