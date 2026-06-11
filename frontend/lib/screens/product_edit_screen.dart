import 'package:flutter/material.dart';
import 'package:frontend/models/category.dart';
import 'package:frontend/models/connection.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/category_provider.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/media_provider.dart';
import 'package:frontend/models/media.dart';
import 'package:frontend/services/image_service.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';

class ProductEditScreen extends StatefulWidget {
  final String productId;
  const ProductEditScreen({super.key, required this.productId});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  Product? _product;
  bool _isLoading = true;
  bool _isUpdating = false;
  final _formKey = GlobalKey<FormState>();
  final ImageService _imageService = ImageService();
  final List<String> _deletedVariantIds = [];

  final Map<UniqueKey, Map<String, TextEditingController>> _variantControllers = {};
  final _productNameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadProductAndProviders();
  }
  
  @override
  void dispose() {
    _productNameController.dispose();
    _variantControllers.forEach((key, controllers) {
      controllers.forEach((field, controller) {
        controller.dispose();
      });
    });
    super.dispose();
  }

  Future<void> _loadProductAndProviders() async {
    try {
      await Future.wait([
        Provider.of<ConnectionProvider>(context, listen: false).fetchConnections(),
        Provider.of<CategoryProvider>(context, listen: false).fetchCategories()
      ]);
      final product = await Provider.of<ProductProvider>(context, listen: false)
          .fetchProductById(widget.productId);
      setState(() {
        _product = product;
        _productNameController.text = _product!.name;
        
        for (var variant in _product!.variants) {
          _addControllersForVariant(variant);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Ürün yüklenemedi: ${e.toString()}');
        Navigator.of(context).pop();
      }
    }
  }

  void _addControllersForVariant(ProductVariant variant) {
    _variantControllers[variant.localId] = {
      'name': TextEditingController(text: variant.name),
      'description': TextEditingController(text: variant.description),
      'costPrice': TextEditingController(text: variant.costPrice?.toString() ?? ''),
      'price': TextEditingController(text: variant.price > 0 ? variant.price.toString() : ''),
      'stockQuantity': TextEditingController(text: variant.stockQuantity.toString()),
      'soldQuantity': TextEditingController(text: variant.soldQuantity.toString()),
      'shelfLocation': TextEditingController(text: variant.shelfLocation),
    };
  }

  void _removeControllersForVariant(ProductVariant variant) {
    _variantControllers[variant.localId]?.forEach((_, controller) {
      controller.dispose();
    });
    _variantControllers.remove(variant.localId);
  }
  
  void _addVariant() {
    setState(() {
      final lastVariant = _product!.variants.last;
      final lastVariantControllers = _variantControllers[lastVariant.localId]!;
      
      final newVariant = ProductVariant(
        name: '', // Kullanıcı talebi: Varyant adı hep boş gelsin
        description: lastVariantControllers['description']!.text,
        price: double.tryParse(lastVariantControllers['price']!.text) ?? 0.0,
        costPrice: double.tryParse(lastVariantControllers['costPrice']!.text),
        stockQuantity: int.tryParse(lastVariantControllers['stockQuantity']!.text) ?? 0,
        soldQuantity: 0,
        shelfLocation: lastVariantControllers['shelfLocation']!.text,
        isActive: lastVariant.isActive,
        tags: List<String>.from(lastVariant.tags ?? []),
        images: [],
      );
      _product!.variants.add(newVariant);
      _addControllersForVariant(newVariant);
    });
  }

  void _removeVariant(ProductVariant variant) {
    if (_product!.variants.length <= 1) {
      _showErrorSnackBar('Bir üründe en az bir varyant bulunmalıdır.');
      return;
    }
    setState(() {
      if (variant.variantId != null) {
        _deletedVariantIds.add(variant.variantId!);
      }
      _removeControllersForVariant(variant);
      _product!.variants.removeWhere((v) => v.localId == variant.localId);
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
       _showErrorSnackBar('Lütfen formdaki tüm zorunlu alanları doldurun.');
      return;
    }
    _formKey.currentState!.save();

    _product!.name = _productNameController.text;
    for (var variant in _product!.variants) {
      final controllers = _variantControllers[variant.localId]!;
      variant.name = controllers['name']!.text;
      variant.description = controllers['description']!.text;
      variant.costPrice = double.tryParse(controllers['costPrice']!.text);
      variant.price = double.tryParse(controllers['price']!.text) ?? 0.0;
      variant.stockQuantity = int.tryParse(controllers['stockQuantity']!.text) ?? 0;
      variant.soldQuantity = int.tryParse(controllers['soldQuantity']!.text) ?? 0;
      variant.shelfLocation = controllers['shelfLocation']!.text;
    }

    setState(() => _isUpdating = true);

    final Map<String, dynamic> payload = _product!.toJson();
    payload['deleted_variant_ids'] = _deletedVariantIds;
    
    try {
      await Provider.of<ProductProvider>(context, listen: false)
          .updateProduct(widget.productId, payload);
      if (mounted) {
        _showErrorSnackBar('Ürün başarıyla güncellendi', isError: false);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
         _showErrorSnackBar('Güncelleme hatası: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showErrorSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ürün Yükleniyor...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Düzenle: ${_product!.name}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Değişiklikleri Kaydet',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProductInfoSection(),
            const SizedBox(height: 24),
            const Text('Ürün Varyantları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ..._product!.variants.asMap().entries.map((entry) {
              final index = entry.key;
              final variant = entry.value;
              return _buildVariantCard(variant, index + 1);
            }),
            const SizedBox(height: 16),
             DottedBorder(
              color: Colors.grey, strokeWidth: 1, dashPattern: const [6, 6],
              child: InkWell(
                onTap: _addVariant,
                child: Container(
                  height: 50, alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.add, color: Colors.grey), SizedBox(width: 8), Text('Yeni Varyant Ekle')],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfoSection() {
     return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Genel Bilgiler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _productNameController,
              decoration: const InputDecoration(labelText: 'Ürün Adı'),
              validator: (value) => value?.isEmpty ?? true ? 'Ürün adı gerekli' : null,
            ),
            const SizedBox(height: 16),
            Consumer<ConnectionProvider>(
              builder: (ctx, connectionProvider, _) {
                final suppliers = connectionProvider.allConnections
                    .where((c) => c.relationRole == 'wholesaler')
                    .toList();
                return DropdownButtonFormField<String>(
                  value: _product!.supplierId,
                  decoration: const InputDecoration(labelText: 'Ürünü Aldığım Toptancı'),
                  items: suppliers
                      .map((sup) => DropdownMenuItem(
                            value: sup.userId,
                            child: Text(sup.displayName),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _product!.supplierId = value),
                );
              },
            ),
            const SizedBox(height: 16),
             _buildCategorySelector(),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Ürün Aktif mi?'),
              value: _product!.isActive,
              onChanged: (value) => setState(() => _product!.isActive = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Consumer<CategoryProvider>(
      builder: (ctx, categoryProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("Kategoriler", style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: categoryProvider.categories.map((category) {
                final isSelected = _product!.categoryIds.contains(category.categoryId);
                return FilterChip(
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _product!.categoryIds.add(category.categoryId);
                      } else {
                        _product!.categoryIds.remove(category.categoryId);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVariantCard(ProductVariant variant, int index) {
     final controllers = _variantControllers[variant.localId]!;
     return Card(
      key: ValueKey(variant.localId),
      margin: const EdgeInsets.symmetric(vertical: 8),
       color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Varyasyon $index", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _removeVariant(variant)),
              ],
            ),
            const Divider(),
            TextFormField(controller: controllers['name'], decoration: const InputDecoration(labelText: 'Varyant Adı'), validator: (val) => val!.isEmpty ? 'Gerekli' : null),
            const SizedBox(height: 8),
            TextFormField(controller: controllers['description'], decoration: const InputDecoration(labelText: 'Varyasyon Açıklaması')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: controllers['costPrice'],
                  decoration: const InputDecoration(labelText: 'Alış Fiyatı (₺)', prefixIcon: Icon(Icons.money_off, size: 18)),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(
                  controller: controllers['price'],
                  decoration: const InputDecoration(labelText: 'Satış Fiyatı (₺)', prefixIcon: Icon(Icons.attach_money, size: 18)),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Fiyat gerekli';
                    final price = double.tryParse(val);
                    if (price == null || price <= 0) return 'Geçerli bir fiyat girin';
                    return null;
                  },
                )),
              ],
            ),
             const SizedBox(height: 8),
            Row(
              children: [
                 Expanded(child: TextFormField(
                  controller: controllers['stockQuantity'],
                  decoration: const InputDecoration(labelText: 'Stok Adedi', prefixIcon: Icon(Icons.inventory, size: 18)),
                  keyboardType: TextInputType.number,
                   validator: (val) {
                    if (val == null || val.isEmpty) return 'Stok adedi gerekli';
                    final stock = int.tryParse(val);
                    if (stock == null || stock < 0) return 'Geçerli bir stok adedi girin';
                    return null;
                  },
                )),
                 const SizedBox(width: 8),
                 Expanded(child: TextFormField(
                  controller: controllers['soldQuantity'],
                  decoration: const InputDecoration(labelText: 'Satılan Adet', prefixIcon: Icon(Icons.sell, size: 18)),
                  keyboardType: TextInputType.number,
                   validator: (val) {
                    if (val == null || val.isEmpty) return 'Satılan adet gerekli';
                    final stock = int.tryParse(val);
                    if (stock == null || stock < 0) return 'Geçerli bir adet girin';
                    return null;
                  },
                )),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controllers['shelfLocation'],
              decoration: const InputDecoration(labelText: 'Raf Konumu', prefixIcon: Icon(Icons.location_on, size: 18)),
            ),
            const SizedBox(height: 16),
            _buildImageSection(variant),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(ProductVariant variant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ürün Resimleri', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (variant.images != null && variant.images!.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: variant.images!.length,
              itemBuilder: (context, index) {
                final imageUrl = variant.images![index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          ImageService.getFullImageUrl(imageUrl),
                          width: 100, height: 100, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 100, height: 100, color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => variant.images!.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                       if (index == 0)
                        Positioned(
                          bottom: 4, left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Kapak', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _addSingleImage(variant),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Resim Ekle'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _addMultipleImages(variant),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Çoklu Resim'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addFromMedia(ProductVariant variant) async {
    final media = context.read<MediaProvider>().media;
    if (!mounted) return;
    final selected = await showDialog<MediaItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Medyadan Seç'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemCount: media.length,
            itemBuilder: (_, i) {
              final item = media[i];
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, item),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(ImageService.getFullImageUrl(item.url), fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal'))],
      ),
    );
    if (selected != null) {
      setState(() {
        variant.images ??= [];
        variant.images!.add(selected.url);
      });
    }
  }

  Future<void> _addSingleImage(ProductVariant variant) async {
    try {
      final XFile? image = await _imageService.showImageSourceDialog(context);
      if (image != null) {
        setState(() => _isUpdating = true);
        final imageUrls = await _imageService.uploadProductImages([image]);
        if (imageUrls != null && imageUrls.isNotEmpty) {
          setState(() {
            variant.images ??= [];
            variant.images!.addAll(imageUrls);
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Resim yükleme hatası: ${e.toString()}');
    } finally {
      if(mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _addMultipleImages(ProductVariant variant) async {
     try {
      final List<XFile>? images = await _imageService.pickMultipleImages();
      if (images != null && images.isNotEmpty) {
        setState(() => _isUpdating = true);
        final imageUrls = await _imageService.uploadProductImages(images);
        if (imageUrls != null && imageUrls.isNotEmpty) {
          setState(() {
            variant.images ??= [];
            variant.images!.addAll(imageUrls);
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Resim yükleme hatası: ${e.toString()}');
    } finally {
      if(mounted) setState(() => _isUpdating = false);
    }
  }
}
