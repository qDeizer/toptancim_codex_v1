import 'package:flutter/material.dart';
import 'package:frontend/providers/auth_provider.dart';
import '../models/financial_summary.dart';
import '../models/financial_transaction.dart';
import '../services/transaction_service.dart';

class TransactionProvider with ChangeNotifier {
  final String? _token;
  final String? _userId; // YENİ
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
    if (_token == null) throw Exception('Yetkilendirme token\'ı bulunamadı.');
    
    // Frontend_type'ı backend'in beklediği string formatına çevir
    final Map<String, dynamic> payload = Map.from(transactionData);
    payload['frontend_type'] = (payload['type'] as DisplayTransactionType).name;
    payload.remove('type');


    try {
      await _transactionService.addTransaction(_token, payload);
      await fetchAllFinancialData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchAllFinancialData() async {
    if (_token == null || _userId == null) {
        _error = "Yetkilendirme token'ı veya kullanıcı ID'si bulunamadı.";
        notifyListeners();
        return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _transactionService.fetchTransactions(_token),
        _transactionService.fetchSummary(_token),
      ]);

      final rawTransactions = results[0] as List<Map<String, dynamic>>;
      _transactions = rawTransactions.map((tx) => FinancialTransaction.fromApi(tx, _userId)).toList();
      _summary = results[1] as FinancialSummary;
    } catch (e) {
      print("fetchAllFinancialData provider error: $e");
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (_token == null) throw Exception('Yetkilendirme token\'ı bulunamadı.');

    final existingIndex = _transactions.indexWhere((tx) => tx.id == transactionId);
    if (existingIndex == -1) return;

    final transactionToDelete = _transactions[existingIndex];
    _transactions.removeAt(existingIndex);
    notifyListeners();

    try {
      await _transactionService.deleteTransaction(_token, transactionId);
      // Başarılı olursa, özet verisini de yenile
      await fetchAllFinancialData();
    } catch (e) {
      // Hata olursa, silinen işlemi geri ekle ve hatayı göster
      _transactions.insert(existingIndex, transactionToDelete);
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> respondToTransaction(String transactionId, String response) async {
    if (_token == null) return;
    try {
      await _transactionService.respondToTransaction(_token, transactionId, response);
      await fetchAllFinancialData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelTransaction(String transactionId) async {
    if (_token == null) return;
    try {
      await _transactionService.cancelTransaction(_token, transactionId);
      await fetchAllFinancialData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> requestCancel(String transactionId) async {
    if (_token == null) return;
    try {
      await _transactionService.requestCancel(_token, transactionId);
      await fetchAllFinancialData();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> respondToCancelRequest(String transactionId, String response) async {
    if (_token == null) return;
    try {
      await _transactionService.respondToCancelRequest(_token, transactionId, response);
      await fetchAllFinancialData();
    } catch (e) {
      rethrow;
    }
  }
}