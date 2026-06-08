import 'dart:async';
import 'dart:convert';

import 'package:frontend/models/financial_summary.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/logger.dart';

class TransactionService {
  final String _baseUrl = '${Constants.baseUrl}/transactions';
  static const Duration _requestTimeout = Duration(seconds: 20);

  Future<void> addTransaction(
    String token,
    Map<String, dynamic> transactionData,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      AppLogger.info(
        'Transaction service add started: personId=${transactionData['person_id'] ?? "none"}, category=${transactionData['category'] ?? "unknown"}',
      );
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: Helpers.getHeaders(token),
            body: json.encode({
              'frontend_type': transactionData['frontend_type'],
              'person_id': transactionData['person_id'],
              'amount': transactionData['amount'],
              'currency': transactionData['currency'],
              'payment_method': transactionData['payment_method'],
              'description': transactionData['description'],
              'transaction_date':
                  (transactionData['transaction_date'] as DateTime)
                      .toIso8601String(),
              'proof_image_url': transactionData['proof_image_url'],
              'reference_id': transactionData['reference_id'],
              'reference_type': transactionData['reference_type'],
              'category': transactionData['category'],
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 201) {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        AppLogger.warning(
          'Transaction service add failed: status=${response.statusCode}, durationMs=${stopwatch.elapsedMilliseconds}',
          error,
        );
        throw Exception(error['message'] ?? 'Finansal islem olusturulamadi');
      }

      AppLogger.info(
        'Transaction service add completed: durationMs=${stopwatch.elapsedMilliseconds}',
      );
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warning(
        'Transaction service add timed out after ${_requestTimeout.inSeconds}s',
        error,
        stackTrace,
      );
      throw Exception('Finansal islem kaydedilirken zaman asimi olustu.');
    } catch (error, stackTrace) {
      AppLogger.error('Transaction service add crashed', error, stackTrace);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransactions(String token) async {
    final stopwatch = Stopwatch()..start();

    try {
      AppLogger.info('Transaction service list started');
      final response = await http
          .get(
            Uri.parse(_baseUrl),
            headers: Helpers.getHeaders(token),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        AppLogger.info(
          'Transaction service list completed: count=${body.length}, durationMs=${stopwatch.elapsedMilliseconds}',
        );
        return body.cast<Map<String, dynamic>>();
      }

      final error = jsonDecode(utf8.decode(response.bodyBytes));
      AppLogger.warning(
        'Transaction service list failed: status=${response.statusCode}, durationMs=${stopwatch.elapsedMilliseconds}',
        error,
      );
      throw Exception(error['message'] ?? 'Finansal islemler getirilemedi.');
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warning(
        'Transaction service list timed out after ${_requestTimeout.inSeconds}s',
        error,
        stackTrace,
      );
      throw Exception('Finansal islemler yuklenirken zaman asimi olustu.');
    } catch (error, stackTrace) {
      AppLogger.error('Transaction service list crashed', error, stackTrace);
      rethrow;
    }
  }

  Future<FinancialSummary> fetchSummary(String token) async {
    final stopwatch = Stopwatch()..start();

    try {
      AppLogger.info('Transaction service summary started');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/summary'),
            headers: Helpers.getHeaders(token),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        AppLogger.info(
          'Transaction service summary completed: durationMs=${stopwatch.elapsedMilliseconds}',
        );
        return FinancialSummary.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      }

      final error = jsonDecode(utf8.decode(response.bodyBytes));
      AppLogger.warning(
        'Transaction service summary failed: status=${response.statusCode}, durationMs=${stopwatch.elapsedMilliseconds}',
        error,
      );
      throw Exception(error['message'] ?? 'Finansal ozet getirilemedi.');
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warning(
        'Transaction service summary timed out after ${_requestTimeout.inSeconds}s',
        error,
        stackTrace,
      );
      throw Exception('Finansal ozet yuklenirken zaman asimi olustu.');
    } catch (error, stackTrace) {
      AppLogger.error('Transaction service summary crashed', error, stackTrace);
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
        throw Exception(error['message'] ?? 'Islem silinemedi.');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> respondToTransaction(
    String token,
    String transactionId,
    String response,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/$transactionId/respond'),
        headers: Helpers.getHeaders(token),
        body: json.encode({'response': response}),
      );
      if (res.statusCode != 200) {
        final error = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(error['message'] ?? 'Islem yanitlanamadi.');
      }
    } catch (error) {
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
        throw Exception(error['message'] ?? 'Islem iptal edilemedi.');
      }
    } catch (error) {
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
        throw Exception(error['message'] ?? 'Iptal talebi olusturulamadi.');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> respondToCancelRequest(
    String token,
    String transactionId,
    String response,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/$transactionId/cancel-respond'),
        headers: Helpers.getHeaders(token),
        body: json.encode({'response': response}),
      );
      if (res.statusCode != 200) {
        final error = jsonDecode(utf8.decode(res.bodyBytes));
        throw Exception(error['message'] ?? 'Talep yanitlanamadi.');
      }
    } catch (error) {
      rethrow;
    }
  }
}
