import 'package:flutter/material.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/category_provider.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/services/image_service.dart';
import 'package:frontend/widgets/media_picker_sheet.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';

class ProductAddScreen extends StatefulWidget {
  const ProductAddScreen({super.key});

  @override
  State<ProductAddScreen> createState() => _ProductAddScreenState();
}

class _ProductAddScreenState extends State<ProductAddScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // State'i korumak için Controller'lar
  final _productNameController = TextEditingController();
  final _wholesalePriceController = TextEditingController();
  
  String? _selectedSupplierId;
  final List<String> _selectedCategoryIds = [];
  bool _isActive = true;
  final List<ProductVariant> _variants = [];
  bool _isLoading = false;
  final ImageService _imageService = ImageService();

  // Varyant Controller'ları için bir Map
  final Map<UniqueKey, Map<String, TextEditingController>> _variantControllers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ConnectionProvider>(context, listen: false).fetchConnections();
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
    });
    _addVariant(isInitial: true);
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _wholesalePriceController.dispose();
    _variantControllers.forEach((key, controllers) {
      controllers.forEach((field, controller) {
        controller.dispose();
      });
    });
    super.dispose();
  }

  void _addControllersForVariant(ProductVariant variant) {
    _variantControllers[variant.localId] = {
      'name': TextEditingController(text: variant.name),
      'description': TextEditingController(text: variant.description),
      'costPrice': TextEditingController(text: variant.costPrice?.toString() ?? ''),
      'price': TextEditingController(text: variant.price > 0 ? variant.price.toString() : ''),
      'stockQuantity': TextEditingController(text: variant.stockQuantity > 0 ? variant.stockQuantity.toString() : ''),
      'shelfLocation': TextEditingController(text: variant.shelfLocation),
    };
  }

  void _removeControllersForVariant(ProductVariant variant) {
    _variantControllers[variant.localId]?.forEach((_, controller) {
      controller.dispose();
    });
    _variantControllers.remove(variant.localId);
  }

  void _addVariant({bool isInitial = false}) {
    setState(() {
      ProductVariant newVariant;
      if (isInitial || _variants.isEmpty) {
        newVariant = ProductVariant(name: '', price: 0.0, stockQuantity: 0);
      } else {
        final lastVariant = _variants.last;
        final lastVariantControllers = _variantControllers[lastVariant.localId]!;
        
        newVariant = ProductVariant(
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
      }
      _variants.add(newVariant);
      _addControllersForVariant(newVariant);
    });
  }

  void _removeVariant(UniqueKey localId) {
    if (_variants.length <= 1) {
      _showErrorSnackBar('Bir üründe en az bir varyant bulunmalıdır.');
      return;
    }
    setState(() {
      final variantToRemove = _variants.firstWhere((v) => v.localId == localId);
      _removeControllersForVariant(variantToRemove);
      _variants.remove(variantToRemove);
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Lütfen formdaki tüm zorunlu alanları doldurun.');
      return;
    }
    _formKey.currentState!.save();

    for (var variant in _variants) {
      final controllers = _variantControllers[variant.localId]!;
      variant.name = controllers['name']!.text;
      variant.description = controllers['description']!.text;
      variant.costPrice = double.tryParse(controllers['costPrice']!.text);
      variant.price = double.tryParse(controllers['price']!.text) ?? 0.0;
      variant.stockQuantity = int.tryParse(controllers['stockQuantity']!.text) ?? 0;
      variant.shelfLocation = controllers['shelfLocation']!.text;
    }

    setState(() => _isLoading = true);
    final productData = Product(
      productId: '',
      creatorId: '',
      name: _productNameController.text,
      supplierId: _selectedSupplierId,
      categoryIds: _selectedCategoryIds,
      isActive: _isActive,
      wholesalePrice: double.tryParse(_wholesalePriceController.text),
      createFinancialTransaction: false,
      variants: _variants,
    );
    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      await provider.addProduct(productData);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürün başarıyla oluşturuldu!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showErrorSnackBar('İşlem başarısız: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Ürün Oluştur'),
        actions: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _submit,
              tooltip: 'Ürünü Oluştur'
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildProductInfoSection(),
            const SizedBox(height: 24),
            const Text('Ürün Varyantları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ..._variants.asMap().entries.map((entry) {
                int index = entry.key;
                ProductVariant variant = entry.value;
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
              validator: (val) => val!.isEmpty ? 'Ürün adı gerekli' : null,
            ),
            const SizedBox(height: 16),
            Consumer<ConnectionProvider>(
              builder: (ctx, connectionProvider, _) {
                final suppliers = connectionProvider.allConnections.where((c) => c.relationRole == 'wholesaler').toList();
                return DropdownButtonFormField<String>(
                  value: _selectedSupplierId,
                  decoration: const InputDecoration(labelText: 'Ürünü Aldığım Toptancı'),
                  items: suppliers.map((sup) => DropdownMenuItem(value: sup.userId, child: Text(sup.displayName))).toList(),
                  onChanged: (value) => setState(() => _selectedSupplierId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _wholesalePriceController,
              decoration: const InputDecoration(
                labelText: 'Ürünün Genel Alış Fiyatı (₺)',
                prefixIcon: Icon(Icons.attach_money, size: 18),
                helperText: 'Varsayılan maliyet, varyantlarda ayrıca belirtilebilir',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (val) {
                if (val != null && val.isNotEmpty) {
                  final price = double.tryParse(val);
                  if (price == null || price < 0) return 'Geçerli bir fiyat girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Ürün Satışa Açık mı?'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
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
              spacing: 8.0, runSpacing: 4.0,
              children: categoryProvider.categories.map((category) {
                final isSelected = _selectedCategoryIds.contains(category.categoryId);
                return FilterChip(
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategoryIds.add(category.categoryId);
                      } else {
                        _selectedCategoryIds.remove(category.categoryId);
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Varyasyon $index", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_variants.length > 1) IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _removeVariant(variant.localId)),
              ],
            ),
            const Divider(),
            TextFormField(
              controller: controllers['name'],
              decoration: const InputDecoration(labelText: 'Varyant Adı (Örn: Kırmızı, 500g)'),
              validator: (val) => val!.isEmpty ? 'Gerekli' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controllers['description'],
              decoration: const InputDecoration(labelText: 'Varyasyon Açıklaması'),
            ),
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
                  controller: controllers['shelfLocation'],
                  decoration: const InputDecoration(labelText: 'Raf Konumu', prefixIcon: Icon(Icons.location_on, size: 18)),
                )),
              ],
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMiniBtn(Icons.camera_alt, 'Kamera', () => _addSingleImage(variant)),
            const SizedBox(width: 8),
            _buildMiniBtn(Icons.photo_library, 'Galeri', () => _addMultipleImages(variant)),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _addFromMedia(variant),
              icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.deepPurple),
              label: const Text('Medyadan', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.4)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _addFromMedia(ProductVariant variant) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MediaPickerSheet(
        onSelected: (urls) {
          setState(() {
            variant.images ??= [];
            variant.images!.addAll(urls);
          });
        },
      ),
    );
  }

  Future<void> _addSingleImage(ProductVariant variant) async {
    try {
      final XFile? image = await _imageService.showImageSourceDialog(context);
      if (image != null) {
        setState(() => _isLoading = true);
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
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addMultipleImages(ProductVariant variant) async {
    try {
      final List<XFile>? images = await _imageService.pickMultipleImages();
      if (images != null && images.isNotEmpty) {
        setState(() => _isLoading = true);
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
      if(mounted) setState(() => _isLoading = false);
    }
  }
}
