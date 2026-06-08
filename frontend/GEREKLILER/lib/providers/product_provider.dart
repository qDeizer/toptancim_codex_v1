import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/tag.dart';
import '../services/product_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  final String? _token;
  bool _isLoading = false;
  final ProductService _productService = ProductService();

  ProductProvider(this._token, this._products, List<Category> categories, List<Tag> tags);

  List<Product> get products => [..._products];
  bool get isLoading => _isLoading;

  Future<void> fetchProducts() async {
    if (_token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _products = await _productService.fetchProducts(_token);
    } catch (e) {
      print(e);
    }
    _isLoading = false;
    notifyListeners();
  }
  
  Future<Product> fetchProductById(String productId) async {
     if (_token == null) throw Exception('Not authenticated');
     return await _productService.fetchProductById(_token, productId);
  }

  Future<void> addProduct(Product product) async {
    if (_token == null) throw Exception('Authentication token not found.');
    _isLoading = true;
    notifyListeners();
    try {
      await _productService.createProduct(_token, product);
      await fetchProducts();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // DEĞİŞİKLİK: Product yerine Map<String, dynamic> alacak şekilde güncellendi.
  Future<void> updateProduct(String productId, Map<String, dynamic> productData) async {
    if (_token == null) throw Exception('Authentication token not found.');
    _isLoading = true;
    notifyListeners();
    try {
      await _productService.updateProduct(_token, productId, productData);
      await fetchProducts();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String productId) async {
    if (_token == null) throw Exception('Authentication token not found.');
    final existingProductIndex = _products.indexWhere((p) => p.productId == productId);
    var existingProduct = _products[existingProductIndex];
    _products.removeAt(existingProductIndex);
    notifyListeners();
    try {
      await _productService.deleteProduct(_token, productId);
    } catch (e) {
      _products.insert(existingProductIndex, existingProduct);
      notifyListeners();
      rethrow;
    }
  }
}