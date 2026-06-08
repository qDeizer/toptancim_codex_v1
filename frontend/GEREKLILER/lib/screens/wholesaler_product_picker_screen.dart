import 'package:flutter/material.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/services/image_service.dart';
import 'package:provider/provider.dart';

class WholesalerProductPickerScreen extends StatefulWidget {
  const WholesalerProductPickerScreen({super.key});

  @override
  State<WholesalerProductPickerScreen> createState() =>
      _WholesalerProductPickerScreenState();
}

class _WholesalerProductPickerScreenState
    extends State<WholesalerProductPickerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchProducts();
    });
  }

  Future<void> _handleProductTap(Product product) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final fullProduct = await context
          .read<ProductProvider>()
          .fetchProductById(product.productId);
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _selectVariant(fullProduct);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürün detayları alınamadı: $e')),
        );
      }
    }
  }

  void _selectVariant(Product product) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: product.variants.length,
          itemBuilder: (listCtx, index) {
            final variant = product.variants[index];
            final variantImage = variant.images != null && variant.images!.isNotEmpty
                ? variant.images!.first
                : null;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  _showQuantityDialog(variant);
                },
                child: GridTile(
                  footer: GridTileBar(
                    backgroundColor: Colors.black54,
                    title: Text(
                      variant.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      "Stok: ${variant.availableStock}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  child: variantImage != null
                      ? Image.network(
                          ImageService.getFullImageUrl(variantImage),
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) =>
                              const Icon(Icons.error),
                        )
                      : const Icon(Icons.image_not_supported),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQuantityDialog(ProductVariant variant) {
    final quantityController = TextEditingController(text: "1");
    Navigator.of(context).pop(); // Close the variant selection sheet
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${variant.name} için miktar girin'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Adet'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                Navigator.of(ctx).pop(); // Close the dialog
                Navigator.of(context).pop({
                  'variant': variant,
                  'quantity': quantity
                }); // Pop the picker screen with result
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişe Ürün Ekle'),
      ),
      body: productProvider.isLoading && productProvider.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: productProvider.products.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400.0,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (ctx, i) {
                final product = productProvider.products[i];
                return _buildProductCard(product);
              },
            ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _handleProductTap(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildImageSection(product),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if ((product.variantCount ?? 0) > 0)
                    Chip(
                      label: Text('${product.variantCount} Varyant'),
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      labelStyle: const TextStyle(fontSize: 11),
                      backgroundColor: Colors.blue.shade50,
                      side: BorderSide.none,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(Product product) {
    final images = product.variantImages ?? [];
    final mainImage = images.isNotEmpty ? images.first : null;
    final thumbnails = images.length > 1 ? images.sublist(1) : <String>[];
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          width: double.infinity,
          color: Colors.grey.shade200,
          child: mainImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.network(
                    ImageService.getFullImageUrl(mainImage),
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) =>
                        const Icon(Icons.error, color: Colors.grey),
                  ),
                )
              : const Center(
                  child: Icon(Icons.inventory_2, size: 60, color: Colors.grey)),
        ),
        if (thumbnails.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.5)
                  ],
                ),
              ),
              child: SizedBox(
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: thumbnails.take(5).map((thumb) {
                    return Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white70, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          ImageService.getFullImageUrl(thumb),
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => const Icon(Icons.error,
                              size: 16, color: Colors.white70),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}