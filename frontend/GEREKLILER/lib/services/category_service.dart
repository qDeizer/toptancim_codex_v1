import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/category.dart';

class CategoryService {
  final String _baseUrl = '${Constants.baseUrl}/categories';

  Future<List<Category>> fetchCategories(String token) async {
    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Category.fromJson(item)).toList();
    } else {
      throw Exception('Kategoriler yüklenemedi');
    }
  }

  Future<Category> addCategory(String token, String name) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 201) {
      return Category.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Kategori eklenemedi');
    }
  }

  Future<void> deleteCategory(String token, String categoryId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/$categoryId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Kategori silinemedi');
    }
  }
}