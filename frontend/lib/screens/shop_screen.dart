import 'package:flutter/material.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/shop_provider.dart';
import 'package:frontend/services/image_service.dart';
import 'package:frontend/utils/logger.dart';
import 'package:provider/provider.dart';

import 'cart_screen.dart';
import 'customer_product_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  final String? initialWholesalerId;
  final String? initialWholesalerName;

  const ShopScreen({
    super.key,
    this.initialWholesalerId,
    this.initialWholesalerName,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? selectedSupplierId;

  String _supplierName(Map supplier) {
    final rawName = supplier['name']?.toString().trim();
    if (rawName != null && rawName.isNotEmpty) {
      return rawName;
    }
    return 'Adsiz toptanci';
  }

  String _supplierAvatarLabel(Map supplier) {
    final name = _supplierName(supplier);
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    selectedSupplierId = widget.initialWholesalerId;
    AppLogger.info(
      'Shop screen initialized: wholesalerId=${widget.initialWholesalerId ?? "all"}, wholesalerName=${widget.initialWholesalerName ?? "none"}',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialContent();
    });
  }

  Future<void> _loadInitialContent() async {
    final shopProvider = context.read<ShopProvider>();
    try {
      AppLogger.info(
        'Shop screen loading initial content: wholesalerId=${widget.initialWholesalerId ?? "all"}',
      );
      if (widget.initialWholesalerId != null) {
        await shopProvider.fetchShopContent(
          wholesalerId: widget.initialWholesalerId,
        );
      } else {
        await shopProvider.loadProducts();
      }
      AppLogger.info(
        'Shop screen initial content ready: wholesalerId=${widget.initialWholesalerId ?? "all"}',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Shop screen initial content failed: wholesalerId=${widget.initialWholesalerId ?? "all"}',
        error,
        stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialWholesalerName != null
        ? '${widget.initialWholesalerName} Ürünleri'
        : 'Alışveriş';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    tooltip: 'Sepet',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    },
                  ),
                  if (cartProvider.totalItemCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${cartProvider.totalItemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<ShopProvider>(
        builder: (context, shopProvider, child) {
          if (shopProvider.isLoading && shopProvider.shopProducts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (shopProvider.error != null &&
              shopProvider.filteredProducts.isEmpty &&
              !shopProvider.isLoading) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      shopProvider.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadInitialContent,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              if (widget.initialWholesalerId == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String?>(
                    value: selectedSupplierId,
                    isExpanded: true,
                    menuMaxHeight: 420,
                    decoration: const InputDecoration(
                      labelText: 'Toptancı seçin',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tümü'),
                      ),
                      ...shopProvider.suppliers.map((supplier) {
                        final supplierName = _supplierName(supplier);
                        return DropdownMenuItem<String?>(
                          value: supplier['id'].toString(),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: supplier['photo'] != null
                                      ? NetworkImage(
                                          ImageService.getFullImageUrl(
                                            supplier['photo'],
                                          ),
                                        )
                                      : null,
                                  child: supplier['photo'] == null
                                      ? Text(_supplierAvatarLabel(supplier))
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 220,
                                  child: Text(
                                    supplierName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      AppLogger.debug(
                        'Shop screen supplier filter changed: supplierId=${value ?? "all"}',
                      );
                      setState(() {
                        selectedSupplierId = value;
                      });
                      shopProvider.filterProductsBySupplierId(value);
                    },
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Bu ekranda yalnızca ${widget.initialWholesalerName ?? 'seçili toptancı'} ürünleri listelenir.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              Expanded(
                child: shopProvider.filteredProducts.isEmpty
                    ? const Center(child: Text('Ürün bulunamadı'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: shopProvider.filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = shopProvider.filteredProducts[index];
                          return ProductCard(product: product);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final firstVariant =
        product.variants.isNotEmpty ? product.variants.first : null;
    final mainImage = product.coverImage ??
        (product.variantThumbnails.isNotEmpty
            ? product.variantThumbnails.first
            : null);
    final isOutOfStock =
        firstVariant == null || firstVariant.availableStock <= 0;
    final otherVariantThumbnails = product.variantThumbnails
        .where((thumb) => thumb != mainImage)
        .take(4)
        .toList();

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () {
          AppLogger.debug(
            'Shop screen opening product detail: productId=${product.productId}, wholesalerId=${product.creatorId}',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CustomerProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Colors.grey[200],
                      child: mainImage != null
                          ? Image.network(
                              ImageService.getFullImageUrl(mainImage),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2,
                              size: 50,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.yellow.shade600,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (otherVariantThumbnails.isNotEmpty)
                    Positioned(
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: otherVariantThumbnails.map((url) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white70,
                                  width: 1,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    ImageService.getFullImageUrl(url),
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: const Center(
                          child: Text(
                            'Stokta Yok',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.variants.length > 1)
                        Chip(
                          label: Text('${product.variants.length} varyant'),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          labelStyle: const TextStyle(fontSize: 10),
                          backgroundColor: Colors.grey.shade200,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (product.wholesalerName != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundImage: product.wholesalerPhoto != null
                              ? NetworkImage(
                                  ImageService.getFullImageUrl(
                                    product.wholesalerPhoto!,
                                  ),
                                )
                              : null,
                          child: product.wholesalerPhoto == null
                              ? const Icon(Icons.store, size: 8)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            product.wholesalerName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (firstVariant != null)
                    Text(
                      '${firstVariant.price} ₺',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
