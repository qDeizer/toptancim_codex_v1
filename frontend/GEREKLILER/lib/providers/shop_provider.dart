import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/shop_service.dart';

class ShopProvider with ChangeNotifier {
  final String? _token;
  final ShopService _shopService = ShopService();
  
  List<Product> _shopProducts = [];
  List<Product> _filteredProducts = [];
  List _wholesalers = []; // Toptancıları tutmak için
  List _suppliers = []; // Suppliers için ayrı liste
  bool _isLoading = false;
  String? _error;
  String? _selectedWholesalerId;

  ShopProvider(this._token);

  // Getters
  List<Product> get shopProducts => _shopProducts;
  List<Product> get filteredProducts => _filteredProducts;
  List get wholesalers => _wholesalers;
  List get suppliers => _suppliers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedWholesalerId => _selectedWholesalerId;


  Future<void> fetchShopContent({String? wholesalerId}) async {
    if (_token == null) {
      _error = "Yetkilendirme token'ı bulunamadı.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _selectedWholesalerId = wholesalerId;
    notifyListeners();

    try {
      final products = await _shopService.fetchShopProducts(_token, wholesalerId: wholesalerId);
      _shopProducts = products;
      
      // Toptancıları sadece ilk yüklemede veya filtre temizlendiğinde çek
      if (wholesalerId == null && _wholesalers.isEmpty) {
          _extractWholesalersFromProducts(products);
      }
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _extractWholesalersFromProducts(List<Product> products) {
      final Set<String> wholesalerIds = {};
      final List uniqueWholesalers = [];
      for (var product in products) {
          if (wholesalerIds.add(product.creatorId)) {
              uniqueWholesalers.add({
                  'id': product.creatorId,
                  'name': product.wholesalerName,
                  'photo': product.wholesalerPhoto,
              });
          }
      }
      _wholesalers = uniqueWholesalers;
      _suppliers = uniqueWholesalers; // Suppliers da aynı veri
  }

  // Eksik metodları ekleyelim
  Future<void> loadSuppliers() async {
    await fetchShopContent();
  }

  Future<void> loadProducts() async {
    await fetchShopContent();
    _filteredProducts = List.from(_shopProducts);
  }

  void filterProductsBySupplierId(String? supplierId) {
    if (supplierId == null) {
      _filteredProducts = List.from(_shopProducts);
    } else {
      _filteredProducts = _shopProducts.where((product) => 
        product.creatorId == supplierId).toList();
    }
    notifyListeners();
  }
}