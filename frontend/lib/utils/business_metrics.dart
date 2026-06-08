import 'package:frontend/models/cart.dart';
import 'package:frontend/models/financial_transaction.dart';
import 'package:frontend/models/product.dart';

class VariantMetrics {
  final String variantId;
  final String productName;
  final String variantName;
  final String shelfLocation;
  final double unitPrice;
  final double? unitCost;
  final int stockQuantity;
  final int soldQuantity;

  const VariantMetrics({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.shelfLocation,
    required this.unitPrice,
    required this.unitCost,
    required this.stockQuantity,
    required this.soldQuantity,
  });

  int get availableStock => stockQuantity - soldQuantity;
}

class DemandItemMetrics {
  final String variantId;
  final String productName;
  final String variantName;
  final String shelfLocation;
  final int quantity;
  final int stopCount;
  final double expectedRevenue;
  final double expectedProfit;
  final int availableStock;

  const DemandItemMetrics({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.shelfLocation,
    required this.quantity,
    required this.stopCount,
    required this.expectedRevenue,
    required this.expectedProfit,
    required this.availableStock,
  });
}

class MonthlyFinanceMetrics {
  final DateTime month;
  double sales;
  double collections;
  double purchases;
  double payments;
  double otherIncome;
  double otherExpense;

  MonthlyFinanceMetrics({
    required this.month,
    this.sales = 0,
    this.collections = 0,
    this.purchases = 0,
    this.payments = 0,
    this.otherIncome = 0,
    this.otherExpense = 0,
  });

  double get netCashFlow => collections + otherIncome - payments - otherExpense;
}

class PartnerLedgerMetrics {
  final String partnerId;
  final String partnerName;
  final double sales;
  final double collections;
  final double purchases;
  final double payments;
  final DateTime? lastMovementAt;

  const PartnerLedgerMetrics({
    required this.partnerId,
    required this.partnerName,
    required this.sales,
    required this.collections,
    required this.purchases,
    required this.payments,
    required this.lastMovementAt,
  });

  double get receivable => sales - collections;
  double get payable => purchases - payments;
}

bool isApprovedTransaction(FinancialTransaction transaction) {
  return transaction.approvalStatus.isEmpty ||
      transaction.approvalStatus == 'onayli';
}

Map<String, VariantMetrics> buildVariantMetricsIndex(List<Product> products) {
  final index = <String, VariantMetrics>{};
  for (final product in products) {
    for (final variant in product.variants) {
      final variantId = variant.variantId;
      if (variantId == null || variantId.isEmpty) {
        continue;
      }
      index[variantId] = VariantMetrics(
        variantId: variantId,
        productName: product.name,
        variantName: variant.name,
        shelfLocation: variant.shelfLocation?.trim().isNotEmpty == true
            ? variant.shelfLocation!.trim()
            : 'Belirtilmemiş',
        unitPrice: variant.price,
        unitCost: variant.costPrice,
        stockQuantity: variant.stockQuantity,
        soldQuantity: variant.soldQuantity,
      );
    }
  }
  return index;
}

double estimateCartProfit(
  Cart cart,
  Map<String, VariantMetrics> variantIndex,
) {
  return cart.items.fold<double>(0, (sum, item) {
    final variant = variantIndex[item.variantId];
    final cost = variant?.unitCost ?? 0;
    return sum + ((item.price - cost) * item.quantity);
  });
}

List<DemandItemMetrics> buildDemandMetrics(
  List<Cart> carts,
  Map<String, VariantMetrics> variantIndex,
) {
  final bucket = <String, DemandItemMetrics>{};

  for (final cart in carts) {
    for (final item in cart.items) {
      final variant = variantIndex[item.variantId];
      final existing = bucket[item.variantId];
      final expectedProfit =
          ((item.price - (variant?.unitCost ?? 0)) * item.quantity);

      bucket[item.variantId] = DemandItemMetrics(
        variantId: item.variantId,
        productName: variant?.productName ?? item.productName,
        variantName: variant?.variantName ?? item.variantName,
        shelfLocation: variant?.shelfLocation ?? 'Belirtilmemiş',
        quantity: (existing?.quantity ?? 0) + item.quantity,
        stopCount: (existing?.stopCount ?? 0) + 1,
        expectedRevenue:
            (existing?.expectedRevenue ?? 0) + (item.price * item.quantity),
        expectedProfit: (existing?.expectedProfit ?? 0) + expectedProfit,
        availableStock: variant?.availableStock ?? 0,
      );
    }
  }

  final items = bucket.values.toList();
  items.sort((a, b) => b.quantity.compareTo(a.quantity));
  return items;
}

List<MonthlyFinanceMetrics> buildMonthlyFinanceMetrics(
  List<FinancialTransaction> transactions, {
  int months = 6,
}) {
  final now = DateTime.now();
  final series = <MonthlyFinanceMetrics>[];
  for (var i = months - 1; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    series.add(MonthlyFinanceMetrics(month: month));
  }

  for (final transaction in transactions.where(isApprovedTransaction)) {
    final monthKey = DateTime(
      transaction.transactionDate.year,
      transaction.transactionDate.month,
      1,
    );

    final slot = series.where((entry) => entry.month == monthKey);
    if (slot.isEmpty) {
      continue;
    }
    final entry = slot.first;

    switch (transaction.displayType) {
      case DisplayTransactionType.satis:
        entry.sales += transaction.amount;
        break;
      case DisplayTransactionType.tahsilat:
        entry.collections += transaction.amount;
        break;
      case DisplayTransactionType.alis:
        entry.purchases += transaction.amount;
        break;
      case DisplayTransactionType.odeme:
        entry.payments += transaction.amount;
        break;
      case DisplayTransactionType.gelir:
        entry.otherIncome += transaction.amount;
        break;
      case DisplayTransactionType.gider:
        entry.otherExpense += transaction.amount;
        break;
      case DisplayTransactionType.bilinmeyen:
        break;
    }
  }

  return series;
}

List<PartnerLedgerMetrics> buildPartnerLedgerMetrics(
  List<FinancialTransaction> transactions,
) {
  final ledger = <String, _PartnerLedgerAccumulator>{};

  for (final transaction in transactions.where(isApprovedTransaction)) {
    final partnerId = transaction.partnerId;
    if (partnerId == null || partnerId.isEmpty) {
      continue;
    }

    final entry = ledger.putIfAbsent(
      partnerId,
      () => _PartnerLedgerAccumulator(
        partnerId: partnerId,
        partnerName: transaction.partnerName,
      ),
    );

    if (entry.lastMovementAt == null ||
        transaction.transactionDate.isAfter(entry.lastMovementAt!)) {
      entry.lastMovementAt = transaction.transactionDate;
    }

    switch (transaction.displayType) {
      case DisplayTransactionType.satis:
        entry.sales += transaction.amount;
        break;
      case DisplayTransactionType.tahsilat:
        entry.collections += transaction.amount;
        break;
      case DisplayTransactionType.alis:
        entry.purchases += transaction.amount;
        break;
      case DisplayTransactionType.odeme:
        entry.payments += transaction.amount;
        break;
      case DisplayTransactionType.gelir:
      case DisplayTransactionType.gider:
      case DisplayTransactionType.bilinmeyen:
        break;
    }
  }

  final items = ledger.values
      .map(
        (entry) => PartnerLedgerMetrics(
          partnerId: entry.partnerId,
          partnerName: entry.partnerName,
          sales: entry.sales,
          collections: entry.collections,
          purchases: entry.purchases,
          payments: entry.payments,
          lastMovementAt: entry.lastMovementAt,
        ),
      )
      .toList();

  items.sort((a, b) => b.sales.compareTo(a.sales));
  return items;
}

class _PartnerLedgerAccumulator {
  final String partnerId;
  final String partnerName;
  double sales = 0;
  double collections = 0;
  double purchases = 0;
  double payments = 0;
  DateTime? lastMovementAt;

  _PartnerLedgerAccumulator({
    required this.partnerId,
    required this.partnerName,
  });
}
