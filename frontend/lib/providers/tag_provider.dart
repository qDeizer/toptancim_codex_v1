import 'package:flutter/material.dart';
import '../models/tag.dart';
import '../services/tag_service.dart';

class TagProvider with ChangeNotifier {
  List<Tag> _tags = [];
  final String? _token;
  bool _isLoading = false;
  final TagService _tagService = TagService();

  TagProvider(this._token);

  List<Tag> get tags => _tags;
  bool get isLoading => _isLoading;
Future<void> fetchTags() async {
    if (_token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _tags = await _tagService.fetchTags(_token);
    } catch (e) {
      print('Error fetching tags: $e');
      _tags = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTag(String name, String? note, double? percentage, double? delta) async {
    if (_token == null) throw Exception('Authentication token not found.');
try {
      final newTag = await _tagService.addTag(_token, name, note, percentage, delta);
      _tags.add(newTag);
      notifyListeners();
} catch (e) {
      rethrow;
}
  }

  Future<void> updateTag(String tagId, String name, String? note, double? percentage, double? delta) async {
    if (_token == null) throw Exception('Authentication token not found.');
try {
      final updatedTag = await _tagService.updateTag(_token, tagId, name, note, percentage, delta);
final index = _tags.indexWhere((tag) => tag.tagId == tagId);
      if (index != -1) {
        _tags[index] = updatedTag;
notifyListeners();
      }
    } catch (e) {
      rethrow;
}
  }

  Future<void> deleteTag(String tagId) async {
    if (_token == null) throw Exception('Authentication token not found.');
final existingIndex = _tags.indexWhere((tag) => tag.tagId == tagId);
    var existingTag = _tags[existingIndex];
    _tags.removeAt(existingIndex);
    notifyListeners();
try {
      await _tagService.deleteTag(_token, tagId);
} catch (e) {
      _tags.insert(existingIndex, existingTag);
      notifyListeners();
      rethrow;
    }
  }
}