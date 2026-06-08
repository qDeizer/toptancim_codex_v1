import 'dart:convert';
import 'package:frontend/models/cart.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/helpers.dart';

class CartService {
  final String _baseUrl = '${Constants.baseUrl}/cart';

  Uri _uri(String path, {String? customerId}) {
    final uri = Uri.parse('$_baseUrl$path');
    if (customerId == null || customerId.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'customer_id': customerId,
      },
    );
  }

  Future<void> addItemToCart(
    String token,
    String variantId,
    int quantity,
    String wholesalerId, {
    String? customerId,
  }) async {
    final response = await http.post(
      _uri('/items', customerId: customerId),
      headers: Helpers.getHeaders(token),
      body: jsonEncode({
        'variant_id': variantId,
        'quantity': quantity,
        'wholesaler_id': wholesalerId,
        if (customerId != null && customerId.isNotEmpty)
          'customer_id': customerId,
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Ürün sepete eklenemedi');
    }
  }

  Future<List<Cart>> getMyCarts(String token, {String? customerId}) async {
    final response = await http.get(
      _uri('', customerId: customerId),
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

  Future<List<Cart>> getOrdersBetweenUsers(
      String token, String personId) async {
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

  Future<void> updateItemQuantity(
    String token,
    String cartItemId,
    int quantity, {
    String? customerId,
  }) async {
    final response = await http.put(
      _uri('/items/$cartItemId', customerId: customerId),
      headers: Helpers.getHeaders(token),
      body: jsonEncode({'quantity': quantity}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Miktar güncellenemedi');
    }
  }

  Future<void> removeItem(String token, String cartItemId,
      {String? customerId}) async {
    final response = await http.delete(
      _uri('/items/$cartItemId', customerId: customerId),
      headers: Helpers.getHeaders(token),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Ürün kaldırılamadı');
    }
  }

  Future<void> placeOrder(String token, String cartId,
      {String? customerId}) async {
    final response = await http.post(
      _uri('/$cartId/place-order', customerId: customerId),
      headers: Helpers.getHeaders(token),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Sipariş verilemedi');
    }
  }
}
