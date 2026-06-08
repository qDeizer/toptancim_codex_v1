import 'package:flutter/material.dart';
import 'package:frontend/models/cart.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/wholesaler_order_provider.dart';
import 'package:frontend/screens/wholesaler_product_picker_screen.dart';
import 'package:frontend/services/image_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class WholesalerOrderEditScreen extends StatefulWidget {
  final String cartId;
  const WholesalerOrderEditScreen({super.key, required this.cartId});

  @override
  State<WholesalerOrderEditScreen> createState() =>
      _WholesalerOrderEditScreenState();
}

class _WholesalerOrderEditScreenState extends State<WholesalerOrderEditScreen> {
  final _totalAmountController = TextEditingController();

  @override
  void dispose() {
    _totalAmountController.dispose();
    super.dispose();
  }
  
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  void _showOverrideTotalDialog(BuildContext context, double currentTotal) {
    _totalAmountController.text = currentTotal.toStringAsFixed(2);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toplam Tutarı Değiştir'),
        content: TextField(
          controller: _totalAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Yeni Toplam Tutar',
            prefixText: '₺ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTotal = double.tryParse(_totalAmountController.text);
              if (newTotal != null && newTotal >= 0) {
                context.read<WholesalerOrderProvider>()
                  .overrideTotalAmount(widget.cartId, newTotal)
                  .then((_) => _showSnackBar('Toplam tutar güncellendi'))
                  .catchError((e) => _showSnackBar(e.toString(), isError: true));
                Navigator.of(ctx).pop();
              } else {
                _showSnackBar('Lütfen geçerli bir tutar girin.', isError: true);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WholesalerOrderProvider>();
    final orderIndex = provider.orders.indexWhere((c) => c.cartId == widget.cartId);
    final Cart? cart = orderIndex != -1 ? provider.orders[orderIndex] : null;

    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    
    if (cart == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Sipariş yükleniyor veya bulunamadı...'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${cart.customerName ?? 'Müşteri'} Siparişi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ...cart.items.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: item.variantImage != null
                      ? NetworkImage(ImageService.getFullImageUrl(item.variantImage))
                      : null,
                ),
                title: Text(item.displayName),
                subtitle: Text(formatCurrency.format(item.price)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        provider.updateItemInOrder(cart.cartId, item.cartItemId, item.quantity - 1);
                      },
                    ),
                    Text(item.quantity.toString(), style: const TextStyle(fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        provider.updateItemInOrder(cart.cartId, item.cartItemId, item.quantity + 1);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        provider.removeItemFromOrder(cart.cartId, item.cartItemId);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          const Divider(height: 32),
          ListTile(
            title: const Text(
              'Toplam Tutar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatCurrency.format(cart.totalAmount),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showOverrideTotalDialog(context, cart.totalAmount),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<Map<String, dynamic>>(
            MaterialPageRoute(builder: (_) => 
             ChangeNotifierProvider.value(
                value: context.read<ProductProvider>(),
                child: const WholesalerProductPickerScreen(),
              ),
            )
          );

          if (result != null && result['variant'] != null && result['quantity'] != null) {
            final ProductVariant variant = result['variant'];
            final int quantity = result['quantity'];
            await provider.addItemToOrder(cart.cartId, variant.variantId!, quantity);
          }
        },
        label: const Text('Yeni Ürün Ekle'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}