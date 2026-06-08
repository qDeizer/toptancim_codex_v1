class Category {
  final String categoryId;
  final String name;
  final String creatorId;

  Category({
    required this.categoryId,
    required this.name,
    required this.creatorId,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      categoryId: json['category_id'],
      name: json['name'],
      creatorId: json['creator_id'],
    );
  }
}