import 'package:flutter/material.dart';
import 'package:frontend/models/cart.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/widgets/order_card.dart';
import 'package:provider/provider.dart';

enum CartStatus { active, ordered, preparing, delivered, cancelled }

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).fetchMyCarts();
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

  void _placeOrder(String cartId) {
     Provider.of<CartProvider>(context, listen: false).placeOrder(cartId)
      .then((_) => _showSnackBar('Siparişiniz başarıyla alındı.'))
      .catchError((e) => _showSnackBar('Sipariş verilemedi: ${e.toString()}', isError: true));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sepetlerim ve Siparişlerim'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.shopping_cart), text: 'Aktif Sepetim'),
              Tab(icon: Icon(Icons.pending_actions), text: 'Onay Bekleyen'),
              Tab(icon: Icon(Icons.check_circle), text: 'Hazırlanan'),
              Tab(icon: Icon(Icons.local_shipping), text: 'Teslim Edilenler'),
              Tab(icon: Icon(Icons.cancel), text: 'İptal Edilenler'),
            ],
          ),
        ),
        body: Consumer<CartProvider>(
          builder: (ctx, provider, _) {
            if (provider.isLoading && provider.activeCarts.isEmpty && provider.orderedCarts.isEmpty && provider.preparingCarts.isEmpty && provider.deliveredCarts.isEmpty && provider.cancelledCarts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(child: Text("Hata: ${provider.error}"));
            }

            return TabBarView(
              children: [
                _buildCartsList(provider, provider.activeCarts, CartStatus.active),
                _buildCartsList(provider, provider.orderedCarts, CartStatus.ordered),
                _buildCartsList(provider, provider.preparingCarts, CartStatus.preparing),
                _buildCartsList(provider, provider.deliveredCarts, CartStatus.delivered),
                _buildCartsList(provider, provider.cancelledCarts, CartStatus.cancelled),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartsList(CartProvider provider, List<Cart> carts, CartStatus status) {
    if (carts.isEmpty) {
      return Center(
        child: Text(_getEmptyMessage(status)),
      );
    }
    
    return ListView.builder(
      itemCount: carts.length,
      itemBuilder: (ctx, index) {
        final cart = carts[index];
        return OrderCard(
          cart: cart,
          perspective: CardPerspective.customer,
          isEditable: status == CartStatus.active,
          onUpdateQuantity: (itemId, newQuantity) => provider.updateItemQuantity(itemId, newQuantity),
          onRemoveItem: (itemId) => provider.removeItem(itemId),
          actionButtons: _buildCustomerActionButtons(cart),
        );
      },
    );
  }

  List<Widget>? _buildCustomerActionButtons(Cart cart) {
    if (cart.status == 'active') {
      return [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: cart.items.isNotEmpty ? () => _placeOrder(cart.cartId) : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Siparişi Onayla'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ];
    }
    return null;
  }

  String _getEmptyMessage(CartStatus status) {
    switch (status) {
      case CartStatus.active:
        return 'Aktif sepetiniz bulunmuyor.';
      case CartStatus.ordered:
        return 'Onay bekleyen siparişiniz bulunmuyor.';
      case CartStatus.preparing:
        return 'Hazırlanan siparişiniz bulunmuyor.';
      case CartStatus.delivered:
        return 'Teslim edilen siparişiniz bulunmuyor.';
      case CartStatus.cancelled:
        return 'İptal edilen siparişiniz bulunmuyor.';
    }
  }
}