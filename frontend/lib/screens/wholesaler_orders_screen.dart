import 'package:flutter/material.dart';
import 'package:frontend/models/cart.dart';
import 'package:frontend/providers/wholesaler_order_provider.dart';
import 'package:frontend/screens/wholesaler_order_edit_screen.dart';
import 'package:frontend/widgets/order_card.dart';
import 'package:provider/provider.dart';

enum OrderStatus { ordered, preparing, shipped, delivered, cancelled }

class WholesalerOrdersScreen extends StatefulWidget {
  const WholesalerOrdersScreen({super.key});
  @override
  State<WholesalerOrdersScreen> createState() => _WholesalerOrdersScreenState();
}

class _WholesalerOrdersScreenState extends State<WholesalerOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WholesalerOrderProvider>(context, listen: false).fetchWholesalerOrders();
    });
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

  void _showActionConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String actionText,
    required Function(Map<String, dynamic> options) onConfirm,
    bool showTransactionSwitch = false,
  }) {
    bool createTransaction = true; 

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content),
                if (showTransactionSwitch) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Ticari İşlem Uygula'),
                    subtitle: const Text('Bu satış için finansal kayıt oluşturulur.'),
                    value: createTransaction,
                    onChanged: (value) {
                       setState(() {
                        createTransaction = value;
                      });
                    },
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm({'createTransaction': createTransaction});
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gelen Siparişler'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.new_releases), text: 'Yeni'),
              Tab(icon: Icon(Icons.construction), text: 'Hazırlanan'),
              Tab(icon: Icon(Icons.local_shipping), text: 'Kargoda'),
              Tab(icon: Icon(Icons.check_circle), text: 'Teslim Edilen'),
              Tab(icon: Icon(Icons.cancel), text: 'İptal'),
            ],
          ),
        ),
        body: Consumer<WholesalerOrderProvider>(
          builder: (ctx, provider, _) {
            if (provider.isLoading && provider.orders.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(child: Text("Hata: ${provider.error}"));
            }

            return TabBarView(
              children: [
                _buildOrdersList(provider.orderedCarts, OrderStatus.ordered),
                _buildOrdersList(provider.preparingCarts, OrderStatus.preparing),
                _buildOrdersList(provider.shippedCarts, OrderStatus.shipped),
                _buildOrdersList(provider.deliveredCarts, OrderStatus.delivered),
                _buildOrdersList(provider.cancelledCarts, OrderStatus.cancelled),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Cart> carts, OrderStatus status) {
    if (carts.isEmpty) {
      return Center(
        child: Text(_getEmptyMessage(status)),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => Provider.of<WholesalerOrderProvider>(context, listen: false).fetchWholesalerOrders(),
      child: ListView.builder(
        itemCount: carts.length,
        itemBuilder: (ctx, index) {
          final cart = carts[index];
           return OrderCard(
            cart: cart, 
            perspective: CardPerspective.wholesaler,
            actionButtons: _buildActionButtons(cart, status),
          );
        },
      ),
    );
  }

  List<Widget> _buildActionButtons(Cart cart, OrderStatus status) {
    final provider = context.read<WholesalerOrderProvider>();
    List<Widget> buttons = [];

    if (status == OrderStatus.ordered) {
      buttons.add(Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Onayla'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, backgroundColor: Colors.green
          ),
          onPressed: () => _showActionConfirmationDialog(
            context: context,
            title: 'Siparişi Onayla',
            content: 'Bu siparişi onaylamak ve hazırlama aşamasına geçirmek istediğinizden emin misiniz? Stoklarınız güncellenecektir.',
            actionText: 'Onayla',
            onConfirm: (_) => provider.confirmSale(cart.cartId)
              .catchError((e) => _showSnackBar('Hata: $e', isError: true)),
          ),
        ),
      ));
    }
    
    if (status == OrderStatus.preparing) {
       buttons.add(Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.local_shipping),
          label: const Text('Kargoya Ver'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, backgroundColor: Colors.blue
          ),
          onPressed: () => _showActionConfirmationDialog(
            context: context,
            title: 'Kargoya Ver',
            content: 'Siparişin durumunu "Kargoda" olarak güncellemek istediğinizden emin misiniz?',
            actionText: 'Evet, Kargoya Ver',
            onConfirm: (_) => provider.updateOrderStatus(cart.cartId, 'shipped', createTransaction: false)
              .catchError((e) => _showSnackBar('Hata: $e', isError: true)),
          ),
        ),
      ));
    }
    
    if (status == OrderStatus.shipped) {
       buttons.add(Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.delivery_dining),
          label: const Text('Teslim Edildi'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, backgroundColor: Colors.teal
          ),
          onPressed: () => _showActionConfirmationDialog(
            context: context,
            title: 'Teslim Edildi',
            content: 'Siparişin müşteriye teslim edildiğini onaylıyor musunuz?',
            actionText: 'Evet, Teslim Edildi',
            showTransactionSwitch: true,
            onConfirm: (options) {
               provider.updateOrderStatus(cart.cartId, 'delivered', createTransaction: options['createTransaction'])
                    .catchError((e) => _showSnackBar('Hata: $e', isError: true));
            },
          ),
        ),
      ));
    }
    
    // Düzenleme ve iptal butonları sadece aktif siparişlerde görünür
    if (status == OrderStatus.ordered || status == OrderStatus.preparing || status == OrderStatus.shipped) {
        if(buttons.isNotEmpty) buttons.add(const SizedBox(width: 8));
        
        // Düzenleme butonu - sadece iptal edilmemiş ve teslim edilmemiş siparişlerde
        buttons.add(
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Siparişi Düzenle',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WholesalerOrderEditScreen(cartId: cart.cartId),
                )
              );
            },
          )
        );
        
        // İptal butonu
        buttons.add(
          IconButton(
            icon: Icon(Icons.cancel, color: Colors.red.shade700),
            tooltip: 'Siparişi İptal Et',
            onPressed: () => _showActionConfirmationDialog(
              context: context,
              title: 'Siparişi İptal Et',
              content: 'Bu siparişi iptal etmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
              actionText: 'Evet, İptal Et',
              onConfirm: (_) => provider.updateOrderStatus(cart.cartId, 'cancelled', createTransaction: false)
                .catchError((e) => _showSnackBar('Hata: $e', isError: true)),
            ),
          )
        );
    }

    return buttons;
  }

  String _getEmptyMessage(OrderStatus status) {
    switch (status) {
      case OrderStatus.ordered: return 'Yeni sipariş bulunmuyor.';
      case OrderStatus.preparing: return 'Hazırlanan sipariş bulunmuyor.';
      case OrderStatus.shipped: return 'Kargoda olan sipariş bulunmuyor.';
      case OrderStatus.delivered: return 'Teslim edilen sipariş bulunmuyor.';
      case OrderStatus.cancelled: return 'İptal edilen sipariş bulunmuyor.';
    }
  }
}