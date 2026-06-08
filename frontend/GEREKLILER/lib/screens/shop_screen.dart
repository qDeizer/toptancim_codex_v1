import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_provider.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';
import '../services/image_service.dart';
import 'customer_product_detail_screen.dart';
import 'cart_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? selectedSupplierId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShopProvider>().loadSuppliers();
      context.read<ShopProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışveriş'),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CartScreen()),
                      );
                    },
                  ),
                  if (cartProvider.totalItemCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${cartProvider.totalItemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
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

          return Column(
            children: [
              // Supplier Dropdown
              Container(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String?>(
                  value: selectedSupplierId,
                  decoration: const InputDecoration(
                    labelText: 'Toptancı Seç',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Hepsi'),
                    ),
                    ...shopProvider.suppliers.map((supplier) {
                      return DropdownMenuItem<String?>(
                        value: supplier['id'].toString(),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: supplier['photo'] != null
                                  ? NetworkImage(ImageService.getFullImageUrl(supplier['photo']))
                                  : null,
                              child: supplier['photo'] == null
                                  ? Text(supplier['name'][0].toUpperCase())
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(supplier['name']),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedSupplierId = value;
                    });
                    shopProvider.filterProductsBySupplierId(value);
                  },
                ),
              ),
              // Products Grid
              Expanded(
                child: shopProvider.filteredProducts.isEmpty
                    ? const Center(child: Text('Ürün bulunamadı'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
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
    final firstVariant = product.variants.isNotEmpty ? product.variants.first : null;
    final mainImage = product.coverImage ??
        (product.variantThumbnails.isNotEmpty ? product.variantThumbnails.first : null);
    final isOutOfStock = firstVariant == null || firstVariant.availableStock <= 0;
    
    // Diğer varyantların ilk resimlerinden thumbnail'ler oluştur
    final otherVariantThumbnails = product.variantThumbnails
        .where((thumb) => thumb != mainImage)
        .take(4)
        .toList();

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerProductDetailScreen(product: product),
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
                                  const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            )
                          : const Icon(Icons.inventory_2, size: 50, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.yellow.shade600, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            product.averageRating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (otherVariantThumbnails.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
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
                                border: Border.all(color: Colors.white70, width: 1),
                                image: DecorationImage(
                                  image: NetworkImage(ImageService.getFullImageUrl(url)),
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
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                        ),
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
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.variants.length > 1)
                        Chip(
                          label: Text('${product.variants.length} Varyant'),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          labelStyle: const TextStyle(fontSize: 10),
                          backgroundColor: Colors.grey.shade200,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (product.wholesalerName != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundImage: product.wholesalerPhoto != null
                              ? NetworkImage(ImageService.getFullImageUrl(product.wholesalerPhoto))
                              : null,
                          child: product.wholesalerPhoto == null ? const Icon(Icons.store, size: 8) : null,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.wholesalerName!,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
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
