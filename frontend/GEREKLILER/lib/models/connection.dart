class Connection {
  final String relationId;
  final String userId;
  final String? isletmeIsmi;
  final String? ad;
  final String? soyad;
  final String? profilFotografi;
  final String relationRole; // 'customer' or 'wholesaler'
  final bool isInternal;

  Connection({
    required this.relationId,
    required this.userId,
    this.isletmeIsmi,
    this.ad,
    this.soyad,
    this.profilFotografi,
    required this.relationRole,
    required this.isInternal,
  });

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      relationId: json['relation_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      isletmeIsmi: json['isletme_ismi']?.toString(),
      ad: json['ad']?.toString(),
      soyad: json['soyad']?.toString(),
      profilFotografi: json['profil_fotografi']?.toString(),
      relationRole: json['relation_role']?.toString() ?? 'customer',
      isInternal: json['is_internal'] ?? false,
    );
  }

  // Hem işletme adı hem de ad/soyad için birleşik gösterim
  String get displayName {
    if (isletmeIsmi != null && isletmeIsmi!.isNotEmpty) {
      return isletmeIsmi!;
    }
    return fullName;
  }
  
  // Sadece ad ve soyadı birleştiren getter
  String get fullName {
    final firstName = ad ?? '';
    final lastName = soyad ?? '';
    if (firstName.isEmpty && lastName.isEmpty) {
      return 'İsimsiz Bağlantı';
    }
    return '$firstName $lastName'.trim();
  }

  String get roleAsTurkish =>
      relationRole == 'customer' ? 'Müşteri' : 'Toptancı';
}