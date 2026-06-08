import 'package:flutter/material.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/connection_service.dart';
import 'package:frontend/services/image_service.dart';
import 'package:provider/provider.dart';

class SelectPersonScreen extends StatefulWidget {
  const SelectPersonScreen({super.key});

  @override
  State<SelectPersonScreen> createState() => _SelectPersonScreenState();
}

class _SelectPersonScreenState extends State<SelectPersonScreen> {
  late Future<List<Map<String, dynamic>>> _personsFuture;
  final ConnectionService _connectionService = ConnectionService();

  @override
  void initState() {
    super.initState();
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      _personsFuture = _connectionService.fetchTransactionablePersons(token);
    } else {
      // Token yoksa, hata ile tamamlanan bir Future ata.
      _personsFuture = Future.error('Yetkilendirme bulunamadı.');
    }
  }

  String _getDisplayName(Map<String, dynamic> person) {
    final isletmeIsmi = person['isletme_ismi'];
    if (isletmeIsmi != null && isletmeIsmi.isNotEmpty) {
      return isletmeIsmi;
    }
    final ad = person['ad'] ?? '';
    final soyad = person['soyad'] ?? '';
    return '$ad $soyad'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişi Seç'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _personsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Kişiler yüklenemedi: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('İşlem yapılacak kişi bulunamadı.'),
            );
          }

          final persons = snapshot.data!;

          return ListView.builder(
            itemCount: persons.length,
            itemBuilder: (ctx, index) {
              final person = persons[index];
              final displayName = _getDisplayName(person);
              final photoUrl = person['profil_fotografi'];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: photoUrl != null
                      ? NetworkImage(ImageService.getFullImageUrl(photoUrl))
                      : null,
                  child: photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(displayName),
                onTap: () {
                  // Seçilen kişi map'ini bir önceki sayfaya döndür
                  Navigator.of(context).pop(person);
                },
              );
            },
          );
        },
      ),
    );
  }
}