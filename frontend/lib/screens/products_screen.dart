import 'package:flutter/material.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/product_add_screen.dart';
import 'package:frontend/screens/product_detail_screen.dart';
import 'package:frontend/screens/product_edit_screen.dart';
import 'package:frontend/services/image_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  Future<void>? _fetchProductsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _fetchProductsFuture = Provider.of<ProductProvider>(context, listen: false).fetchProducts();
        });
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _navigateToEdit(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductEditScreen(productId: product.productId),
      ),
    ).then((_) {
      setState(() {
        _fetchProductsFuture = Provider.of<ProductProvider>(context, listen: false).fetchProducts();
      });
    });
  }
  
  void _navigateToCreate() {
     Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProductAddScreen(),
      ),
    ).then((_) {
      setState(() {
        _fetchProductsFuture = Provider.of<ProductProvider>(context, listen: false).fetchProducts();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürünlerim'),
      ),
      body: FutureBuilder(
          future: _fetchProductsFuture,
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _fetchProductsFuture != null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Ürünler yüklenemedi: ${snapshot.error}'));
            }

            return RefreshIndicator(
              onRefresh: () {
                final future = Provider.of<ProductProvider>(context, listen: false).fetchProducts();
                setState(() {
                  _fetchProductsFuture = future;
                });
                return future;
              },
              child: Consumer<ProductProvider>(
                builder: (ctx, productProvider, child) {
                  if (productProvider.products.isEmpty) {
                    return const Center(child: Text('Henüz ürün eklenmemiş.'));
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: productProvider.products.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400.0,
                      childAspectRatio: 0.8, 
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (ctx, i) {
                      final Product product = productProvider.products[i];
                      return _buildProductCard(context, product);
                    },
                  );
                },
              ),
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        tooltip: 'Yeni Ürün Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.productId)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildImageSection(product),
            ),
            _buildInfoSection(context, product),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(Product product) {
    final String? mainImage = product.coverImage ??
        (product.variantThumbnails.isNotEmpty ? product.variantThumbnails.first : null);

    final List<String> thumbnails = product.variantThumbnails
        .where((thumb) => thumb != mainImage)
        .toList();

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
                    errorBuilder: (ctx, err, st) => const Icon(Icons.error, color: Colors.grey),
                  ),
                )
              : const Center(child: Icon(Icons.inventory_2, size: 60, color: Colors.grey)),
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
                  colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.5)],
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
                          errorBuilder: (ctx, err, st) => const Icon(Icons.error, size: 16, color: Colors.white70),
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

  Widget _buildInfoSection(BuildContext context, Product product) {
    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final categories = product.categoryNames?.take(3).toList() ?? [];
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 30,
                child: PopupMenuButton<String>(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _navigateToEdit(product);
                    } else if (value == 'delete') {
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          title: const Text('Emin misiniz?'),
                          content: Text('\'${product.name}\' adlı ürünü silmek üzeresiniz.\nBu işlem geri alınamaz.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('İptal')),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(dialogCtx).pop();
                                try {
                                  await productProvider.deleteProduct(product.productId);
                                } catch (e) {
                                  _showErrorSnackBar('Ürün silinemedi: ${e.toString()}');
                                }
                              },
                              child: const Text('Sil', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Düzenle'))),
                    const PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('Sil'))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formatCurrency.format(product.firstVariantPrice ?? 0),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              if (categories.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.start,
                    children: categories.map((cat) => Chip(
                      label: Text(cat),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      labelStyle: const TextStyle(fontSize: 11),
                      backgroundColor: Colors.blue.shade50,
                      side: BorderSide.none,
                    )).toList(),
                  ),
                ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(Icons.inventory_2_outlined, '${product.totalAvailableStock} Adet', Colors.green),
              _buildStatItem(
                Icons.circle,
                product.isActive ? 'Aktif' : 'Pasif',
                product.isActive ? Colors.green : Colors.red,
              ),
              _buildStatItem(Icons.monetization_on_outlined, formatCurrency.format(product.totalProfit ?? 0), Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: color)),
      ],
    );
  }
}
