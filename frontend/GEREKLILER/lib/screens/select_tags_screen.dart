import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:frontend/models/connection.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:frontend/providers/tag_provider.dart';
import 'package:provider/provider.dart';

class SelectTagsScreen extends StatefulWidget {
  final Connection connection;
  const SelectTagsScreen({super.key, required this.connection});

  @override
  State<SelectTagsScreen> createState() => _SelectTagsScreenState();
}

class _SelectTagsScreenState extends State<SelectTagsScreen> {
  Future<void>? _fetchData;
  Set<String> _selectedTagIds = {};
  bool _isLoading = false;
  bool _isInitialDataLoaded = false; // YENİ: Verinin ilk kez yüklendiğini takip eden bayrak

  @override
  void initState() {
    super.initState();
    // Build tamamlandıktan sonra veri yüklemeyi başlat
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _fetchData = _loadInitialData();
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadInitialData() async {
    // Bu fonksiyon artık setState çağırmıyor, sadece veri çekiyor.
    final tagProvider = Provider.of<TagProvider>(context, listen: false);
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    
    // Mevcut tüm etiketleri ve bu bağlantıya atanmış olanları paralel olarak getir
    await Future.wait([
        tagProvider.fetchTags(),
        connectionProvider.fetchTagsForConnection(widget.connection.relationId)
    ]);
  }

  Future<void> _saveSelection() async {
    setState(() => _isLoading = true);
    try {
        await Provider.of<ConnectionProvider>(context, listen: false).syncTagsForConnection(
            widget.connection.relationId, 
            _selectedTagIds.toList()
        );
        if(mounted) Navigator.of(context).pop();
    } catch (e) {
        if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Hata: ${e.toString()}'),
                backgroundColor: Colors.red,
            ));
        }
    } finally {
        if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("'${widget.connection.displayName}' için Etiket Seç"),
        actions: [
          if (_isLoading) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
          else IconButton(onPressed: _saveSelection, icon: const Icon(Icons.save), tooltip: 'Kaydet'),
        ],
      ),
      body: _fetchData == null 
        ? const Center(child: CircularProgressIndicator())
        : FutureBuilder(
            future: _fetchData,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Veri yüklenemedi: ${snapshot.error}'));
              }

          // Veri başarıyla çekildikten sonra, provider'ları dinleyerek arayüzü çiz.
          final connectionProvider = Provider.of<ConnectionProvider>(context);
          final tagProvider = Provider.of<TagProvider>(context);

          // HATA DÜZELTMESİ: Yerel state'i (_selectedTagIds) provider'dan gelen veriyle
          // sadece ilk yüklemede senkronize et.
          if (!_isInitialDataLoaded) {
              _selectedTagIds = connectionProvider.assignedTags.map((t) => t.tagId).toSet();
              _isInitialDataLoaded = true;
          }

          if (tagProvider.tags.isEmpty) {
            return const Center(child: Text('Henüz hiç etiket oluşturulmamış.'));
          }

          return ListView.builder(
            itemCount: tagProvider.tags.length,
            itemBuilder: (ctx, index) {
              final Tag tag = tagProvider.tags[index];
              final bool isSelected = _selectedTagIds.contains(tag.tagId);
              return CheckboxListTile(
                title: Text(tag.name),
                subtitle: tag.note != null && tag.note!.isNotEmpty ? Text(tag.note!) : null,
                value: isSelected,
                onChanged: (bool? value) {
                  // Kullanıcı etkileşimiyle yerel state'i güncelle.
                  setState(() {
                    if (value == true) {
                      _selectedTagIds.add(tag.tagId);
                    } else {
                      _selectedTagIds.remove(tag.tagId);
                    }
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}