import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:frontend/models/connection.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/providers/tag_assignment_provider.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:provider/provider.dart';

class AssignedConnectionsScreen extends StatefulWidget {
  final Tag tag;
  const AssignedConnectionsScreen({super.key, required this.tag});

  @override
  State<AssignedConnectionsScreen> createState() =>
      _AssignedConnectionsScreenState();
}

class _AssignedConnectionsScreenState extends State<AssignedConnectionsScreen> {
  Future<void>? _fetchConnectionsFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Build tamamlandıktan sonra veri yüklemeyi başlat
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final tagAssignmentProvider = Provider.of<TagAssignmentProvider>(context, listen: false);
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    
    _fetchConnectionsFuture = Future.wait([
      tagAssignmentProvider.getConnectionsForTag(widget.tag.tagId),
      connectionProvider.fetchConnections(),
    ]);
    
    if (mounted) setState(() {});
  }

  void _showAddConnectionDialog() {
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    final tagAssignmentProvider = Provider.of<TagAssignmentProvider>(context, listen: false);
    
    // Mevcut atanmış bağlantıların ID'lerini al - null kontrolü ekle
    final assignedConnectionIds = tagAssignmentProvider.assignedConnections
        .where((c) => c.relationId.isNotEmpty)
        .map((c) => c.relationId)
        .toSet();
    
    // Atanmamış bağlantıları filtrele - null kontrolü ekle
    final availableConnections = connectionProvider.allConnections
        .where((c) => c.relationId.isNotEmpty && !assignedConnectionIds.contains(c.relationId))
        .toList();

    if (availableConnections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eklenebilecek bağlantı bulunamadı.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bağlantı Ekle'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: availableConnections.length,
            itemBuilder: (ctx, index) {
              final connection = availableConnections[index];
              return ListTile(
                title: Text(connection.displayName),
                subtitle: Text(connection.roleAsTurkish),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  if (connection.relationId.isNotEmpty) {
                    await _assignTagToConnection(connection.relationId);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  void _showRemoveConnectionDialog() {
    final tagAssignmentProvider = Provider.of<TagAssignmentProvider>(context, listen: false);
    
    if (tagAssignmentProvider.assignedConnections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çıkarılacak bağlantı bulunamadı.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bağlantı Çıkar'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: tagAssignmentProvider.assignedConnections.length,
            itemBuilder: (ctx, index) {
              final connection = tagAssignmentProvider.assignedConnections[index];
              return ListTile(
                title: Text(connection.displayName),
                subtitle: Text(connection.roleAsTurkish),
                trailing: const Icon(Icons.remove_circle, color: Colors.red),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _removeTagFromConnection(connection.relationId!);
                                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignTagToConnection(String relationId) async {
    setState(() => _isLoading = true);
    try {
      // Backend'e tag atama isteği gönder
      await _assignTagToConnectionBackend(relationId);
      // Veriyi yenile
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etiket başarıyla atandı.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeTagFromConnection(String relationId) async {
    setState(() => _isLoading = true);
    try {
      // Backend'e tag çıkarma isteği gönder
      await _removeTagFromConnectionBackend(relationId);
      // Veriyi yenile
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etiket başarıyla çıkarıldı.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignTagToConnectionBackend(String relationId) async {
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    // Mevcut etiketleri al ve yeni etiketi ekle
    await connectionProvider.fetchTagsForConnection(relationId);
    final currentTagIds = connectionProvider.assignedTags.map((t) => t.tagId).toList();
    if (!currentTagIds.contains(widget.tag.tagId)) {
      currentTagIds.add(widget.tag.tagId);
      await connectionProvider.syncTagsForConnection(relationId, currentTagIds);
    }
  }

  Future<void> _removeTagFromConnectionBackend(String relationId) async {
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    // Mevcut etiketleri al ve bu etiketi çıkar
    await connectionProvider.fetchTagsForConnection(relationId);
    final currentTagIds = connectionProvider.assignedTags.map((t) => t.tagId).toList();
    currentTagIds.remove(widget.tag.tagId);
    await connectionProvider.syncTagsForConnection(relationId, currentTagIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("'${widget.tag.name}' Etiketli Bağlantılar"),
        actions: [
          if (_isLoading) 
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else ...[
            IconButton(
              onPressed: _showAddConnectionDialog, 
              icon: const Icon(Icons.add, color: Colors.green), 
              tooltip: 'Kişi Ekle'
            ),
            IconButton(
              onPressed: _showRemoveConnectionDialog, 
              icon: const Icon(Icons.remove, color: Colors.red), 
              tooltip: 'Kişi Çıkar'
            ),
          ],
        ],
      ),
      body: _fetchConnectionsFuture == null
        ? const Center(child: CircularProgressIndicator())
        : FutureBuilder(
            future: _fetchConnectionsFuture,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
              }

          return Consumer<TagAssignmentProvider>(
            builder: (ctx, provider, _) {
              if (provider.assignedConnections.isEmpty) {
                return const Center(
                  child: Text('Bu etikete atanmış kimse bulunamadı.'),
                );
              }
              return ListView.builder(
                itemCount: provider.assignedConnections.length,
                itemBuilder: (ctx, i) {
                  final Connection connection = provider.assignedConnections[i];
                  return ListTile(
                    title: Text(connection.displayName),
                    subtitle: Text(connection.roleAsTurkish),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}