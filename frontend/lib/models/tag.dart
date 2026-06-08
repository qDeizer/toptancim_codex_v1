class Tag {
  final String tagId;
  final String name;
  final String? note;
  final double? pricingPercentage;
  final double? pricingDelta;
  final String creatorId;

  Tag({
    required this.tagId,
    required this.name,
    this.note,
    this.pricingPercentage,
    this.pricingDelta,
    required this.creatorId,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      tagId: json['tag_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      note: json['note']?.toString(),
      pricingPercentage: json['pricing_percentage'] != null ? double.tryParse(json['pricing_percentage'].toString()) : null,
      pricingDelta: json['pricing_delta'] != null ? double.tryParse(json['pricing_delta'].toString()) : null,
      creatorId: json['creator_id']?.toString() ?? '',
    );
  }
}