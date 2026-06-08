import 'package:flutter/material.dart';
import 'package:frontend/models/financial_transaction.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/person_profile_screen.dart';
import 'package:frontend/services/connection_service.dart';
import 'package:frontend/services/image_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/transaction_provider.dart';

class FinancialTransactionCard extends StatelessWidget {
  final FinancialTransaction transaction;
  final VoidCallback? onLongPress;

  const FinancialTransactionCard({
    super.key,
    required this.transaction,
    this.onLongPress,
  });

  String _getTransactionTypeText(DisplayTransactionType type) {
    switch (type) {
      case DisplayTransactionType.satis:
        return 'Satış';
      case DisplayTransactionType.tahsilat:
        return 'Tahsilat';
      case DisplayTransactionType.alis:
        return 'Alış';
      case DisplayTransactionType.odeme:
        return 'Ödeme';
      case DisplayTransactionType.gelir:
        return 'Diğer Gelir';
      case DisplayTransactionType.gider:
        return 'Diğer Gider';
      case DisplayTransactionType.bilinmeyen:
        return 'Bilinmeyen İşlem';
    }
  }

  IconData _getTransactionIcon(DisplayTransactionType type) {
    switch (type) {
      case DisplayTransactionType.satis:
        return Icons.point_of_sale;
      case DisplayTransactionType.tahsilat:
        return Icons.call_received;
      case DisplayTransactionType.alis:
        return Icons.add_shopping_cart;
      case DisplayTransactionType.odeme:
        return Icons.call_made;
      case DisplayTransactionType.gelir:
        return Icons.trending_up;
      case DisplayTransactionType.gider:
        return Icons.trending_down;
      case DisplayTransactionType.bilinmeyen:
      default:
        return Icons.question_mark;
    }
  }

  (Color, String) _getTransactionProperties(BuildContext context,
      DisplayTransactionType type, TransactionDirection direction) {
    final theme = Theme.of(context);
    switch (direction) {
      case TransactionDirection.incoming:
        return (Colors.green.shade600, '+');
      case TransactionDirection.outgoing:
        return (theme.colorScheme.error, '-');
      case TransactionDirection.neutral:
        if (type == DisplayTransactionType.satis) {
          return (theme.colorScheme.primary, '');
        }
        return (theme.colorScheme.secondary, '');
    }
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToProfile(BuildContext context, FinancialTransaction transaction) async {
    if (transaction.partnerId == null) return;
    
    // Detay diyalogunu kapat
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Kişi profili yükleniyor...'),
      duration: Duration(seconds: 1),
    ));

    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception("Not authenticated");

      final relationIds = await ConnectionService().getRelationIdsByUsers(token, transaction.partnerId!);
      if (relationIds.isEmpty) {
        throw Exception("Bu kişiyle aranızda bir bağlantı bulunamadı.");
      }
      
      if(context.mounted) {
        // Ana context üzerinden push yap
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PersonProfileScreen(relationId: relationIds.first),
          ),
        );
      }
    } catch (e) {
      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profil açılamadı: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }


  void _showTransactionDetailDialog(
      BuildContext context, FinancialTransaction transaction) {
    final formattedDate = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR')
        .format(transaction.transactionDate);
    final formattedAmount =
        NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
            .format(transaction.amount);

    final authProvider = context.read<AuthProvider>();
    final myId = authProvider.userId;
    final isCreator = transaction.creatorId == myId;
    final approvalStatus = transaction.approvalStatus;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Text(_getTransactionTypeText(transaction.displayType)),
                if (approvalStatus != 'onayli')
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: _getStatusColor(approvalStatus),
                            borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                            _getStatusText(approvalStatus),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                    ),
            ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              if (transaction.partnerId != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: transaction.partnerPhoto != null
                        ? NetworkImage(ImageService.getFullImageUrl(transaction.partnerPhoto))
                        : null,
                    child: transaction.partnerPhoto == null ? const Icon(Icons.person, size: 20) : null,
                  ),
                  title: Text(transaction.partnerName),
                  subtitle: const Text('İlgili Kişi'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _navigateToProfile(ctx, transaction),
                )
              else 
                _detailRow(Icons.person, 'İlgili Kişi', transaction.partnerName),
              const Divider(),
              _detailRow(Icons.attach_money, 'Tutar', formattedAmount),
              _detailRow(Icons.payment, 'Ödeme Yöntemi',
                  transaction.paymentMethod ?? 'Belirtilmemiş'),
              _detailRow(Icons.date_range, 'Tarih', formattedDate),
              if (transaction.description != null &&
                  transaction.description!.isNotEmpty)
                _detailRow(
                    Icons.description, 'Açıklama', transaction.description!),
              _detailRow(Icons.info_outline, 'Durum', _getStatusText(approvalStatus)),
              
             const SizedBox(height: 10),
             _buildActionButtons(ctx, transaction, isCreator, myId!),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Kapat'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
      switch (status) {
          case 'beklemede': return Colors.orange;
          case 'onayli': return Colors.green;
          case 'reddedildi': return Colors.red;
          case 'iptal_edildi': return Colors.grey;
          case 'creator_iptal_talebi': return Colors.purple;
          case 'ilgili_iptal_talebi': return Colors.purple;
          default: return Colors.blue;
      }
  }

  String _getStatusText(String status) {
      switch (status) {
          case 'beklemede': return 'Onay Bekliyor';
          case 'onayli': return 'Onaylandı';
          case 'reddedildi': return 'Reddedildi';
          case 'iptal_edildi': return 'İptal Edildi';
          case 'creator_iptal_talebi': return 'İptal Talebi (Oluşturan)';
          case 'ilgili_iptal_talebi': return 'İptal Talebi (İlgili)';
          default: return status;
      }
  }

  Widget _buildActionButtons(BuildContext context, FinancialTransaction transaction, bool isCreator, String myId) {
      final provider = context.read<TransactionProvider>(); // Use read, actions are one-off
      final status = transaction.approvalStatus;
      
      List<Widget> buttons = [];

      if (status == 'beklemede') {
          if (isCreator) {
               buttons.add(ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                   onPressed: () => _performAction(context, () => provider.cancelTransaction(transaction.id), "İşlem iptal edildi."),
                   child: const Text('İptal Et', style: TextStyle(color: Colors.white)),
               ));
          } else {
               buttons.add(ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                   onPressed: () => _performAction(context, () => provider.respondToTransaction(transaction.id, 'onayla'), "İşlem onaylandı."),
                   child: const Text('Onayla', style: TextStyle(color: Colors.white)),
               ));
               buttons.add(const SizedBox(width: 8));
               buttons.add(ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                   onPressed: () => _performAction(context, () => provider.respondToTransaction(transaction.id, 'reddet'), "İşlem reddedildi."),
                   child: const Text('Reddet', style: TextStyle(color: Colors.white)),
               ));
          }
      } else if (status == 'onayli') {
          buttons.add(OutlinedButton(
               onPressed: () => _performAction(context, () => provider.requestCancel(transaction.id), "İptal talebi gönderildi."),
               child: const Text('İptal Talebi Oluştur'),
          ));
      } else if (status == 'creator_iptal_talebi') {
          if (!isCreator) {
              // I am the related party, creator asked for cancel.
               buttons.add(ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                   onPressed: () => _performAction(context, () => provider.respondToCancelRequest(transaction.id, 'onayla'), "İptal talebi onaylandı (İşlem İptal)."),
                   child: const Text('İptali Onayla', style: TextStyle(color: Colors.white)),
               ));
               buttons.add(const SizedBox(width: 8));
               buttons.add(ElevatedButton(
                   onPressed: () => _performAction(context, () => provider.respondToCancelRequest(transaction.id, 'reddet'), "İptal talebi reddedildi."),
                   child: const Text('İptali Reddet'),
               ));
          } else {
              buttons.add(const Text("İptal talebiniz karşı tarafın onayını bekliyor.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));
          }
      } else if (status == 'ilgili_iptal_talebi') {
          if (isCreator) {
              // I am creator, related party asked for cancel.
               buttons.add(ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                   onPressed: () => _performAction(context, () => provider.respondToCancelRequest(transaction.id, 'onayla'), "İptal talebi onaylandı (İşlem İptal)."),
                   child: const Text('İptali Onayla', style: TextStyle(color: Colors.white)),
               ));
                buttons.add(const SizedBox(width: 8));
               buttons.add(ElevatedButton(
                   onPressed: () => _performAction(context, () => provider.respondToCancelRequest(transaction.id, 'reddet'), "İptal talebi reddedildi."),
                   child: const Text('İptali Reddet'),
               ));
          } else {
               buttons.add(const Text("İptal talebiniz karşı tarafın onayını bekliyor.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));
          }
      }

      return Row(mainAxisAlignment: MainAxisAlignment.center, children: buttons);
  }

  Future<void> _performAction(BuildContext context, Future<void> Function() action, String successMessage) async {
      try {
          await action();
          if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green));
          }
      } catch (e) {
          if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    final (color, sign) =
        _getTransactionProperties(context, transaction.displayType, transaction.direction);
    final formattedAmount =
        NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
            .format(transaction.amount);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _showTransactionDetailDialog(context, transaction),
        onLongPress: onLongPress,
        child: ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            backgroundImage: transaction.partnerPhoto != null
                ? NetworkImage(
                    ImageService.getFullImageUrl(transaction.partnerPhoto))
                : null,
            child: transaction.partnerPhoto == null
                ? Icon(_getTransactionIcon(transaction.displayType), color: color)
                : null,
          ),
          title: Text(
            transaction.partnerName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(_getTransactionTypeText(transaction.displayType)),
          trailing: Text(
            '$sign$formattedAmount',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}