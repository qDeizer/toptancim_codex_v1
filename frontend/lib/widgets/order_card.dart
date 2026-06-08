import 'package:flutter/material.dart';
import 'package:frontend/models/cart.dart';
import 'package:frontend/models/cart_item.dart';
import 'package:frontend/services/image_service.dart';
import 'package:intl/intl.dart';

enum CardPerspective { customer, wholesaler }

class OrderCard extends StatelessWidget {
  final Cart cart;
  final CardPerspective perspective;
  final bool isEditable;
  final List<Widget>? actionButtons;
  final Function(String cartItemId, int newQuantity)? onUpdateQuantity;
  final Function(String cartItemId)? onRemoveItem;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.cart,
    required this.perspective,
    this.isEditable = false,
    this.actionButtons,
    this.onUpdateQuantity,
    this.onRemoveItem,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency =
        NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    final String titleText = perspective == CardPerspective.customer
        ? cart.wholesalerName
        : cart.customerName ?? 'Bilinmeyen Müşteri';
    
    final String? photoUrl = perspective == CardPerspective.customer
        ? cart.wholesalerPhoto
        : cart.customerPhoto;
    
    final IconData placeholderIcon = perspective == CardPerspective.customer 
        ? Icons.store 
        : Icons.person;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _getCardColor(cart.status),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(ImageService.getFullImageUrl(photoUrl))
                      : null,
                  child: photoUrl == null ? Icon(placeholderIcon) : null,
                ),
                title: Text(titleText,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(_getSubtitleText(cart)),
                trailing: _getStatusChip(cart.status),
              ),
              const Divider(),
              ...cart.items.map((item) =>
                  _buildCartItemTile(context, item, formatCurrency, isEditable)),
              const Divider(),
              _buildCartSummary(cart, formatCurrency),
              if (actionButtons != null && actionButtons!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actionButtons!,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemTile(BuildContext context, CartItem item,
      NumberFormat formatter, bool isEditable) {
    // Yeni format: ürün ismi - toptancı - varyant adedi - fiyat
    final String displayText = '${item.productName} - ${cart.wholesalerName} - ${item.variantName}';
    
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: item.variantImage != null
            ? NetworkImage(ImageService.getFullImageUrl(item.variantImage))
            : null,
        child: item.variantImage == null ? const Icon(Icons.shopping_bag) : null,
      ),
      title: Text(displayText,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(formatter.format(item.price)),
      trailing: isEditable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: item.quantity > 1
                      ? () => onUpdateQuantity?.call(item.cartItemId, item.quantity - 1)
                      : null,
                ),
                Text(item.quantity.toString(),
                    style: const TextStyle(fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => onUpdateQuantity?.call(item.cartItemId, item.quantity + 1),
                ),
                IconButton(
                  icon: Icon(Icons.delete_forever,
                      color: Theme.of(context).colorScheme.error),
                  onPressed: () => onRemoveItem?.call(item.cartItemId),
                ),
              ],
            )
          : Text(
              '${item.quantity} Adet',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildCartSummary(Cart cart, NumberFormat formatter) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Toplam Tutar:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
            formatter.format(cart.totalAmount),
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Color? _getCardColor(String status) {
    switch (status) {
      case 'active':
        return null;
      case 'ordered':
        return Colors.orange.shade50;
      case 'preparing':
        return Colors.blue.shade50;
      case 'shipped':
        return Colors.lightBlue.shade50;
      case 'delivered':
        return Colors.green.shade50;
      case 'cancelled':
        return Colors.red.shade50;
      default:
        return null;
    }
  }

  String _getSubtitleText(Cart cart) {
    if (cart.status == 'active') return 'Hazırlanan Sepet';
    if (cart.orderedAt == null) return 'Sipariş Tarihi Bilinmiyor';
    return 'Sipariş Tarihi: ${DateFormat('dd.MM.yyyy').format(cart.orderedAt!)}';
  }

  Widget? _getStatusChip(String status) {
    switch (status) {
      case 'active':
        return null;
      case 'ordered':
        return const Chip(
            label: Text('Onay Bekliyor'), backgroundColor: Colors.orange, labelStyle: TextStyle(color: Colors.white));
      case 'preparing':
        return const Chip(
            label: Text('Hazırlanıyor'), backgroundColor: Colors.blue, labelStyle: TextStyle(color: Colors.white));
      case 'shipped':
        return const Chip(
            label: Text('Kargoda'), backgroundColor: Colors.lightBlue, labelStyle: TextStyle(color: Colors.white));
      case 'delivered':
        return const Chip(
            label: Text('Teslim Edildi'), backgroundColor: Colors.green, labelStyle: TextStyle(color: Colors.white));
      case 'cancelled':
        return const Chip(
            label: Text('İptal Edildi'), backgroundColor: Colors.red, labelStyle: TextStyle(color: Colors.white));
      default:
        return null;
    }
  }
}