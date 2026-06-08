import 'package:frontend/models/tag.dart';

class ConnectionDetails {
  final String id;
  final String? ad;
  final String? soyad;
  final String? isletmeIsmi;
  final String? telNo;
  final String? email;
  final String? profilFotografi;
  
  // Flattened address info
  final String? addressTitle;
  final String? address;
  final String? detailedAddress;
  final double? latitude;
  final double? longitude;

  final List<String> roles;
  final String scope;
  final List<Tag> tags;
  final bool canEdit;
  final bool wholesalerApproval;
  final bool customerApproval;
  final String relationId;
  final bool isWholesaler;

  ConnectionDetails({
    required this.id,
    this.ad,
    this.soyad,
    this.isletmeIsmi,
    this.telNo,
    this.email,
    this.profilFotografi,
    this.addressTitle,
    this.address,
    this.detailedAddress,
    this.latitude,
    this.longitude,
    required this.roles,
    required this.scope,
    required this.tags,
    required this.canEdit,
    required this.wholesalerApproval,
    required this.customerApproval,
    required this.relationId,
    required this.isWholesaler,
  });

  String get fullName {
    if ((ad == null || ad!.isEmpty) && (soyad == null || soyad!.isEmpty)) {
      return 'İsimsiz';
    }
    return '${ad ?? ''} ${soyad ?? ''}'.trim();
  }

  String get displayName {
    if (isletmeIsmi != null && isletmeIsmi!.isNotEmpty) {
      return isletmeIsmi!;
    }
    return fullName;
  }

  String get addressAsString {
    if (address == null && detailedAddress == null) {
      return 'Adres belirtilmemiş';
    }
    return [addressTitle, address, detailedAddress]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
  }

  factory ConnectionDetails.fromJson(Map<String, dynamic> json) {
    var tagsList = json['tags'] as List? ?? [];
    List<Tag> parsedTags = tagsList.map((i) => Tag.fromJson(i)).toList();
    
    var rolesList = json['roles'] as List? ?? [];
    List<String> parsedRoles = rolesList.map((i) => i.toString()).toList();

    return ConnectionDetails(
      id: json['id'],
      ad: json['ad'],
      soyad: json['soyad'],
      isletmeIsmi: json['isletme_ismi'],
      telNo: json['tel_no'],
      email: json['email'],
      profilFotografi: json['profil_fotografi'],
      addressTitle: json['address_title'],
      address: json['address'],
      detailedAddress: json['detailed_address'],
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      roles: parsedRoles,
      scope: json['scope'],
      tags: parsedTags,
      canEdit: json['can_edit'] ?? false,
      wholesalerApproval: json['wholesaler_approval'] ?? true,
      customerApproval: json['customer_approval'] ?? true,
      relationId: json['relation_id'] ?? '',
      isWholesaler: json['is_wholesaler'] ?? false,
    );
  }
}