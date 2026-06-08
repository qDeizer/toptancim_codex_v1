enum DisplayTransactionType { satis, tahsilat, alis, odeme, gelir, gider, bilinmeyen }
enum TransactionDirection { incoming, outgoing, neutral }

class FinancialTransaction {
  final String id;
  final double amount;
  final String currency;
  final DateTime transactionDate;
  final String? description;
  final String? paymentMethod;
  final String? proofImageUrl;
  // Yorumlanmış Alanlar
  final DisplayTransactionType displayType;
  final TransactionDirection direction;
  final String partnerName;
  final String? partnerId;
  final bool? isPartnerInternal;
  final String? partnerPhoto;
  // Orijinal Veri (Detaylar için)
  final Map<String, dynamic> originalData;
  final String approvalStatus; // onayli, beklemede, reddedildi, iptal_edildi, creator_iptal_talebi, ilgili_iptal_talebi
  final String creatorId;

  FinancialTransaction({
    required this.id,
    required this.amount,
    required this.currency,
    required this.transactionDate,
    this.description,
    this.paymentMethod,
    this.proofImageUrl,
    required this.displayType,
    required this.direction,
    required this.partnerName,
    this.partnerId,
    this.isPartnerInternal,
    this.partnerPhoto,
    required this.originalData,
    required this.approvalStatus,
    required this.creatorId,
  });

  factory FinancialTransaction.fromApi(Map<String, dynamic> json, String myUserId) {
    String fromId = json['from_id'] ?? '';
    String toId = json['to_id'] ?? '';
    String beType = json['transaction_type'] ?? '';

    DisplayTransactionType type = DisplayTransactionType.bilinmeyen;
    TransactionDirection direction = TransactionDirection.neutral;
    String partnerName = 'Bilinmeyen';
    String? partnerId;
    bool? isPartnerInternal;
    String? partnerPhoto;

    if (beType == 'Tahakkuk') {
      if (fromId == myUserId) {
        type = DisplayTransactionType.satis;
        direction = TransactionDirection.neutral;
        partnerName = json['to_name'] ?? 'Müşteri';
        partnerPhoto = json['to_photo'];
        partnerId = toId;
        isPartnerInternal = json['is_to_internal'];
      } else if (toId == myUserId) {
        type = DisplayTransactionType.alis;
        direction = TransactionDirection.neutral;
        partnerName = json['from_name'] ?? 'Toptancı';
        partnerPhoto = json['from_photo'];
        partnerId = fromId;
        isPartnerInternal = json['is_from_internal'];
      }
    } else if (beType == 'Nakit Akışı') {
      if (fromId == myUserId) {
        type = DisplayTransactionType.odeme;
        direction = TransactionDirection.outgoing;
        partnerName = json['to_name'] ?? 'Alıcı';
        partnerPhoto = json['to_photo'];
        partnerId = toId;
        isPartnerInternal = json['is_to_internal'];
      } else if (toId == myUserId) {
        type = DisplayTransactionType.tahsilat;
        direction = TransactionDirection.incoming;
        partnerName = json['from_name'] ?? 'Gönderen';
        partnerPhoto = json['from_photo'];
        partnerId = fromId;
        isPartnerInternal = json['is_from_internal'];
      }
    } else if (beType == 'Doğrudan İşlem') {
      if (fromId == myUserId) {
        type = DisplayTransactionType.gider;
        direction = TransactionDirection.outgoing;
        partnerName = json['to_name'] ?? 'Diğer Gider';
        partnerPhoto = json['to_photo'];
        partnerId = toId;
        isPartnerInternal = json['is_to_internal'];
      } else if (toId == myUserId) {
        type = DisplayTransactionType.gelir;
        direction = TransactionDirection.incoming;
        partnerName = json['from_name'] ?? 'Diğer Gelir';
        partnerPhoto = json['from_photo'];
        partnerId = fromId;
        isPartnerInternal = json['is_from_internal'];
      }
    }

    // Gelir/Gider için partner ismi yoksa açıklamayı kullan
    if ((type == DisplayTransactionType.gelir || type == DisplayTransactionType.gider) && (partnerName == 'Diğer Gelir' || partnerName == 'Diğer Gider')) {
        partnerName = json['description']?.isNotEmpty == true ? json['description'] : partnerName;
    }

    return FinancialTransaction(
      id: json['transaction_id'],
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      currency: json['currency'] ?? 'TRY',
      transactionDate: DateTime.parse(json['transaction_date']),
      description: json['description'],
      paymentMethod: json['payment_method'],
      proofImageUrl: json['proof_url'],
      displayType: type,
      direction: direction,
      partnerName: partnerName,
      partnerId: partnerId,
      isPartnerInternal: isPartnerInternal,
      partnerPhoto: partnerPhoto,
      originalData: json,
      approvalStatus: json['approval_status'] ?? 'onayli',
      creatorId: json['creator_id'] ?? '',
    );
  }
}
