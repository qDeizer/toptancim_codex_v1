class CartItem {
  final String cartItemId;
  final String variantId;
  final int quantity;
  final double price;
  final String variantName;
  final String? variantImage;
  final String productName;

  CartItem({
    required this.cartItemId,
    required this.variantId,
    required this.quantity,
    required this.price,
    required this.variantName,
    this.variantImage,
    required this.productName,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartItemId: json['cart_item_id'],
      variantId: json['variant_id'],
      quantity: json['quantity'],
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      variantName: json['variant_name'] ?? 'Bilinmeyen Varyant',
      variantImage: json['variant_image'],
      productName: json['product_name'] ?? 'Bilinmeyen Ürün',
    );
  }

  String get displayName => '$productName - $variantName';
}