import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media.dart';
import '../utils/constants.dart';

class MediaService {
  static String get baseUrl => Constants.baseUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    if (token == null) throw Exception('Token bulunamadı');
    return {'Authorization': 'Bearer $token'};
  }

  Future<List<MediaItem>> fetchMedia() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/media'), headers: headers);
    if (res.statusCode != 200) throw Exception('Medya listesi alınamadı');
    final List data = json.decode(res.body);
    return data.map((j) => MediaItem.fromJson(j)).toList();
  }

  Future<MediaItem> uploadMedia(List<int> bytes, String filename) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token bulunamadı');
    final uri = Uri.parse('$baseUrl/media/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('media', bytes, filename: filename));
    final res = await request.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 201) throw Exception(json.decode(body)['message'] ?? 'Yükleme başarısız');
    return MediaItem.fromJson(json.decode(body));
  }

  Future<MediaItem?> toggleFavorite(String mediaId) async {
    final headers = await _authHeaders();
    final res = await http.patch(Uri.parse('$baseUrl/media/$mediaId/favorite'), headers: headers);
    if (res.statusCode != 200) return null;
    return MediaItem.fromJson(json.decode(res.body));
  }

  Future<void> deleteMedia(String mediaId) async {
    final headers = await _authHeaders();
    final res = await http.delete(Uri.parse('$baseUrl/media/$mediaId'), headers: headers);
    if (res.statusCode != 200) throw Exception('Silme başarısız');
  }

  // AI görsel oluşturma
  Future<List<MediaItem>> generateAiImages({
    required String prompt,
    int n = 1,
    String quality = 'low',
    String size = '1024x1024',
    List<String>? referenceMediaIds,
  }) async {
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';
    final body = json.encode({
      'prompt': prompt,
      'n': n,
      'quality': quality,
      'size': size,
      'reference_media_ids': referenceMediaIds ?? [],
    });
    final res = await http.post(
      Uri.parse('$baseUrl/media/generate-ai'),
      headers: headers,
      body: body,
    );
    final data = json.decode(res.body);
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'AI görsel oluşturulamadı');
    final images = data['images'] as List;
    return images.map((j) => MediaItem.fromJson(j)).toList();
  }
}

