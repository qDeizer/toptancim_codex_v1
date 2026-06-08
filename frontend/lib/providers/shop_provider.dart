import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/shop_service.dart';
import '../utils/logger.dart';

class ShopProvider with ChangeNotifier {
  final String? _token;
  final ShopService _shopService = ShopService();

  List<Product> _shopProducts = [];
  List<Product> _filteredProducts = [];
  List _wholesalers = [];
  List _suppliers = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedWholesalerId;

  ShopProvider(this._token);

  List<Product> get shopProducts => _shopProducts;
  List<Product> get filteredProducts => _filteredProducts;
  List get wholesalers => _wholesalers;
  List get suppliers => _suppliers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedWholesalerId => _selectedWholesalerId;

  Future<void> fetchShopContent({String? wholesalerId}) async {
    if (_token == null) {
      _error = "Yetkilendirme token'i bulunamadi.";
      AppLogger.warning(
        'Shop provider fetch blocked due to missing auth token',
      );
      notifyListeners();
      return;
    }

    AppLogger.info(
      'Shop provider fetch started: wholesalerId=${wholesalerId ?? "all"}',
    );
    _isLoading = true;
    _error = null;
    _selectedWholesalerId = wholesalerId;
    notifyListeners();

    try {
      final products = await _shopService.fetchShopProducts(
        _token,
        wholesalerId: wholesalerId,
      );
      _shopProducts = products;

      if (wholesalerId == null && _wholesalers.isEmpty) {
        _extractWholesalersFromProducts(products);
      }

      _filteredProducts = wholesalerId == null
          ? List<Product>.from(_shopProducts)
          : _shopProducts
              .where((product) => product.creatorId == wholesalerId)
              .toList();

      AppLogger.info(
        'Shop provider fetch completed: wholesalerId=${wholesalerId ?? "all"}, products=${_shopProducts.length}, filtered=${_filteredProducts.length}, suppliers=${_suppliers.length}',
      );
    } catch (error, stackTrace) {
      _error = error.toString();
      AppLogger.error(
        'Shop provider fetch failed: wholesalerId=${wholesalerId ?? "all"}',
        error,
        stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _extractWholesalersFromProducts(List<Product> products) {
    final wholesalerIds = <String>{};
    final uniqueWholesalers = [];

    for (final product in products) {
      if (wholesalerIds.add(product.creatorId)) {
        uniqueWholesalers.add({
          'id': product.creatorId,
          'name': product.wholesalerName,
          'photo': product.wholesalerPhoto,
        });
      }
    }

    _wholesalers = uniqueWholesalers;
    _suppliers = uniqueWholesalers;
    AppLogger.debug(
      'Shop provider extracted suppliers: count=${_suppliers.length}',
    );
  }

  Future<void> loadSuppliers() async {
    AppLogger.debug('Shop provider loadSuppliers called');
    await fetchShopContent();
  }

  Future<void> loadProducts() async {
    AppLogger.debug(
      'Shop provider loadProducts called: cacheCount=${_shopProducts.length}',
    );
    if (_shopProducts.isEmpty) {
      await fetchShopContent();
    }
    _filteredProducts = List<Product>.from(_shopProducts);
    AppLogger.info(
      'Shop provider loadProducts prepared filtered list: count=${_filteredProducts.length}',
    );
    notifyListeners();
  }

  void filterProductsBySupplierId(String? supplierId) {
    if (supplierId == null) {
      _filteredProducts = List<Product>.from(_shopProducts);
    } else {
      _filteredProducts = _shopProducts
          .where((product) => product.creatorId == supplierId)
          .toList();
    }

    AppLogger.debug(
      'Shop provider filter applied: supplierId=${supplierId ?? "all"}, resultCount=${_filteredProducts.length}',
    );
    notifyListeners();
  }
}
