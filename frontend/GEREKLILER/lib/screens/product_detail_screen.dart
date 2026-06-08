import 'package:flutter/material.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/services/image_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Detayları'),
      ),
      body: FutureBuilder<Product>(
        future: Provider.of<ProductProvider>(context, listen: false).fetchProductById(productId),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error.toString()}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Ürün bulunamadı.'));
          }

          final product = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildProductMainImage(product),
              const SizedBox(height: 16),
              _buildInfoCard(context, product),
              const SizedBox(height: 24),
              Text(
                'Varyantlar (${product.variants.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              ...product.variants.asMap().entries.map((entry) {
                return _buildVariantCard(context, entry.value, entry.key + 1);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, Product product) {
    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(context, Icons.info_outline, 'Durum', product.isActive ? 'Aktif' : 'Pasif'),
            _buildInfoRow(context, Icons.person_outline, 'Tedarikçi', product.supplierName ?? 'Belirtilmemiş'),
            _buildInfoRow(context, Icons.category_outlined, 'Kategoriler', 
              product.categoryNames != null && product.categoryNames!.isNotEmpty 
                ? product.categoryNames!.join(', ') 
                : 'Kategori yok'),
            const Divider(height: 20),
            _buildInfoRow(context, Icons.monetization_on, 'Toplam Kar', 
              formatCurrency.format(product.totalProfit ?? 0), 
              valueColor: Colors.green, isValueBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantCard(BuildContext context, ProductVariant variant, int index) {
     final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Varyasyon $index: ${variant.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            if(variant.description != null && variant.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(variant.description!),
              ),
            _buildInfoRow(context, Icons.attach_money, 'Satış Fiyatı', formatCurrency.format(variant.price)),
            _buildInfoRow(context, Icons.arrow_downward, 'Toplam Alınan', '${variant.stockQuantity} adet', valueColor: Colors.blue),
            _buildInfoRow(context, Icons.arrow_upward, 'Toplam Satılan', '${variant.soldQuantity} adet', valueColor: Colors.red),
            _buildInfoRow(context, Icons.inventory_2_outlined, 'Mevcut Stok', '${variant.availableStock} adet', valueColor: Colors.green, isValueBold: true),
            _buildInfoRow(context, Icons.location_on_outlined, 'Raf Konumu', variant.shelfLocation ?? 'Belirtilmemiş'),
            _buildInfoRow(context, Icons.local_offer_outlined, 'Varyant Durumu', variant.isActive ? 'Aktif' : 'Pasif'),
            const Divider(height: 20),
            _buildInfoRow(context, Icons.trending_up, 'Bu Varyanttan Gelen Kar', formatCurrency.format(variant.variantProfit ?? 0), valueColor: Colors.green, isValueBold: true),
            if (variant.images != null && variant.images!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Resimler:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: variant.images!.length,
                  itemBuilder: (context, imgIndex) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          ImageService.getFullImageUrl(variant.images![imgIndex]),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[300],
                              child: const Icon(Icons.error),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {Color? valueColor, bool isValueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(color: valueColor, fontWeight: isValueBold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }

  Widget _buildProductMainImage(Product product) {
    final String? mainImageUrl = product.coverImage ??
        (product.variantThumbnails.isNotEmpty ? product.variantThumbnails.first : null);

    if (mainImageUrl != null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            ImageService.getFullImageUrl(mainImageUrl),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      Text('Resim yüklenemedi', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      );
    } else {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 50, color: Colors.grey),
              SizedBox(height: 8),
              Text('Ürün resmi yok', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
  }}
