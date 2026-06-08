import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../services/cart_service.dart';
import '../services/socket_service.dart';
import '../utils/logger.dart';
import 'dart:async';

class CartProvider with ChangeNotifier {
  String? _token;
  final CartService _cartService = CartService();

  List<Cart> _carts = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _socketSubscription;

  CartProvider(this._token) {
     if (_token != null) {
        _initSocketListener();
     }
  }

  void _initSocketListener() {
    _socketSubscription?.cancel();
    _socketSubscription = SocketService().cartUpdates.listen((_) {
      AppLogger.info('CartProvider: Received socket update, fetching carts...');
      fetchMyCarts();
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  String? get token => _token;

  void updateAuth(String? newToken) {
    if (_token == newToken) return; // No change
    
    _token = newToken;
    AppLogger.info('CartProvider: Auth token updated. Token exists: ${_token != null}');

    if (_token != null) {
      _initSocketListener();
      SocketService().connect(_token!);
      fetchMyCarts();
    } else {
      SocketService().disconnect();
      _carts = [];
      notifyListeners();
    }
  }

  List<Cart> get activeCarts => _carts.where((c) => c.status == 'active').toList();
  List<Cart> get orderedCarts => _carts.where((c) => c.status == 'ordered').toList();
  List<Cart> get preparingCarts => _carts.where((c) => c.status == 'preparing' || c.status == 'shipped').toList();
  List<Cart> get deliveredCarts => _carts.where((c) => c.status == 'delivered').toList();
  List<Cart> get cancelledCarts => _carts.where((c) => c.status == 'cancelled').toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalActiveCartItems {
    if (activeCarts.isEmpty) return 0;
    // User requested "product count" (distinct items), not quantity sum.
    // "active sepetimde ki ürün tutarları kadar sayı gözüksün yani 2 tane"
    // This implies counting the list length across all active carts.
    return activeCarts.fold(0, (sum, cart) => sum + cart.items.length);
  }

  // Alias for totalActiveCartItems to match usage in screens
  int get totalItems => totalActiveCartItems;
  int get totalItemCount => totalActiveCartItems;


  Future<void> fetchMyCarts() async {
    if (_token == null) return;
    AppLogger.info('fetchMyCarts called');
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _carts = await _cartService.getMyCarts(_token!);
      AppLogger.info('fetchMyCarts success. Active carts: ${activeCarts.length}');
    } catch (e, stack) {
      _error = e.toString();
      AppLogger.error('fetchMyCarts failed', e, stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addItemToCart({
    required String variantId,
    required int quantity,
    required String wholesalerId,
  }) async {
    if (_token == null) throw Exception('Yetkisiz işlem');
    try {
      await _cartService.addItemToCart(_token!, variantId, quantity, wholesalerId);
      await fetchMyCarts();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateItemQuantity(String cartItemId, int newQuantity) async {
    if (_token == null) throw Exception('Yetkisiz işlem');
    try {
      await _cartService.updateItemQuantity(_token!, cartItemId, newQuantity);
      // Refresh carts to get the new total amount
      await fetchMyCarts();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeItem(String cartItemId) async {
    if (_token == null) throw Exception('Yetkisiz işlem');
    try {
      // Optimistic UI update
      final cartContainingItem = _carts.firstWhere((c) => c.items.any((i) => i.cartItemId == cartItemId));
      final itemToRemove = cartContainingItem.items.firstWhere((i) => i.cartItemId == cartItemId);
      cartContainingItem.items.remove(itemToRemove);
      notifyListeners();

      await _cartService.removeItem(_token!, cartItemId);
      await fetchMyCarts();
      // Refresh to be sure
    } catch (e) {
       _error = e.toString();
      notifyListeners();
      await fetchMyCarts(); // Revert on error
      rethrow;
    }
  }


  Future<void> placeOrder(String cartId) async {
     if (_token == null) throw Exception('Yetkisiz işlem');
    _isLoading = true;
    notifyListeners();
    try {
      await _cartService.placeOrder(_token!, cartId);
      // Refresh the list to update status from 'active' to 'ordered'
      await fetchMyCarts();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}