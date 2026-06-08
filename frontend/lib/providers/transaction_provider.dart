import 'package:flutter/material.dart';
import 'package:frontend/providers/auth_provider.dart';

import '../models/financial_summary.dart';
import '../models/financial_transaction.dart';
import '../services/transaction_service.dart';
import '../utils/logger.dart';

class TransactionProvider with ChangeNotifier {
  final String? _token;
  final String? _userId;
  final TransactionService _transactionService = TransactionService();
  List<FinancialTransaction> _transactions = [];
  FinancialSummary _summary = FinancialSummary.initial();
  bool _isLoading = false;
  String? _error;

  TransactionProvider(AuthProvider? authProvider)
      : _token = authProvider?.token,
        _userId = authProvider?.userId;

  List<FinancialTransaction> get transactions => [..._transactions];
  FinancialSummary get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> addTransaction(Map<String, dynamic> transactionData) async {
    if (_token == null) {
      throw Exception("Yetkilendirme token'i bulunamadi.");
    }

    AppLogger.info(
      'Transaction provider add started: personId=${transactionData['person_id'] ?? "none"}',
    );

    final payload = Map<String, dynamic>.from(transactionData);
    payload['frontend_type'] = (payload['type'] as DisplayTransactionType).name;
    payload.remove('type');

    try {
      await _transactionService.addTransaction(_token, payload);
      await fetchAllFinancialData();
      AppLogger.info('Transaction provider add completed');
    } catch (error, stackTrace) {
      AppLogger.error('Transaction provider add failed', error, stackTrace);
      rethrow;
    }
  }

  Future<void> fetchAllFinancialData() async {
    if (_token == null || _userId == null) {
      _error = "Yetkilendirme token'i veya kullanici ID'si bulunamadi.";
      AppLogger.warning(
        'Transaction provider fetch blocked due to missing auth or userId',
      );
      notifyListeners();
      return;
    }

    AppLogger.info('Transaction provider fetchAllFinancialData started');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _transactionService.fetchTransactions(_token),
        _transactionService.fetchSummary(_token),
      ]);

      final rawTransactions = results[0] as List<Map<String, dynamic>>;
      _transactions = rawTransactions
          .map((tx) => FinancialTransaction.fromApi(tx, _userId))
          .toList();
      _summary = results[1] as FinancialSummary;

      AppLogger.info(
        'Transaction provider fetchAllFinancialData completed: transactionCount=${_transactions.length}',
      );
    } catch (error, stackTrace) {
      _error = error.toString();
      AppLogger.error(
        'Transaction provider fetchAllFinancialData failed',
        error,
        stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (_token == null) {
      throw Exception("Yetkilendirme token'i bulunamadi.");
    }

    final existingIndex =
        _transactions.indexWhere((tx) => tx.id == transactionId);
    if (existingIndex == -1) {
      return;
    }

    final transactionToDelete = _transactions[existingIndex];
    _transactions.removeAt(existingIndex);
    notifyListeners();

    try {
      await _transactionService.deleteTransaction(_token, transactionId);
      await fetchAllFinancialData();
    } catch (error) {
      _transactions.insert(existingIndex, transactionToDelete);
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> respondToTransaction(
    String transactionId,
    String response,
  ) async {
    if (_token == null) {
      return;
    }

    try {
      await _transactionService.respondToTransaction(
        _token,
        transactionId,
        response,
      );
      await fetchAllFinancialData();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> cancelTransaction(String transactionId) async {
    if (_token == null) {
      return;
    }

    try {
      await _transactionService.cancelTransaction(_token, transactionId);
      await fetchAllFinancialData();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> requestCancel(String transactionId) async {
    if (_token == null) {
      return;
    }

    try {
      await _transactionService.requestCancel(_token, transactionId);
      await fetchAllFinancialData();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> respondToCancelRequest(
    String transactionId,
    String response,
  ) async {
    if (_token == null) {
      return;
    }

    try {
      await _transactionService.respondToCancelRequest(
        _token,
        transactionId,
        response,
      );
      await fetchAllFinancialData();
    } catch (error) {
      rethrow;
    }
  }
}
