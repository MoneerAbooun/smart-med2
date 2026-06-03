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
import 'package:smart_med/features/medicine_search/presentation/medicine_result_localization.dart';
import 'package:smart_med/features/medicine_search/presentation/widgets/medicine_name_suggestion_helpers.dart';

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
  final MedicineSearchHistoryRepository _historyRepository =
      medicineSearchHistoryRepository;
  final MedicineNameRepository _medicineNameRepository = medicineNameRepository;

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
  List<String> _recentMedicineSearches = const <String>[];
  List<MedicineNameEntry> _medicineNameEntries = const <MedicineNameEntry>[];

  @override
  void initState() {
    super.initState();

    _nameController.addListener(_onMedicineNameInputChanged);
    _selectedImage = widget.initialImage;

    if (_selectedImage != null) {
      _selectedMode = MedicineSearchMode.image;
      _loadSelectedImageBytes();
    }

    _loadSearchHistory();
    _loadMedicineNameEntries();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onMedicineNameInputChanged);
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
        _errorMessage = context.l10n.format(
          'home.camera.captureError',
          <String, String>{'error': context.l10n.isolate(e.toString())},
        );
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
      _nameController.text,
    );
  }

  void _applyMedicineSuggestion(MedicineNameEntry entry) {
    final value = medicineEntrySearchValue(entry);

    setState(() {
      _nameController.text = value;
      _nameController.selection = TextSelection.collapsed(offset: value.length);
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
      _nameController.text = value;
      _errorMessage = null;
    });
  }

  Future<void> _searchByName() async {
    FocusScope.of(context).unfocus();
    final query = _nameController.text.trim();
    final result = await _runSearch(() => _repository.searchByName(query));

    if (result != null) {
      await _saveMedicineSearch(query);
    }
  }

  Future<void> _searchByImage() async {
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
      _isSearching = true;
      _errorMessage = null;
      _expandedSectionId = null;
    });

    try {
      final result = await loader();

      if (!mounted) return null;

      setState(() {
        _result = result;
        _isSearching = false;
        _expandedSectionId = null;
      });

      return result;
    } on MedicineLookupRepositoryException catch (error) {
      if (!mounted) return null;

      setState(() {
        _errorMessage = error.message;
        _isSearching = false;
        _expandedSectionId = null;
      });

      return null;
    } catch (error) {
      if (!mounted) return null;

      setState(() {
        _errorMessage = error.toString();
        _isSearching = false;
        _expandedSectionId = null;
      });

      return null;
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

  String _sectionPreview(
    BuildContext context,
    List<String> items,
    String emptyMessage,
  ) {
    final previewSource = items.isEmpty ? emptyMessage : items.first;
    final preview = _truncateText(previewSource);

    if (items.length <= 1) {
      return preview;
    }

    return context.l10n.format('medicineSearch.more', <String, String>{
      'preview': context.l10n.isolate(preview),
      'count': (items.length - 1).toString(),
    });
  }

  String _sectionCountLabel(BuildContext context, List<String> items) {
    if (items.isEmpty) {
      return context.l10n.text('common.notAvailable');
    }

    return items.length == 1
        ? context.l10n.text('common.oneItem')
        : context.l10n.format('common.itemCount', <String, String>{
            'count': items.length.toString(),
          });
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
    final l10n = context.l10n;

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
            l10n.text('medicineSearch.mode.title'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('medicineSearch.mode.subtitle'),
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
              label: Text(l10n.text('common.useName')),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _selectMode(MedicineSearchMode.image),
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
    final query = _nameController.text.trim();

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
            l10n.text('medicineSearch.name.title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('medicineSearch.name.subtitle'),
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
              label: l10n.text('common.medicineName'),
              hint: l10n.text('common.exampleIbuprofen'),
            ),
            onSubmitted: (_) {
              if (!_isSearching) {
                _searchByName();
              }
            },
          ),
          const SizedBox(height: 14),
          _buildMedicineSuggestionsOrHistory(disabled: _isSearching),
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
              label: Text(
                _isSearching
                    ? l10n.text('common.searching')
                    : l10n.text('medicineSearch.name.button'),
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
            l10n.text('medicineSearch.image.title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('medicineSearch.image.subtitle'),
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
                      onPressed: _isSearching ? null : _openInlineCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l10n.text('common.camera')),
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
                      onPressed: _isSearching
                          ? null
                          : _closeInlineCameraOrClearImage,
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
                onPressed: _isSearching ? null : _searchByImage,
                icon: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.image_search_outlined),
                label: Text(
                  _isSearching
                      ? l10n.text('common.searching')
                      : l10n.text('medicineSearch.image.button'),
                ),
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
    required MedicineResultSection section,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizedItems = context.l10n.medicineResultTexts(
      items,
      section: section,
    );
    final displayItems = localizedItems.isEmpty
        ? <String>[emptyMessage]
        : localizedItems;
    final isPlaceholder = localizedItems.isEmpty;
    final isExpanded = _expandedSectionId == title;
    final canExpand = localizedItems.isNotEmpty;
    final preview = _sectionPreview(context, localizedItems, emptyMessage);
    final countLabel = _sectionCountLabel(context, localizedItems);

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
    final l10n = context.l10n;
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
            l10n.isolate(result.medicineName),
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
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if (resolvedDifferentFromQuery) ...[
            const SizedBox(height: 6),
            Text(
              l10n.format('medicineSearch.details.searchedAs', <String, String>{
                'query': l10n.isolate(result.query),
              }),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            l10n.text('medicineSearch.details.tap'),
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
                l10n.format(
                  'medicineSearch.details.photoNote',
                  <String, String>{
                    'note': l10n.medicineResultText(
                      result.identificationReason ?? '',
                    ),
                  },
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildListSection(
            context,
            icon: Icons.local_offer_outlined,
            title: l10n.text('medicineSearch.section.brandNames'),
            items: result.brandNames,
            emptyMessage: l10n.text('medicineSearch.empty.brandNames'),
            section: MedicineResultSection.brandNames,
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.science_outlined,
            title: l10n.text('medicineSearch.section.activeIngredients'),
            items: result.activeIngredients,
            emptyMessage: l10n.text('medicineSearch.empty.activeIngredients'),
            section: MedicineResultSection.activeIngredients,
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.info_outline,
            title: l10n.text('medicineSearch.section.commonUses'),
            items: result.usedFor,
            emptyMessage: l10n.text('medicineSearch.empty.commonUses'),
            section: MedicineResultSection.commonUses,
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.straighten_outlined,
            title: l10n.text('medicineSearch.section.doseInformation'),
            items: result.dose,
            emptyMessage: l10n.text('medicineSearch.empty.doseInformation'),
            section: MedicineResultSection.dose,
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.warning_amber_rounded,
            title: l10n.text('medicineSearch.section.warnings'),
            items: result.warnings,
            emptyMessage: l10n.text('medicineSearch.empty.warnings'),
            section: MedicineResultSection.warnings,
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.sick_outlined,
            title: l10n.text('medicineSearch.section.sideEffects'),
            items: result.sideEffects,
            emptyMessage: l10n.text('medicineSearch.empty.sideEffects'),
            section: MedicineResultSection.sideEffects,
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.inventory_2_outlined,
            title: l10n.text('medicineSearch.section.storage'),
            items: result.storage,
            emptyMessage: l10n.text('medicineSearch.empty.storage'),
            section: MedicineResultSection.storage,
          ),
          const SizedBox(height: 12),
          _buildListSection(
            context,
            icon: Icons.gpp_maybe_outlined,
            title: l10n.text('medicineSearch.section.disclaimer'),
            items: result.disclaimer,
            emptyMessage: l10n.text('medicineSearch.empty.disclaimer'),
            section: MedicineResultSection.disclaimer,
          ),
        ],
      ),
    );
  }

  Widget _buildResultState(BuildContext context) {
    final l10n = context.l10n;

    if (_errorMessage != null) {
      return _buildStateCard(
        context,
        icon: Icons.error_outline,
        title: l10n.text('medicineSearch.error.title'),
        message: l10n.medicineResultText(_errorMessage!),
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
      title: l10n.text('medicineSearch.ready.title'),
      message: l10n.text('medicineSearch.ready.message'),
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('medicineSearch.title'))),
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
