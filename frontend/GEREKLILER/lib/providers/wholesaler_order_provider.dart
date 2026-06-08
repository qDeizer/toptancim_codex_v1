import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../services/wholesaler_order_service.dart';

class WholesalerOrderProvider with ChangeNotifier {
  final String? _token;
  final WholesalerOrderService _orderService = WholesalerOrderService();

  List<Cart> _orders = [];
  bool _isLoading = false;
  String? _error;

  WholesalerOrderProvider(this._token);

  List<Cart> get orders => _orders;
  List<Cart> get orderedCarts => _orders.where((c) => c.status == 'ordered').toList();
  List<Cart> get preparingCarts => _orders.where((c) => c.status == 'preparing').toList();
  List<Cart> get shippedCarts => _orders.where((c) => c.status == 'shipped').toList();
  List<Cart> get deliveredCarts => _orders.where((c) => c.status == 'delivered').toList();
  List<Cart> get cancelledCarts => _orders.where((c) => c.status == 'cancelled').toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchWholesalerOrders() async {
    if (_token == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _orderService.getWholesalerOrders(_token);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Cart?> getOrderById(String cartId) async {
    if (_token == null) return null;
    final existingOrderIndex = _orders.indexWhere((o) => o.cartId == cartId);
    if (existingOrderIndex != -1) {
      return _orders[existingOrderIndex];
    }
    await fetchWholesalerOrders();
    final refreshedIndex = _orders.indexWhere((o) => o.cartId == cartId);
    return refreshedIndex != -1 ? _orders[refreshedIndex] : null;
  }

  Future<void> confirmSale(String cartId) async {
    if (_token == null) throw Exception('Yetkisiz işlem');
    try {
      await _orderService.confirmSale(_token, cartId);
      await fetchWholesalerOrders();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String cartId, String status, {required bool createTransaction}) async {
    if (_token == null) throw Exception('Yetkisiz işlem');
    try {
      await _orderService.updateOrderStatus(_token, cartId, status, createTransaction: createTransaction);
      await fetchWholesalerOrders();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateItemInOrder(String cartId, String cartItemId, int newQuantity) async {
    if (_token == null) throw Exception('Yetkisiz işlem');
    try {
      await _orderService.updateItemInOrder(_token, cartId, cartItemId, newQuantity);
      await fetchWholesalerOrders();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> removeItemFromOrder(String cartId, String cartItemId) async {
     if (_token == null) throw Exception('Yetkisiz işlem');
    try {
      await _orderService.removeItemFromOrder(_token, cartId, cartItemId);
      await fetchWholesalerOrders();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> addItemToOrder(String cartId, String variantId, int quantity) async {
     if (_token == null) throw Exception('Yetkisiz işlem');
    try {
      await _orderService.addItemToOrder(_token, cartId, variantId, quantity);
      await fetchWholesalerOrders();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> overrideTotalAmount(String cartId, double newTotal) async {
    if (_token == null) throw Exception('Yetkisiz işlem');
    try {
      await _orderService.overrideTotalAmount(_token, cartId, newTotal);
      await fetchWholesalerOrders();
    } catch (e) {
      rethrow;
    }
  }
}