import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/tag.dart';
import '../models/connection.dart';

class TagAssignmentService {
  final String _baseUrl = '${Constants.baseUrl}/assignments';

  Future<List<Tag>> getTagsForConnection(String token, String relationId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/connection/$relationId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Tag.fromJson(item)).toList();
    } else {
      throw Exception('Bağlantı için etiketler yüklenemedi');
    }
  }

  Future<List<Connection>> getConnectionsForTag(String token, String tagId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tag/$tagId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Connection.fromJson(item)).toList();
    } else {
      throw Exception('Etiket için bağlantılar yüklenemedi');
    }
  }

  Future<List<Tag>> syncTagsForConnection(String token, String relationId, List<String> tagIds) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/connection/$relationId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'tag_ids': tagIds}),
    );
    
    if (response.statusCode == 200) {
       List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Tag.fromJson(item)).toList();
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Etiketler güncellenemedi');
    }
  }
}