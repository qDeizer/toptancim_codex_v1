import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cart.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class WholesalerOrderService {
  final String _baseUrl = '${Constants.baseUrl}/cart';

  Future<List<Cart>> getWholesalerOrders(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/wholesaler-orders'),
      headers: Helpers.getHeaders(token),
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((c) => Cart.fromJson(c)).toList();
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Siparişler getirilemedi');
    }
  }
  
  Future<void> confirmSale(String token, String cartId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/$cartId/confirm-sale'),
      headers: Helpers.getHeaders(token),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Sipariş onaylanamadı');
    }
  }

  Future<void> updateOrderStatus(String token, String cartId, String status, {required bool createTransaction}) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/$cartId/status'),
      headers: Helpers.getHeaders(token),
      body: jsonEncode({
        'status': status,
        'createTransaction': createTransaction,
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Sipariş durumu güncellenemedi');
    }
  }

  Future<void> updateItemInOrder(String token, String cartId, String cartItemId, int quantity) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/wholesaler/$cartId/items/$cartItemId'),
      headers: Helpers.getHeaders(token),
      body: jsonEncode({'quantity': quantity}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Ürün miktarı güncellenemedi');
    }
  }

  Future<void> removeItemFromOrder(String token, String cartId, String cartItemId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/wholesaler/$cartId/items/$cartItemId'),
      headers: Helpers.getHeaders(token),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Ürün siparişten kaldırılamadı');
    }
  }

  Future<void> addItemToOrder(String token, String cartId, String variantId, int quantity) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/wholesaler/$cartId/items'),
      headers: Helpers.getHeaders(token),
      body: jsonEncode({
        'variant_id': variantId,
        'quantity': quantity,
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Ürün siparişe eklenemedi');
    }
  }

  Future<void> overrideTotalAmount(String token, String cartId, double newTotal) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/wholesaler/$cartId/override-total'),
      headers: Helpers.getHeaders(token),
      body: jsonEncode({'total_amount': newTotal}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Toplam tutar güncellenemedi');
    }
  }
}