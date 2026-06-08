import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/product.dart';

class ProductService {
  final String _baseUrl = '${Constants.baseUrl}/products';

  Future<List<Product>> fetchProducts(String token) async {
    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<Product> fetchProductById(String token, String productId) async {
     final response = await http.get(
      Uri.parse('$_baseUrl/$productId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to load product details');
    }
  }

  Future<Product> createProduct(String token, Product product) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(product.toJson()),
    );
    if (response.statusCode == 201) {
      return Product.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Failed to create product');
    }
  }

  // DEĞİŞİKLİK: Product yerine Map<String, dynamic> alacak şekilde güncellendi.
  Future<Product> updateProduct(String token, String productId, Map<String, dynamic> productData) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/$productId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(productData),
    );
    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Failed to update product');
    }
  }

  Future<void> deleteProduct(String token, String productId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/$productId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Failed to delete product');
    }
  }
}