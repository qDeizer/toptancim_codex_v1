import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media.dart';
import '../providers/media_provider.dart';
import '../screens/media_screen.dart';
import '../services/image_service.dart';

/// Ürün ekle/düzenle ekranlarında kullanılan çok-seçimli medya galerisi sheet.
/// Seçilen görsellerin URL'lerini [onSelected] callback'i ile döndürür.
/// Üst bölümdeki "AI ile Oluştur" butonu AiImageGeneratorSheet'i açar;
/// dönen placeholder'lar polling sayesinde hazır olunca otomatik seçilir.
class MediaPickerSheet extends StatefulWidget {
  final void Function(List<String> urls) onSelected;

  const MediaPickerSheet({super.key, required this.onSelected});

  @override
  State<MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<MediaPickerSheet> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<MediaProvider>().fetchMedia(refresh: true);
    });
  }

  List<MediaItem> get _readyMedia =>
      context.watch<MediaProvider>().media.where((m) => m.isReady && m.url.isNotEmpty).toList();

  void _openAiGenerator() {
    final notifier = ValueNotifier<List<String>>([]);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiImageGeneratorSheet(onGenerated: notifier),
    ).then((_) {
      // Sheet kapandı; AI placeholders'ını galeride görüp seçebilsin
      if (notifier.value.isNotEmpty) {
        setState(() {
          for (final id in notifier.value) {
            _selectedIds.add(id);
          }
        });
      }
    });
  }

  void _confirm() {
    final urls = _readyMedia
        .where((m) => _selectedIds.contains(m.mediaId))
        .map((m) => m.url)
        .toList();
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir görsel seçin'), duration: Duration(seconds: 2)),
      );
      return;
    }
    Navigator.pop(context);
    widget.onSelected(urls);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = _readyMedia;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Column(
                children: [
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Medyadan Seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // AI butonu
                      OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('AI Üret', style: TextStyle(fontSize: 12)),
                        onPressed: _openAiGenerator,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: cs.primary),
                          foregroundColor: cs.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${_selectedIds.length} görsel seçili',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            // Grid
            Expanded(
              child: media.isEmpty
                  ? const Center(child: Text('Henüz medya yok.'))
                  : GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: media.length,
                      itemBuilder: (_, i) {
                        final item = media[i];
                        final sel = _selectedIds.contains(item.mediaId);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (sel) { _selectedIds.remove(item.mediaId); } else { _selectedIds.add(item.mediaId); }
                          }),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  ImageService.getFullImageUrl(item.url),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                                ),
                              ),
                              if (sel)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: cs.primary.withValues(alpha: 0.3),
                                    border: Border.all(color: cs.primary, width: 2),
                                  ),
                                  child: const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 32)),
                                ),
                              if (item.isAi)
                                Positioned(
                                  bottom: 2, left: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome, size: 10, color: Colors.amber),
                                        Text('AI', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Bottom bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      '${_selectedIds.isEmpty ? 'Seç' : 'Seç ($_selectedIds adet)'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
