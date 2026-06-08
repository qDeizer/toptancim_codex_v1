import 'dart:convert';
import 'package:frontend/models/cart.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/helpers.dart';

class CartService {
  final String _baseUrl = '${Constants.baseUrl}/cart';

  Future<void> addItemToCart(String token, String variantId, int quantity, String wholesalerId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/items'),
      headers: Helpers.getHeaders(token),
      body: jsonEncode({
        'variant_id': variantId,
        'quantity': quantity,
        'wholesaler_id': wholesalerId,
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Ürün sepete eklenemedi');
    }
  }

  Future<List<Cart>> getMyCarts(String token) async {
    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: Helpers.getHeaders(token),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((c) => Cart.fromJson(c)).toList();
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Sepetler getirilemedi');
    }
  }

   Future<List<Cart>> getOrdersBetweenUsers(String token, String personId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/between/$personId'),
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

  Future<void> updateItemQuantity(String token, String cartItemId, int quantity) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/items/$cartItemId'),
      headers: Helpers.getHeaders(token),
      body: jsonEncode({'quantity': quantity}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Miktar güncellenemedi');
    }
  }

  Future<void> removeItem(String token, String cartItemId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/items/$cartItemId'),
      headers: Helpers.getHeaders(token),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Ürün kaldırılamadı');
    }
  }

  Future<void> placeOrder(String token, String cartId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/$cartId/place-order'),
      headers: Helpers.getHeaders(token),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Sipariş verilemedi');
    }
  }
}