import 'package:flutter/material.dart';

class Product {
  final String productId;
  final String creatorId;
  String name;
  String? supplierId;
  List<String> categoryIds;
  List<String>? tags;
  bool isActive;
  DateTime? lastPurchaseDate;
  double? wholesalePrice;
  bool createFinancialTransaction;
  final List<ProductVariant> variants;

  List<dynamic>? categoryNames;
  String? supplierName;
  int? variantCount;
  double? totalProfit;
  int? totalStockQuantity;
  int? totalSoldQuantity;
  String? wholesalerName;
  String? wholesalerPhoto;
  double? firstVariantPrice;
  List<String>? variantImages;
  double averageRating;
  List<String> variantThumbnails;

  Product({
    required this.productId,
    required this.creatorId,
    required this.name,
    this.supplierId,
    required this.categoryIds,
    this.tags,
    this.isActive = true,
    this.lastPurchaseDate,
    this.wholesalePrice,
    this.createFinancialTransaction = false,
    required this.variants,
    this.categoryNames,
    this.supplierName,
    this.variantCount,
    this.totalProfit,
    this.totalStockQuantity,
    this.totalSoldQuantity,
    this.wholesalerName,
    this.wholesalerPhoto,
    this.firstVariantPrice,
    this.variantImages,
    this.averageRating = 0.0,
    this.variantThumbnails = const [],
  });

  /// Primary image picked consistently for all surfaces.
  String? get coverImage {
    final activeWithImages = variants.where((v) => v.isActive && v.images != null && v.images!.isNotEmpty);
    if (activeWithImages.isNotEmpty) return activeWithImages.first.images!.first;

    final anyWithImages = variants.where((v) => v.images != null && v.images!.isNotEmpty);
    if (anyWithImages.isNotEmpty) return anyWithImages.first.images!.first;

    if (variantThumbnails.isNotEmpty) return variantThumbnails.first;
    if (variantImages != null && variantImages!.isNotEmpty) return variantImages!.first;
    return null;
  }

  int get totalAvailableStock => (totalStockQuantity ?? 0) - (totalSoldQuantity ?? 0);

  factory Product.fromJson(Map<String, dynamic> json) {
    var variantList = json['variants'] as List? ?? [];
    List<ProductVariant> variants = variantList.isNotEmpty
        ? variantList.map((i) => ProductVariant.fromJson(i)).toList()
        : [];

    var categoryIdList = json['category_ids'] as List? ?? [];
    List<String> categories = categoryIdList.map((i) => i.toString()).toList();

    var imagesList = json['variant_images'] as List?;
    List<String> parsedImages = imagesList != null
        ? imagesList.where((i) => i != null).map((i) => i.toString()).toList()
        : [];
    
    var thumbnailsList = json['variant_thumbnails'] as List?;
    List<String> parsedThumbnails = thumbnailsList != null
        ? thumbnailsList.where((i) => i != null).map((i) => i.toString()).toList()
        : [];

    // If thumbnails are missing, build them from variants (prioritize active ones).
    if (parsedThumbnails.isEmpty && variants.isNotEmpty) {
      final activeVariants = variants
          .where((v) => v.isActive && v.images != null && v.images!.isNotEmpty)
          .toList();
      final fallbackVariants = variants
          .where((v) => v.images != null && v.images!.isNotEmpty)
          .toList();
      final source = activeVariants.isNotEmpty ? activeVariants : fallbackVariants;
      parsedThumbnails = source.map((v) => v.images!.first).toList();
    }

    return Product(
      productId: json['product_id'],
      creatorId: json['creator_id'],
      name: json['name'],
      supplierId: json['supplier_id'],
      categoryIds: categories,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      isActive: json['is_active'] ?? true,
      lastPurchaseDate: json['last_purchase_date'] != null ? DateTime.parse(json['last_purchase_date']) : null,
      wholesalePrice: json['wholesale_price'] != null ? double.tryParse(json['wholesale_price'].toString()) : null,
      createFinancialTransaction: json['create_financial_transaction'] ?? false,
      variants: variants,
      categoryNames: json['category_names'],
      supplierName: json['supplier_name'],
      variantCount: json['variant_count'] != null ? int.tryParse(json['variant_count'].toString()) : null,
      totalProfit: json['total_profit'] != null ? double.tryParse(json['total_profit'].toString()) : null,
      totalStockQuantity: json['total_stock_quantity'] != null ? int.tryParse(json['total_stock_quantity'].toString()) : null,
      totalSoldQuantity: json['total_sold_quantity'] != null ? int.tryParse(json['total_sold_quantity'].toString()) : null,
      wholesalerName: json['wholesaler_name'],
      wholesalerPhoto: json['wholesaler_photo'],
      firstVariantPrice: json['first_variant_price'] != null ? double.tryParse(json['first_variant_price'].toString()) : null,
      variantImages: parsedImages,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      variantThumbnails: parsedThumbnails,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'supplier_id': supplierId,
      'category_ids': categoryIds,
      'tags': tags,
      'is_active': isActive,
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
      'wholesale_price': wholesalePrice,
      'create_financial_transaction': createFinancialTransaction,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }
}

class ProductVariant {
  String? variantId;
  String name;
  String? description;
  double? rating;
  String? shelfLocation;
  List<String>? images;
  double price;
  double? costPrice; // YENİ ALAN
  int stockQuantity;
  int soldQuantity;
  double? variantProfit;
  List<String>? tags;
  bool isActive;
  final UniqueKey localId = UniqueKey();

  int get availableStock => stockQuantity - soldQuantity;

  ProductVariant({
    this.variantId,
    required this.name,
    this.description,
    this.rating,
    this.shelfLocation,
    this.images,
    required this.price,
    this.costPrice, // YENİ
    required this.stockQuantity,
    this.soldQuantity = 0,
    this.variantProfit,
    this.tags,
    this.isActive = true,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      variantId: json['variant_id'],
      name: json['name'] ?? json['variant_name'],
      description: json['description'] ?? json['variant_description'],
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
      shelfLocation: json['shelf_location'],
      images: json['images'] != null ? List<String>.from(json['images']) : (json['variant_images'] != null ? List<String>.from(json['variant_images']) : null),
      price: double.parse(json['price'].toString()),
      costPrice: json['cost_price'] != null ? double.tryParse(json['cost_price'].toString()) : null, // YENİ
      stockQuantity: json['stock_quantity'] != null ? int.parse(json['stock_quantity'].toString()) : 0,
      soldQuantity: json['sold_quantity'] != null ? int.parse(json['sold_quantity'].toString()) : 0,
      variantProfit: json['variant_profit'] != null ? double.tryParse(json['variant_profit'].toString()) : null,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variant_id': variantId, // Güncelleme için önemli
      'name': name,
      'description': description,
      'rating': rating,
      'shelf_location': shelfLocation,
      'images': images,
      'price': price,
      'cost_price': costPrice, // YENİ
      'stock_quantity': stockQuantity,
      'sold_quantity': soldQuantity, // YENİ
      'is_active': isActive,
      'tags': tags,
    };
  }
}
