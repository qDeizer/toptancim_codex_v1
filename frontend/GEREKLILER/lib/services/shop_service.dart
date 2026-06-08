import 'dart:convert';
import 'package:frontend/models/product.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ShopService {
  final String _baseUrl = '${Constants.baseUrl}/shop';

  Future<List<Product>> fetchShopProducts(String token, {String? wholesalerId}) async {
    String url = '$_baseUrl/products';
    if (wholesalerId != null) {
      url += '?wholesaler_id=$wholesalerId';
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((dynamic item) => Product.fromJson(item)).toList();
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['message'] ?? 'Alışveriş ürünleri yüklenemedi');
      }
    } catch (e) {
      rethrow;
    }
  }
}