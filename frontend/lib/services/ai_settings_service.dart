import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_settings.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class AiSettingsService {
  Future<AiSettings> fetchSettings(String token) async {
    AppLogger.info('AI settings service fetch started');
    final response = await http.get(
      Uri.parse('${Constants.baseUrl}/ai/settings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      AppLogger.warning(
        'AI settings service fetch failed: status=${response.statusCode}',
        error,
      );
      throw Exception(error['error'] ?? 'AI ayarlari yuklenemedi.');
    }

    AppLogger.info('AI settings service fetch completed');
    return AiSettings.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
  }

  Future<AiSettings> updateSettings(String token, AiSettings settings) async {
    AppLogger.info(
      'AI settings service update started: strategy=${settings.strategy}, providerCount=${settings.providers.length}',
    );
    final response = await http.put(
      Uri.parse('${Constants.baseUrl}/ai/settings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(settings.toJson()),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      AppLogger.warning(
        'AI settings service update failed: status=${response.statusCode}',
        error,
      );
      throw Exception(error['error'] ?? 'AI ayarlari kaydedilemedi.');
    }

    AppLogger.info('AI settings service update completed');
    return AiSettings.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
  }
}
