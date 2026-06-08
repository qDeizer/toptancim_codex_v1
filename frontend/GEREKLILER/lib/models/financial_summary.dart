class FinancialSummary {
  final double totalReceivable;
  final double totalDebt;
  final double totalRevenue;
  final double totalExpense;
  final double netCash;
  final double currentBalance;

  FinancialSummary({
    required this.totalReceivable,
    required this.totalDebt,
    required this.totalRevenue,
    required this.totalExpense,
    required this.netCash,
    required this.currentBalance,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      totalReceivable: (json['total_receivable'] as num?)?.toDouble() ?? 0.0,
      totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      netCash: (json['net_cash'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Başlangıç/boş durum için bir factory
  factory FinancialSummary.initial() {
    return FinancialSummary(
      totalReceivable: 0.0,
      totalDebt: 0.0,
      totalRevenue: 0.0,
      totalExpense: 0.0,
      netCash: 0.0,
      currentBalance: 0.0,
    );
  }
}