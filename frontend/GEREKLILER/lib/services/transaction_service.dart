import 'package:frontend/models/financial_summary.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class TransactionService {
  final String _baseUrl = '${Constants.baseUrl}/transactions';

  Future<void> addTransaction(String token, Map<String, dynamic> transactionData) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: Helpers.getHeaders(token),
        body: json.encode({
            'frontend_type': transactionData['frontend_type'],
            'person_id': transactionData['person_id'], // null olabilir
            'amount': transactionData['amount'],
            'currency': transactionData['currency'],
            'payment_method': transactionData['payment_method'], // null olabilir
            'description': transactionData['description'],
            'transaction_date': (transactionData['transaction_date'] as DateTime).toIso8601String(),
            'proof_image_url': transactionData['proof_image_url'],
            'reference_id': transactionData['reference_id'],
            'reference_type': transactionData['reference_type'],
            'category': transactionData['category'],
        }),
      );
      if (response.statusCode != 201) {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['message'] ?? 'Finansal işlem oluşturulamadı');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransactions(String token) async {
    try {
        final response = await http.get(
            Uri.parse(_baseUrl),
            headers: Helpers.getHeaders(token),
         );
        if (response.statusCode == 200) {
            List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
            return body.cast<Map<String, dynamic>>();
        } else {
            final error = jsonDecode(utf8.decode(response.bodyBytes));
            throw Exception(error['message'] ?? 'Finansal işlemler getirilemedi.');
        }
    } catch (e) {
        rethrow;
    }
  }
  
  Future<FinancialSummary> fetchSummary(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/summary'),
        headers: Helpers.getHeaders(token),
      );
      if (response.statusCode == 200) {
        return FinancialSummary.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['message'] ?? 'Finansal özet getirilemedi.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTransaction(String token, String transactionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/$transactionId'),
        headers: Helpers.getHeaders(token),
      );
      if (response.statusCode != 200) {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['message'] ?? 'İşlem silinemedi.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> respondToTransaction(String token, String transactionId, String response) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/$transactionId/respond'),
        headers: Helpers.getHeaders(token),
        body: json.encode({'response': response}),
      );
      if (res.statusCode != 200) {
        final error = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(error['message'] ?? 'İşlem yanıtlanamadı.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelTransaction(String token, String transactionId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/$transactionId/cancel'),
        headers: Helpers.getHeaders(token),
      );
      if (res.statusCode != 200) {
        final error = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(error['message'] ?? 'İşlem iptal edilemedi.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> requestCancel(String token, String transactionId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/$transactionId/cancel-request'),
        headers: Helpers.getHeaders(token),
      );
      if (res.statusCode != 200) {
        final error = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(error['message'] ?? 'İptal talebi oluşturulamadı.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> respondToCancelRequest(String token, String transactionId, String response) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/$transactionId/cancel-respond'),
        headers: Helpers.getHeaders(token),
        body: json.encode({'response': response}),
      );
      if (res.statusCode != 200) {
        final error = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(error['message'] ?? 'Talep yanıtlanamadı.');
      }
    } catch (e) {
      rethrow;
    }
  }
}