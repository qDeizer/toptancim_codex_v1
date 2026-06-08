import 'package:flutter/material.dart';
import 'package:frontend/models/connection.dart';
import 'package:frontend/models/connection_details.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:frontend/screens/select_tags_screen.dart';
import 'package:provider/provider.dart';

class ConnectionSettingsDialog extends StatefulWidget {
  final Connection connection;

  const ConnectionSettingsDialog({super.key, required this.connection});

  @override
  State<ConnectionSettingsDialog> createState() => _ConnectionSettingsDialogState();
}

class _ConnectionSettingsDialogState extends State<ConnectionSettingsDialog> {
  late Future<ConnectionDetails> _fetchDetailsFuture;
  late Future<void> _fetchTagsFuture;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ConnectionProvider>(context, listen: false);
    _fetchTagsFuture = Future.delayed(Duration.zero, () {
      return provider.fetchTagsForConnection(widget.connection.relationId);
    });
    _fetchDetailsFuture = Future.delayed(Duration.zero, () {
      return provider.fetchConnectionDetails(widget.connection.relationId);
    });
  }

  void _refresh() {
    setState(() {
      final provider = Provider.of<ConnectionProvider>(context, listen: false);
      _fetchTagsFuture = provider.fetchTagsForConnection(widget.connection.relationId);
      _fetchDetailsFuture = provider.fetchConnectionDetails(widget.connection.relationId);
    });
  }

  Future<void> _toggleApproval(BuildContext context, ConnectionDetails details, bool currentValue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Karşılıklı İşlem Onayı'),
        content: Text(currentValue
            ? 'Bu özelliği kapattığınızda, bu kişi sizinle ticari işlem yaparken onayınız beklenmeyecek. Emin misiniz?'
            : 'Bu kişi bundan sonra sizinle ticari vb işlemler yapacağı zaman sizden onay beklemeden sisteme düşecek. Kabul ediyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hayır')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Evet')),
        ],
      ),
    );

    if (confirmed == true) {
      Map<String, dynamic> updateData = {};
      if (details.isWholesaler) {
        updateData['wholesaler_approval'] = !currentValue;
      } else {
        updateData['customer_approval'] = !currentValue;
      }

      try {
        await Provider.of<ConnectionProvider>(context, listen: false)
            .updateConnectionSettings(details.relationId, updateData);
        _refresh();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ayarlar güncellendi.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.connection.displayName} Ayarları'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<ConnectionDetails>(
          future: _fetchDetailsFuture,
          builder: (ctx, snapshot) {
             if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Hata: ${snapshot.error}');
            }
            final details = snapshot.data!;
            bool myApprovalStatus =
                details.isWholesaler ? details.wholesalerApproval : details.customerApproval;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Karşılıklı İşlem Onayı'),
                    subtitle:
                        Text(myApprovalStatus ? 'Açık (Yeşil)' : 'Kapalı (Kırmızı)'),
                    value: myApprovalStatus,
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red.shade200,
                    onChanged: (val) =>
                        _toggleApproval(context, details, myApprovalStatus),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Etiketler',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Düzenle'),
                        onPressed: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (_) => SelectTagsScreen(
                                        connection: widget.connection,
                                      )))
                              .then((_) {
                            _refresh();
                          });
                        },
                      ),
                    ],
                  ),
                  if (details.tags.isEmpty)
                    const Text('Etiket yok.',
                        style: TextStyle(color: Colors.grey)),
                  if (details.tags.isNotEmpty)
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: details.tags
                          .map((tag) => Chip(
                                label: Text(tag.name),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}
