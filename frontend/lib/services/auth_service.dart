import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  Future<String> login(String loginIdentifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'loginIdentifier': loginIdentifier,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final token = jsonDecode(response.body)['token'];
        await _saveToken(token);
        return token;
      } else if (response.statusCode == 404) {
        throw Exception('Kullanıcı bulunamadı.');
      } else if (response.statusCode == 401) {
        throw Exception('Şifre hatalı.');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Giriş başarısız: ${errorData['message'] ?? 'Bilinmeyen hata'}');
      }
    } catch (e) {
      if (e.toString().contains('Failed to fetch')) {
        throw Exception('Sunucuya bağlanılamıyor. İnternet bağlantınızı kontrol edin.');
      }
      rethrow;
    }
  }

  Future<void> register({
    required String userName,
    required String isletmeIsmi,
    required String ad,
    required String soyad,
    required String telNo,
    required String email,
    required String password,
    String? hakkinda,
    required Map<String, dynamic> address_info,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_name': userName,
          'isletme_ismi': isletmeIsmi,
          'ad': ad,
          'soyad': soyad,
          'tel_no': telNo,
          'email': email,
          'password': password,
          'hakkinda': hakkinda,
          'address_info': address_info,
        }),
      );

      if (response.statusCode != 201) {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['message'] ?? 'Kayıt başarısız');
      }
    } catch (e) {
      if (e.toString().contains('Failed to fetch')) {
        throw Exception('Sunucuya bağlanılamıyor. Backend sunucusunun çalıştığından emin olun.');
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
}