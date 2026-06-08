import 'package:flutter/material.dart';
import '../models/connection.dart';
import '../models/tag.dart';
import '../services/tag_assignment_service.dart';

class TagAssignmentProvider with ChangeNotifier {
  final String? _token;
  final TagAssignmentService _service = TagAssignmentService();
  
  List<Connection> _assignedConnections = [];
  final List<Tag> _assignedTags = [];
  bool _isLoading = false;

  TagAssignmentProvider(this._token);

  List<Connection> get assignedConnections => _assignedConnections;
  List<Tag> get assignedTags => _assignedTags;
  bool get isLoading => _isLoading;

  Future<void> getConnectionsForTag(String tagId) async {
    if (_token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _assignedConnections = await _service.getConnectionsForTag(_token, tagId);
    } catch (e) {
      print('Error fetching connections for tag: $e');
      _assignedConnections = [];
    }
    _isLoading = false;
    notifyListeners();
  }
}