import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/tag.dart';

class TagService {
  final String _baseUrl = '${Constants.baseUrl}/tags';

  Future<List<Tag>> fetchTags(String token) async {
    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Tag.fromJson(item)).toList();
    } else {
      throw Exception('Etiketler yüklenemedi');
    }
  }

  Future<Tag> addTag(String token, String name, String? note, double? percentage, double? delta) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'note': note,
        'pricing_percentage': percentage,
        'pricing_delta': delta,
      }),
    );

    if (response.statusCode == 201) {
      return Tag.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Etiket eklenemedi');
    }
  }
  
  Future<Tag> updateTag(String token, String tagId, String name, String? note, double? percentage, double? delta) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/$tagId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'note': note,
        'pricing_percentage': percentage,
        'pricing_delta': delta,
      }),
    );

    if (response.statusCode == 200) {
       return Tag.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Etiket güncellenemedi');
    }
  }

  Future<void> deleteTag(String token, String tagId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/$tagId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Etiket silinemedi');
    }
  }
}