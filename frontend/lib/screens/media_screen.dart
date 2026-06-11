import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/media.dart';
import '../providers/media_provider.dart';
import '../services/image_service.dart';
import '../utils/constants.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  bool _selectMode = false;
  final Set<String> _selected = {};
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<MediaProvider>().fetchMedia(refresh: true);
    });
  }

  List<MediaItem> get _filteredMedia {
    final media = context.watch<MediaProvider>().media;
    if (_showFavoritesOnly) return media.where((m) => m.isFavorite).toList();
    return media;
  }

  Future<void> _uploadFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      await context.read<MediaProvider>().uploadMedia(bytes, picked.name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medya yüklendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yükleme başarısız: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uploadFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      await context.read<MediaProvider>().uploadMedia(bytes, picked.name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medya yüklendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yükleme başarısız: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteSelected() async {
    final provider = context.read<MediaProvider>();
    for (final id in _selected.toList()) {
      await provider.deleteMedia(id);
    }
    _selected.clear();
    _selectMode = false;
  }

  void _toggleFavorite(String mediaId) {
    context.read<MediaProvider>().toggleFavorite(mediaId);
  }

  void _openAiGenerator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiImageGeneratorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<MediaProvider>().isLoading;
    final media = _filteredMedia;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '${_selected.length} seçildi' : 'Medyam'),
        actions: [
          if (_selectMode) ...[
            IconButton(icon: const Icon(Icons.delete), onPressed: _selected.isNotEmpty ? _deleteSelected : null),
            IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() { _selectMode = false; _selected.clear(); }); }),
          ] else ...[
            IconButton(
              icon: Icon(_showFavoritesOnly ? Icons.star : Icons.star_border),
              onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
              tooltip: 'Favoriler',
            ),
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              onPressed: _openAiGenerator,
              tooltip: 'AI ile Oluştur',
            ),
          ],
        ],
      ),
      floatingActionButton: _selectMode ? null : FloatingActionButton(
        onPressed: () => _showUploadOptions(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<MediaProvider>().fetchMedia(refresh: true),
        child: isLoading && media.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : media.isEmpty
                ? const Center(child: Text('Henüz medya yok. + butonuna basarak yükleyebilirsin.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: media.length,
                    itemBuilder: (ctx, i) => _buildMediaTile(media[i]),
                  ),
      ),
    );
  }

  Widget _buildMediaTile(MediaItem item) {
    final isSelected = _selected.contains(item.mediaId);
    final fullUrl = ImageService.getFullImageUrl(item.url);
    return GestureDetector(
      onTap: () {
        if (_selectMode) {
          setState(() { if (isSelected) _selected.remove(item.mediaId); else _selected.add(item.mediaId); });
        } else {
          _showMediaDetail(item);
        }
      },
      onLongPress: () {
        setState(() { _selectMode = true; _selected.add(item.mediaId); });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(fullUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40)),
            ),
          ),
          if (_selectMode)
            Positioned(top: 4, right: 4,
              child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.blue : Colors.white)),
          if (item.isFavorite && !_selectMode)
            const Positioned(top: 4, left: 4,
              child: Icon(Icons.star, color: Colors.amber, size: 20)),
        ],
      ),
    );
  }

  void _showMediaDetail(MediaItem item) {
    final fullUrl = ImageService.getFullImageUrl(item.url);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(fullUrl, fit: BoxFit.contain)),
            Positioned(top: 8, right: 8, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx))),
            Positioned(top: 8, left: 8, child: IconButton(
              icon: Icon(item.isFavorite ? Icons.star : Icons.star_border, color: Colors.amber),
              onPressed: () { _toggleFavorite(item.mediaId); Navigator.pop(ctx); },
            )),
            Positioned(bottom: 8, right: 8, child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                context.read<MediaProvider>().deleteMedia(item.mediaId);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showUploadOptions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Kameradan'), onTap: () { Navigator.pop(ctx); _uploadFromCamera(); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeriden'), onTap: () { Navigator.pop(ctx); _uploadFromGallery(); }),
          ],
        ),
      ),
    );
  }
}

// AI Görsel Oluşturma Bottom Sheet
class AiImageGeneratorSheet extends StatefulWidget {
  const AiImageGeneratorSheet({super.key});

  @override
  State<AiImageGeneratorSheet> createState() => _AiImageGeneratorSheetState();
}

class _QualityOption {
  final String value;
  final String label;
  final String hint;
  final IconData icon;
  const _QualityOption(this.value, this.label, this.hint, this.icon);
}

class _SizeOption {
  final String value;
  final String label;
  final IconData icon;
  const _SizeOption(this.value, this.label, this.icon);
}

class _AiImageGeneratorSheetState extends State<AiImageGeneratorSheet> {
  final _promptController = TextEditingController();
  int _numImages = 1;
  String _quality = 'low';
  String _size = '1024x1024';
  bool _isGenerating = false;
  String? _errorMessage;
  List<MediaItem> _selectedRefs = [];
  List<MediaItem>? _generatedImages;

  static const _qualityOptions = [
    _QualityOption('low', 'Hızlı', 'En uygun maliyet, taslak için ideal', Icons.bolt),
    _QualityOption('medium', 'Dengeli', 'İyi detay, makul süre', Icons.tune),
    _QualityOption('high', 'Yüksek', 'En iyi detay, daha yavaş ve pahalı', Icons.diamond_outlined),
  ];

  static const _sizeOptions = [
    _SizeOption('1024x1024', 'Kare', Icons.crop_square),
    _SizeOption('1024x1536', 'Dikey', Icons.crop_portrait),
    _SizeOption('1536x1024', 'Yatay', Icons.crop_landscape),
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _selectReferences() async {
    final media = context.read<MediaProvider>().media;
    if (media.isEmpty) {
      setState(() => _errorMessage = 'Referans seçmek için önce medyanıza görsel yükleyin.');
      return;
    }
    final selected = await showDialog<List<MediaItem>>(
      context: context,
      builder: (ctx) => _ReferencePickerDialog(media: media, initialSelection: _selectedRefs),
    );
    if (selected != null) setState(() => _selectedRefs = selected);
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    if (_promptController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Lütfen oluşturmak istediğiniz görseli tarif edin.');
      return;
    }
    setState(() {
      _isGenerating = true;
      _generatedImages = null;
      _errorMessage = null;
    });
    try {
      final provider = context.read<MediaProvider>();
      final images = await provider.generateAiImages(
        prompt: _promptController.text.trim(),
        n: _numImages,
        quality: _quality,
        size: _size,
        referenceMediaIds: _selectedRefs.map((r) => r.mediaId).toList(),
      );
      if (!mounted) return;
      setState(() {
        _generatedImages = images;
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildHeader(cs),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    _sectionTitle(cs, Icons.edit_note, 'Görseli tarif et'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _promptController,
                      maxLines: 4,
                      minLines: 3,
                      textInputAction: TextInputAction.newline,
                      enabled: !_isGenerating,
                      decoration: InputDecoration(
                        hintText: 'Örn: Beyaz fonda, stüdyo ışığında çekilmiş bir kot ceket ürün fotoğrafı...',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(cs, Icons.photo_library_outlined, 'Referans görseller',
                        trailing: '${_selectedRefs.length}/4'),
                    const SizedBox(height: 4),
                    Text(
                      'Referans eklersen yapay zekâ bu görsellerdeki ürünü ve stili temel alır.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    _buildReferenceStrip(cs),
                    const SizedBox(height: 20),

                    _sectionTitle(cs, Icons.grid_view_rounded, 'Görsel sayısı'),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: [1, 2, 3, 4]
                          .map((n) => ButtonSegment(value: n, label: Text('$n')))
                          .toList(),
                      selected: {_numImages},
                      onSelectionChanged: _isGenerating
                          ? null
                          : (sel) => setState(() => _numImages = sel.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(cs, Icons.high_quality_outlined, 'Kalite'),
                    const SizedBox(height: 8),
                    ..._qualityOptions.map((q) => _buildQualityTile(cs, q)),
                    const SizedBox(height: 20),

                    _sectionTitle(cs, Icons.aspect_ratio, 'Boyut'),
                    const SizedBox(height: 8),
                    Row(
                      children: _sizeOptions.map((s) {
                        final selected = _size == s.value;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              avatar: Icon(s.icon, size: 18,
                                  color: selected ? cs.onPrimary : cs.onSurfaceVariant),
                              label: SizedBox(
                                width: double.infinity,
                                child: Text(s.label, textAlign: TextAlign.center),
                              ),
                              selected: selected,
                              selectedColor: cs.primary,
                              labelStyle: TextStyle(
                                  color: selected ? cs.onPrimary : cs.onSurface),
                              onSelected: _isGenerating
                                  ? null
                                  : (sel) {
                                      if (sel) setState(() => _size = s.value);
                                    },
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(cs),
                    ],
                    if (_isGenerating) ...[
                      const SizedBox(height: 16),
                      _buildLoadingCard(cs),
                    ],
                    if (_generatedImages != null && _generatedImages!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildResults(cs),
                    ],
                  ],
                ),
              ),
              _buildBottomBar(cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome, color: cs.onPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Görsel Oluştur',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Tarif et, yapay zekâ senin için üretsin',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _isGenerating ? null : () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ColorScheme cs, IconData icon, String title, {String? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const Spacer(),
        if (trailing != null)
          Text(trailing, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildReferenceStrip(ColorScheme cs) {
    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Referans ekleme kutusu
          InkWell(
            onTap: _isGenerating ? null : _selectReferences,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: cs.primary),
                  const SizedBox(height: 4),
                  Text('Seç', style: TextStyle(fontSize: 11, color: cs.primary)),
                ],
              ),
            ),
          ),
          ..._selectedRefs.map((ref) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        ImageService.getFullImageUrl(ref.url),
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 76,
                          height: 76,
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image, size: 24),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: _isGenerating
                            ? null
                            : () => setState(() => _selectedRefs.remove(ref)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildQualityTile(ColorScheme cs, _QualityOption q) {
    final selected = _quality == q.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _isGenerating ? null : () => setState(() => _quality = q.value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(q.icon, size: 20, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected ? cs.onPrimaryContainer : cs.onSurface,
                        )),
                    Text(q.hint,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: cs.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_errorMessage!,
                style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(Icons.close, color: cs.onErrorContainer, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(),
          ),
          const SizedBox(height: 14),
          Text(
            _numImages > 1 ? '$_numImages görsel oluşturuluyor...' : 'Görsel oluşturuluyor...',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Bu işlem 1-2 dakika sürebilir, lütfen ekranı kapatmayın.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme cs) {
    final images = _generatedImages!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 18),
            const SizedBox(width: 6),
            const Text('Görseller hazır ve medyanıza eklendi',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: images.length > 1 ? 2 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
          children: images.map((img) {
            final url = ImageService.getFullImageUrl(img.url);
            return GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.black87,
                  insetPadding: const EdgeInsets.all(12),
                  child: Stack(
                    children: [
                      InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          color: cs.surfaceContainerHighest,
                          child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image, size: 40)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isGenerating ? null : _generate,
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(
              _isGenerating
                  ? 'Oluşturuluyor...'
                  : (_generatedImages != null ? 'Tekrar Oluştur' : 'Oluştur'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferencePickerDialog extends StatefulWidget {
  final List<MediaItem> media;
  final List<MediaItem> initialSelection;
  const _ReferencePickerDialog({required this.media, this.initialSelection = const []});
  @override
  State<_ReferencePickerDialog> createState() => _ReferencePickerDialogState();
}

class _ReferencePickerDialogState extends State<_ReferencePickerDialog> {
  final Set<String> _sel = {};

  @override
  void initState() {
    super.initState();
    for (final m in widget.initialSelection) {
      if (_sel.length < 4) _sel.add(m.mediaId);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Expanded(child: Text('Referans Seç', style: TextStyle(fontSize: 18))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${_sel.length}/4',
                style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemCount: widget.media.length,
          itemBuilder: (_, i) {
            final item = widget.media[i];
            final sel = _sel.contains(item.mediaId);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (sel) {
                    _sel.remove(item.mediaId);
                  } else if (_sel.length < 4) {
                    _sel.add(item.mediaId);
                  }
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      ImageService.getFullImageUrl(item.url),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image, size: 24),
                      ),
                    ),
                  ),
                  if (sel)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: cs.primary.withValues(alpha: 0.35),
                        border: Border.all(color: cs.primary, width: 2),
                      ),
                      child: const Center(
                          child: Icon(Icons.check_circle, color: Colors.white, size: 28)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
        FilledButton(
          onPressed: () => Navigator.pop(
              ctx, widget.media.where((m) => _sel.contains(m.mediaId)).toList()),
          child: const Text('Seç'),
        ),
      ],
    );
  }
}

