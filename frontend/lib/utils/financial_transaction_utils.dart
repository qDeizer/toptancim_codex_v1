import 'package:flutter/material.dart';
import 'package:frontend/models/financial_transaction.dart';

String transactionTypeLabel(DisplayTransactionType type) {
  switch (type) {
    case DisplayTransactionType.satis:
      return 'Satış';
    case DisplayTransactionType.tahsilat:
      return 'Tahsilat';
    case DisplayTransactionType.alis:
      return 'Alış';
    case DisplayTransactionType.odeme:
      return 'Ödeme';
    case DisplayTransactionType.gelir:
      return 'Gelir';
    case DisplayTransactionType.gider:
      return 'Gider';
    case DisplayTransactionType.bilinmeyen:
      return 'Diğer';
  }
}

IconData transactionTypeIcon(DisplayTransactionType type) {
  switch (type) {
    case DisplayTransactionType.satis:
      return Icons.point_of_sale_rounded;
    case DisplayTransactionType.tahsilat:
      return Icons.south_west_rounded;
    case DisplayTransactionType.alis:
      return Icons.inventory_2_rounded;
    case DisplayTransactionType.odeme:
      return Icons.north_east_rounded;
    case DisplayTransactionType.gelir:
      return Icons.trending_up_rounded;
    case DisplayTransactionType.gider:
      return Icons.trending_down_rounded;
    case DisplayTransactionType.bilinmeyen:
      return Icons.layers_outlined;
  }
}

String transactionDirectionLabel(TransactionDirection direction) {
  switch (direction) {
    case TransactionDirection.incoming:
      return 'Giris';
    case TransactionDirection.outgoing:
      return 'Cikis';
    case TransactionDirection.neutral:
      return 'Cari';
  }
}

String transactionCurrencyLabel(String currency) {
  switch (currency.toUpperCase()) {
    case 'TRY':
      return 'TL';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    default:
      return currency;
  }
}

List<DisplayTransactionType> availableTransactionTypes(
  Iterable<FinancialTransaction> transactions,
) {
  final hasUnknown = transactions.any(
    (transaction) =>
        transaction.displayType == DisplayTransactionType.bilinmeyen,
  );
  final orderedTypes = DisplayTransactionType.values
      .where((type) => type != DisplayTransactionType.bilinmeyen)
      .toList();

  if (hasUnknown) {
    orderedTypes.add(DisplayTransactionType.bilinmeyen);
  }

  return orderedTypes;
}
