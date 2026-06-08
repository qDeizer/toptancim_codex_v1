import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  final AuthService _authService = AuthService();
  bool _isAuthCheckComplete = false;

  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isAuthCheckComplete => _isAuthCheckComplete;
  
  String? get userId {
    if (_token == null) return null;
    try {
      final parts = _token!.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> payloadMap = json.decode(decoded);
      if (payloadMap.containsKey('user') && payloadMap['user'] is Map) {
         return payloadMap['user']['id']?.toString();
      }
      return null;
    } catch (e) {
      print('Error decoding token: $e');
      return null;
    }
  }

  AuthProvider() {
    tryAutoLogin();
  }

  Future<void> tryAutoLogin() async {
    final storedToken = await _authService.getToken();
    if (storedToken != null) {
      _token = storedToken;
    }
    _isAuthCheckComplete = true;
    notifyListeners();
  }
  
  Future<void> login(String loginIdentifier, String password) async {
    try {
      _token = await _authService.login(loginIdentifier, password);
      notifyListeners();
    } catch (e) {
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
       await _authService.register(
         userName: userName,
         isletmeIsmi: isletmeIsmi,
         ad: ad,
         soyad: soyad,
         telNo: telNo,
         email: email,
         password: password,
         hakkinda: hakkinda,
         address_info: address_info,
       );
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> logout() async {
    _token = null;
    await _authService.logout();
    notifyListeners();
  }
}