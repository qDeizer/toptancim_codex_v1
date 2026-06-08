import 'package:flutter/material.dart';
import '../models/connection.dart';
import '../models/tag.dart';
import '../models/connection_details.dart';
import '../services/connection_service.dart';
import '../services/tag_assignment_service.dart';
class ConnectionProvider with ChangeNotifier {
  List<Connection> _customers = [];
  List<Connection> _wholesalers = [];
  final String? _token;
  bool _isLoading = false;
  final ConnectionService _connectionService = ConnectionService();
  final TagAssignmentService _assignmentService = TagAssignmentService(); // YENİ
  List<Tag> _assignedTags = []; // YENİ

  ConnectionProvider(this._token);

  List<Connection> get allConnections => [..._wholesalers, ..._customers];
  List<Tag> get assignedTags => _assignedTags; // YENİ
  bool get isLoading => _isLoading;

  Future<void> fetchConnections() async {
    if (_token == null) return;
    _isLoading = true;
notifyListeners();
    try {
      final connections = await _connectionService.fetchConnections(_token);
      _customers = connections['customers'] ?? [];
_wholesalers = connections['wholesalers'] ?? [];
    } catch (e) {
      print(e);
}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addInternalConnection(String identifier, String relationType) async {
    if (_token == null) throw Exception('Yetkilendirme tokenı bulunamadı.');
try {
      await _connectionService.addInternalConnection(_token, identifier, relationType);
      await fetchConnections();
} catch (e) {
      rethrow;
}
  }

  Future<void> addExternalConnection(Map<String, dynamic> data) async {
    if (_token == null) throw Exception('Yetkilendirme tokenı bulunamadı.');
try {
      await _connectionService.addExternalConnection(_token, data);
      await fetchConnections();
} catch (e) {
      rethrow;
}
  }

  Future<void> deleteConnection(String relationId) async {
    if (_token == null) throw Exception('Yetkilendirme tokenı bulunamadı.');
final originalConnections = allConnections;
    _customers.removeWhere((c) => c.relationId == relationId);
    _wholesalers.removeWhere((w) => w.relationId == relationId);
    notifyListeners();
try {
      await _connectionService.deleteConnection(_token, relationId);
} catch (e) {
      _customers = originalConnections.where((c) => c.relationRole == 'customer').toList();
_wholesalers = originalConnections.where((c) => c.relationRole == 'wholesaler').toList();
      notifyListeners();
      rethrow;
    }
  }

  // YENİ METOTLAR
  Future<void> fetchTagsForConnection(String relationId) async {
    if (_token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _assignedTags = await _assignmentService.getTagsForConnection(_token, relationId);
    } catch (e) {
      print('Error fetching tags for connection: $e');
      _assignedTags = []; // Hata durumunda listeyi boşalt
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncTagsForConnection(String relationId, List<String> tagIds) async {
    if (_token == null) throw Exception('Yetkilendirme tokenı bulunamadı.');
    try {
      final updatedTags = await _assignmentService.syncTagsForConnection(_token, relationId, tagIds);
      _assignedTags = updatedTags;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<ConnectionDetails> fetchConnectionDetails(String relationId) async {
    if (_token == null) throw Exception('Yetkilendirme tokenı bulunamadı.');
    return await _connectionService.fetchConnectionDetails(_token, relationId);
  }

  Future<void> updateConnectionSettings(String relationId, Map<String, dynamic> settings) async {
    if (_token == null) throw Exception('Yetkilendirme tokenı bulunamadı.');
     try {
      await _connectionService.updateConnectionSettings(_token, relationId, settings);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}