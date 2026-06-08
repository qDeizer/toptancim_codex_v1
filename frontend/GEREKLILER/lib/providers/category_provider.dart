import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class CategoryProvider with ChangeNotifier {
  List<Category> _categories = [];
  final String? _token;
  bool _isLoading = false;
  final CategoryService _categoryService = CategoryService();

  CategoryProvider(this._token);

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> fetchCategories() async {
    if (_token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _categories = await _categoryService.fetchCategories(_token);
    } catch (e) {
      // Hata UI'da gösterileceği için burada sadece loglanabilir.
      print(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    if (_token == null) throw Exception('Authentication token not found.');
    try {
      final newCategory = await _categoryService.addCategory(_token, name);
      _categories.add(newCategory);
      notifyListeners();
    } catch (e) {
      rethrow; // Hatanın UI katmanına iletilmesini sağlar.
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    if (_token == null) throw Exception('Authentication token not found.');
    final existingCategoryIndex = _categories.indexWhere((cat) => cat.categoryId == categoryId);
    var existingCategory = _categories[existingCategoryIndex];
    _categories.removeAt(existingCategoryIndex);
    notifyListeners();

    try {
      await _categoryService.deleteCategory(_token, categoryId);
    } catch (e) {
      // Silme işlemi başarısız olursa kategoriyi listeye geri ekle
      _categories.insert(existingCategoryIndex, existingCategory);
      notifyListeners();
      rethrow; // Hatanın UI katmanına iletilmesini sağlar.
    }
  }
}