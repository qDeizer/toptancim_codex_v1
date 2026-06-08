import 'package:flutter/material.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/services/image_service.dart';
import 'package:provider/provider.dart';

class CustomerProductDetailScreen extends StatefulWidget {
  final Product product;
  const CustomerProductDetailScreen({super.key, required this.product});

  @override
  State<CustomerProductDetailScreen> createState() =>
      _CustomerProductDetailScreenState();
}

class _CustomerProductDetailScreenState
    extends State<CustomerProductDetailScreen> {
  int _quantity = 1;
  late ProductVariant _selectedVariant;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.product.variants.first;
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changeVariant(ProductVariant newVariant) {
    setState(() {
      _selectedVariant = newVariant;
      _quantity = 1;
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _openFullScreenImage(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.8),
        pageBuilder: (BuildContext context, _, __) {
          return FullScreenImageViewer(
            imageUrls: _selectedVariant.images!,
            initialIndex: initialIndex,
          );
        },
      ),
    );
  }



  void _addToCart() {
    if (_quantity > _selectedVariant.availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Stok yetersiz. Bu üründen en fazla ${_selectedVariant.availableStock} adet alabilirsiniz.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider
        .addItemToCart(
      variantId: _selectedVariant.variantId!,
      quantity: _quantity,
      wholesalerId: widget.product.creatorId,
    )
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$_quantity adet "${widget.product.name} - ${_selectedVariant.name}" sepete eklendi.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${error.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.product.name} - ${_selectedVariant.name}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120), // bottom bar height
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGalleryAndThumbnails(),
            _buildVariantSelector(),
            _buildProductDetails(),
          ],
        ),
      ),
      bottomSheet: _buildStickyBottomBar(),
    );
  }

  Widget _buildGalleryAndThumbnails() {
    final images = _selectedVariant.images;
    if (images == null || images.isEmpty) {
      return Container(
        height: 480,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: Icon(Icons.inventory_2, size: 100, color: Colors.grey)),
      );
    }
    return Container(
      height: 480,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () => _openFullScreenImage(context, _currentPage),
              child: PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Hero(
                    tag: 'product_image_${images[index]}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        ImageService.getFullImageUrl(images[index]),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                              child: Icon(Icons.error,
                                  color: Colors.grey, size: 50)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (images.length > 1)
            SizedBox(
              width: 60,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ListView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _currentPage == index
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            ImageService.getFullImageUrl(images[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVariantSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: widget.product.variants.map((variant) {
          final isSelected = _selectedVariant.variantId == variant.variantId;
          final imageUrl = variant.images != null && variant.images!.isNotEmpty
              ? variant.images!.first
              : null;
          return GestureDetector(
            onTap: () => _changeVariant(variant),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                  width: 2,
                ),
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 32,
                      color: Colors.grey.shade200,
                      child: imageUrl != null
                          ? Image.network(
                              ImageService.getFullImageUrl(imageUrl),
                              fit: BoxFit.cover)
                          : const Icon(Icons.image_not_supported,
                              size: 16, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    variant.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildProductDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Açıklama önce
          if (_selectedVariant.description != null &&
              _selectedVariant.description!.isNotEmpty) ...[
            Text(
              _selectedVariant.description!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Toptancı bilgisi sonra
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: widget.product.wholesalerPhoto != null
                    ? NetworkImage(ImageService.getFullImageUrl(widget.product.wholesalerPhoto!))
                    : null,
                child: widget.product.wholesalerPhoto == null
                    ? const Icon(Icons.store, size: 14)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toptancı',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600, fontSize: 11),
                    ),
                    Text(
                      widget.product.wholesalerName ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    bool isOutOfStock = _selectedVariant.availableStock <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
          )
        ],
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_selectedVariant.price} ₺',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                isOutOfStock ? 'Stokta Yok' : 'Stokta Var',
                style: TextStyle(
                    color: isOutOfStock ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: isOutOfStock
                    ? null
                    : () {
                        if (_quantity > 1) {
                          setState(() => _quantity--);
                        }
                      },
              ),
              Text('$_quantity', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: isOutOfStock
                    ? null
                    : () {
                        setState(() => _quantity++);
                      },
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isOutOfStock ? null : _addToCart,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  backgroundColor: isOutOfStock ? Colors.grey : null,
                ),
                child: const Icon(Icons.add_shopping_cart),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: widget.imageUrls.length > 1
            ? Text(
                '${_currentIndex + 1} / ${widget.imageUrls.length}',
                style: const TextStyle(color: Colors.white),
              )
            : null,
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Hero(
            tag: 'product_image_${widget.imageUrls[index]}',
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  ImageService.getFullImageUrl(widget.imageUrls[index]),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 50),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}