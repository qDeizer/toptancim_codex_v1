import 'package:flutter/material.dart';
import 'package:frontend/models/connection.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:frontend/screens/add_connection_screen.dart';
import 'package:frontend/screens/person_profile_screen.dart';
import 'package:frontend/widgets/connection_settings_dialog.dart';
import 'package:frontend/services/image_service.dart';
import 'package:provider/provider.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});
  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ConnectionProvider>(context, listen: false).fetchConnections();
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bağlantılarım'),
      ),
      body: Consumer<ConnectionProvider>(
        builder: (ctx, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (provider.allConnections.isEmpty) {
            return const Center(child: Text('Henüz bağlantı eklenmemiş.'));
          }
          return RefreshIndicator(
            onRefresh: () => provider.fetchConnections(),
            child: ListView.builder(
              itemCount: provider.allConnections.length,
              itemBuilder: (ctx, i) {
                final Connection connection = provider.allConnections[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: connection.profilFotografi != null
                      ? NetworkImage(ImageService.getFullImageUrl(connection.profilFotografi!))
                      : null,
                    child: connection.profilFotografi == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(connection.displayName),
                  subtitle: Row(
                    children: [
                      Text(connection.roleAsTurkish),
                      if (!connection.isInternal) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text('Harici'),
                          backgroundColor: Colors.red.shade100,
                          labelStyle: TextStyle(color: Colors.red.shade900, fontSize: 10),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          side: BorderSide.none,
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PersonProfileScreen(relationId: connection.relationId),
                      ),
                    );
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                         if (value == 'edit') {
                            showDialog(
                              context: context,
                              builder: (_) => ConnectionSettingsDialog(connection: connection),
                            );
                         } else if (value == 'delete') {
                            showDialog(
                               context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  title: const Text('Emin misiniz?'),
                                    content: Text('\'${connection.displayName}\' adlı bağlantıyı silmek üzeresiniz. Bu işlem geri alınamaz.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('İptal')),
                                        TextButton(
                                          onPressed: () async {
                                                try {
                                                  await provider.deleteConnection(connection.relationId);
                                                } catch (e) {
                                                  _showErrorSnackBar('Bağlantı silinemedi: ${e.toString()}');
                                                }
                                                 if (context.mounted) Navigator.of(dialogCtx).pop();
                                          },
                                            child: const Text('Sil', style: TextStyle(color: Colors.red)),
                                        ),
                                    ],
                                ),
                            );
                          }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(leading: Icon(Icons.edit), title: Text('Düzenle')),
                        ),
                        const PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(leading: Icon(Icons.delete), title: Text('Sil')),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddConnectionScreen()),
        ).then((_) => Provider.of<ConnectionProvider>(context, listen: false).fetchConnections() ),
        tooltip: 'Bağlantı Ekle', // Geri dönüldüğünde listeyi yenile
        child: const Icon(Icons.add),
      ),
    );
  }
}