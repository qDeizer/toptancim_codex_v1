class User {
    final String userId;
    final String userName;
    final String isletmeIsmi;
    final String ad;
    final String soyad;
    final String telNo;
    final String email;
    final String? hakkinda;
    final String? profilFotografi;
    final bool toptanciUyelik;
    final String? role;
    final DateTime? createdAt;
    
    // Flattened address info
    final String? addressTitle;
    final String? address;
    final String? detailedAddress;
    final double? latitude;
    final double? longitude;

    User({
        required this.userId,
        required this.userName,
        required this.isletmeIsmi,
        required this.ad,
        required this.soyad,
        required this.telNo,
        required this.email,
        this.hakkinda,
        this.profilFotografi,
        required this.toptanciUyelik,
        this.role,
        this.createdAt,
        this.addressTitle,
        this.address,
        this.detailedAddress,
        this.latitude,
        this.longitude,
    });

    factory User.fromJson(Map<String, dynamic> json) => User(
        userId: json["user_id"],
        userName: json["user_name"],
        isletmeIsmi: json["isletme_ismi"],
        ad: json["ad"],
        soyad: json["soyad"],
        telNo: json["tel_no"],
        email: json["email"],
        hakkinda: json["hakkinda"],
        profilFotografi: json["profil_fotografi"],
        toptanciUyelik: json["toptanci_uyelik"] ?? false,
        role: json["role"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        addressTitle: json["address_title"],
        address: json["address"],
        detailedAddress: json["detailed_address"],
        latitude: double.tryParse(json['latitude']?.toString() ?? ''),
        longitude: double.tryParse(json['longitude']?.toString() ?? ''),
    );
}