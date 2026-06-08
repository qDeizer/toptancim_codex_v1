import 'package:flutter/material.dart';
import 'package:frontend/models/cart.dart';
import 'package:frontend/models/connection_details.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/wholesaler_product_picker_screen.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/services/image_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CustomerOrderBuilderScreen extends StatefulWidget {
  final ConnectionDetails person;

  const CustomerOrderBuilderScreen({
    super.key,
    required this.person,
  });

  @override
  State<CustomerOrderBuilderScreen> createState() =>
      _CustomerOrderBuilderScreenState();
}

class _CustomerOrderBuilderScreenState
    extends State<CustomerOrderBuilderScreen> {
  final CartService _cartService = CartService();
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  Cart? _draftCart;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScreen();
    });
  }

  Future<void> _loadScreen() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    final myUserId = auth.userId;

    if (token == null || myUserId == null) {
      setState(() {
        _error = 'Yetkilendirme bilgisi bulunamadı.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        context.read<ProductProvider>().fetchProducts(),
        _reloadDraftCart(token, myUserId),
      ]);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reloadDraftCart(String token, String myUserId) async {
    final carts = await _cartService.getMyCarts(
      token,
      customerId: widget.person.id,
    );

    Cart? activeCart;
    for (final cart in carts) {
      if (cart.wholesalerId == myUserId && cart.status == 'active') {
        activeCart = cart;
        break;
      }
    }

    _draftCart = activeCart;
  }

  Future<void> _runBusyAction(
    Future<void> Function(String token, String myUserId) action, {
    String? successMessage,
  }) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    final myUserId = auth.userId;

    if (token == null || myUserId == null) {
      _showSnackBar('Yetkilendirme bilgisi bulunamadı.', isError: true);
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await action(token, myUserId);
      await _reloadDraftCart(token, myUserId);
      if (mounted) {
        setState(() {});
      }
      if (successMessage != null && mounted) {
        _showSnackBar(successMessage);
      }
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  Future<void> _addProduct() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<ProductProvider>(),
          child: const WholesalerProductPickerScreen(),
        ),
      ),
    );

    if (result == null ||
        result['variant'] == null ||
        result['quantity'] == null) {
      return;
    }

    final variant = result['variant'] as ProductVariant;
    final quantity = result['quantity'] as int;

    await _runBusyAction(
      (token, myUserId) => _cartService.addItemToCart(
        token,
        variant.variantId!,
        quantity,
        myUserId,
        customerId: widget.person.id,
      ),
      successMessage: 'Ürün sipariş taslağına eklendi.',
    );
  }

  Future<void> _changeItemQuantity(String itemId, int newQuantity) async {
    if (newQuantity < 1) {
      await _removeItem(itemId);
      return;
    }

    await _runBusyAction(
      (token, _) => _cartService.updateItemQuantity(
        token,
        itemId,
        newQuantity,
        customerId: widget.person.id,
      ),
      successMessage: 'Miktar güncellendi.',
    );
  }

  Future<void> _removeItem(String itemId) async {
    await _runBusyAction(
      (token, _) => _cartService.removeItem(
        token,
        itemId,
        customerId: widget.person.id,
      ),
      successMessage: 'Ürün taslaktan kaldırıldı.',
    );
  }

  Future<void> _placeOrder() async {
    final cart = _draftCart;
    if (cart == null || cart.items.isEmpty) {
      _showSnackBar('Siparişe eklenecek ürün bulunmuyor.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Siparişi Oluştur'),
        content: Text(
          '${widget.person.displayName} adına bu siparişi oluşturmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _runBusyAction(
      (token, _) => _cartService.placeOrder(
        token,
        cart.cartId,
        customerId: widget.person.id,
      ),
      successMessage: 'Sipariş oluşturuldu.',
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.person.displayName} için Sipariş'),
        actions: [
          IconButton(
            onPressed: _isBusy ? null : _loadScreen,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Ürün Ekle'),
      ),
      bottomNavigationBar: _buildBottomBar(theme),
      body: RefreshIndicator(
        onRefresh: _loadScreen,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _buildHeroCard(theme),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _buildMessageState(_error!, isError: true)
            else if (_draftCart == null || _draftCart!.items.isEmpty)
              _buildMessageState(
                'Henüz aktif sipariş taslağı yok. Ürün ekleyerek başlayabilirsiniz.',
              )
            else
              ..._draftCart!.items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: item.variantImage != null
                              ? Image.network(
                                  ImageService.getFullImageUrl(
                                      item.variantImage),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image_not_supported_outlined),
                                )
                              : Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.inventory_2_outlined),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormatter.format(item.price),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                IconButton.outlined(
                                  onPressed: _isBusy
                                      ? null
                                      : () => _changeItemQuantity(
                                            item.cartItemId,
                                            item.quantity - 1,
                                          ),
                                  icon: const Icon(Icons.remove),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Text(
                                    item.quantity.toString(),
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                IconButton.outlined(
                                  onPressed: _isBusy
                                      ? null
                                      : () => _changeItemQuantity(
                                            item.cartItemId,
                                            item.quantity + 1,
                                          ),
                                  icon: const Icon(Icons.add),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _isBusy
                                      ? null
                                      : () => _removeItem(item.cartItemId),
                                  tooltip: 'Ürünü kaldır',
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: widget.person.profilFotografi != null
                ? NetworkImage(
                    ImageService.getFullImageUrl(widget.person.profilFotografi),
                  )
                : null,
            child: widget.person.profilFotografi == null
                ? const Icon(Icons.person, size: 28)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.person.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bu ekran üzerinden müşteri adına aktif sipariş taslağı oluşturabilir, ürün ekleyebilir ve siparişi kesinleştirebilirsiniz.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState(String message, {bool isError = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final cart = _draftCart;
    final canSubmit =
        !_isLoading && !_isBusy && cart != null && cart.items.isNotEmpty;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Taslak Toplamı',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _currencyFormatter.format(cart?.totalAmount ?? 0),
                      key: ValueKey(cart?.totalAmount ?? 0),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: canSubmit ? _placeOrder : null,
              icon: _isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Siparişi Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
