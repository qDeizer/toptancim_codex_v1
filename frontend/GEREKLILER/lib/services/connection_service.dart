import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/connection.dart';
import '../models/connection_details.dart';

class ConnectionService {
  final String _baseUrl = '${Constants.baseUrl}/connections';

  Future<Map<String, List<Connection>>> fetchConnections(String token) async {
    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );
    if (response.statusCode == 200) {
      Map<String, dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      List<Connection> customers = (body['customers'] as List)
          .map((item) => Connection.fromJson(item))
          .toList();
      List<Connection> wholesalers = (body['wholesalers'] as List)
          .map((item) => Connection.fromJson(item))
          .toList();
      return {'customers': customers, 'wholesalers': wholesalers};
    } else {
      throw Exception('Bağlantılar yüklenemedi');
    }
  }

  Future<ConnectionDetails> fetchConnectionDetails(String token, String relationId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$relationId/details'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );
    if (response.statusCode == 200) {
      Map<String, dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return ConnectionDetails.fromJson(body);
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Bağlantı detayları yüklenemedi');
    }
  }

  Future<List<String>> getRelationIdsByUsers(String token, String otherUserId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/by-users?other_user_id=$otherUserId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );
    if (response.statusCode == 200) {
        Map<String, dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return List<String>.from(body['relation_ids']);
    } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['message'] ?? 'İlişki bulunamadı');
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransactionablePersons(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/transactionable'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.cast<Map<String, dynamic>>();
    } else {
      throw Exception('İşlem yapılacak kişiler yüklenemedi');
    }
  }

  Future<void> addInternalConnection(
      String token, String identifier, String relationType) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/internal'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'target_user_identifier': identifier,
        'relation_type': relationType,
      }),
    );
    if (response.statusCode != 201) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Dahili bağlantı eklenemedi');
    }
  }

  Future<void> addExternalConnection(
      String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/external'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Harici bağlantı eklenemedi');
    }
  }

  Future<void> updateExternalUser(String token, String externalUserId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/external/$externalUserId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Harici kullanıcı güncellenemedi');
    }
  }

  Future<void> deleteConnection(String token, String relationId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/$relationId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Bağlantı silinemedi');
    }
  }

  Future<void> updateConnectionSettings(String token, String relationId, Map<String, dynamic> settings) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/$relationId/settings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(settings),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? 'Ayarlar güncellenemedi');
    }
  }
}