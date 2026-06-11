import 'dart:async';
import 'package:flutter/material.dart';
import '../models/media.dart';
import '../services/media_service.dart';
import '../services/socket_service.dart';

class MediaProvider with ChangeNotifier {
  final MediaService _service = MediaService();
  List<MediaItem> _media = [];
  bool _isLoading = false;
  Timer? _pollTimer;
  StreamSubscription? _socketSub;

  List<MediaItem> get media => List.from(_media);
  bool get isLoading => _isLoading;
  List<MediaItem> get favorites => _media.where((m) => m.isFavorite).toList();
  bool get hasGenerating => _media.any((m) => m.isGenerating);

  MediaProvider() {
    _initSocketListener();
  }

  void _initSocketListener() {
    _socketSub?.cancel();
    _socketSub = SocketService().mediaUpdates.listen((_) {
      fetchMedia(refresh: true);
    });
  }

  void _maybeStartPolling() {
    if (hasGenerating && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (hasGenerating) {
          fetchMedia(refresh: true);
        } else {
          _pollTimer?.cancel();
          _pollTimer = null;
        }
      });
    } else if (!hasGenerating && _pollTimer != null) {
      _pollTimer!.cancel();
      _pollTimer = null;
    }
  }

  Future<void> fetchMedia({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final all = await _service.fetchMedia();
      _media = all;
      _maybeStartPolling();
    } catch (e) {
      debugPrint('Media fetch error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<MediaItem?> uploadMedia(List<int> bytes, String filename) async {
    try {
      final item = await _service.uploadMedia(bytes, filename);
      _media.insert(0, item);
      notifyListeners();
      return item;
    } catch (e) {
      debugPrint('Media upload error: $e');
      rethrow;
    }
  }

  Future<void> toggleFavorite(String mediaId) async {
    final idx = _media.indexWhere((m) => m.mediaId == mediaId);
    if (idx < 0) return;
    _media[idx].isFavorite = !_media[idx].isFavorite;
    notifyListeners();
    try {
      final updated = await _service.toggleFavorite(mediaId);
      if (updated != null) _media[idx].isFavorite = updated.isFavorite;
    } catch (e) {
      _media[idx].isFavorite = !_media[idx].isFavorite; // revert
    }
    notifyListeners();
  }

  Future<void> deleteMedia(String mediaId, {bool force = false}) async {
    _media.removeWhere((m) => m.mediaId == mediaId);
    notifyListeners();
    try {
      await _service.deleteMedia(mediaId, force: force);
    } on MediaInUseException {
      // Kullanıcıya göstermek için exception'ı yukarı sıçrat
      rethrow;
    } catch (e) {
      await fetchMedia(refresh: true); // reload on failure
    }
  }

  Future<List<MediaItem>> generateAiImages({
    required String prompt,
    int n = 1,
    String quality = 'low',
    String size = '1024x1024',
    List<String>? referenceMediaIds,
  }) async {
    final generated = await _service.generateAiImages(
      prompt: prompt,
      n: n,
      quality: quality,
      size: size,
      referenceMediaIds: referenceMediaIds,
    );
    // Async üretim (202): placeholder'lar generating statüsüyle gelir
    _media.insertAll(0, generated);
    _maybeStartPolling();
    notifyListeners();
    return generated;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socketSub?.cancel();
    super.dispose();
  }
}
