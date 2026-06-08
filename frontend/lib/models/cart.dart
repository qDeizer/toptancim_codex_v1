import 'cart_item.dart';

class Cart {
  final String cartId;
  final String wholesalerId;
  final String wholesalerName;
  final String? wholesalerPhoto;
  final String? customerId;
  final String? customerName;
  final String? customerPhoto;
  final String status;
  double totalAmount; // mutable yapıyoruz
  final DateTime updatedAt;
  final DateTime? createdAt;
  final DateTime? orderedAt;
  final List<CartItem> items;

  Cart({
    required this.cartId,
    required this.wholesalerId,
    required this.wholesalerName,
    this.wholesalerPhoto,
    this.customerId,
    this.customerName,
    this.customerPhoto,
    required this.status,
    required this.totalAmount,
    required this.updatedAt,
    this.createdAt,
    this.orderedAt,
    required this.items,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<CartItem> parsedItems = [];
    if (itemsList.isNotEmpty && itemsList.first != null) {
      parsedItems = itemsList.map((i) => CartItem.fromJson(i)).toList();
    }
    
    return Cart(
      cartId: json['cart_id'],
      wholesalerId: json['wholesaler_id'] ?? '',
      wholesalerName: json['wholesaler_name'] ?? 'Bilinmeyen Toptancı',
      wholesalerPhoto: json['wholesaler_photo'],
      customerId: json['customer_id'],
      customerName: json['customer_name'],
      customerPhoto: json['customer_photo'],
      status: json['status'],
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      updatedAt: DateTime.parse(json['updated_at']),
      orderedAt: json['ordered_at'] != null ? DateTime.parse(json['ordered_at']) : null,
      items: parsedItems,
    );
  }
}
