import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/models/cart.dart';
import 'package:frontend/models/financial_transaction.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/transaction_provider.dart';
import 'package:frontend/providers/wholesaler_order_provider.dart';
import 'package:frontend/screens/analysis_plus_screen.dart';
import 'package:frontend/utils/business_metrics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AnalysisHubScreen extends StatefulWidget {
  final String? userId;
  final String? userDisplayName;

  const AnalysisHubScreen({
    super.key,
    this.userId,
    this.userDisplayName,
  });

  @override
  State<AnalysisHubScreen> createState() => _AnalysisHubScreenState();
}

class _AnalysisHubScreenState extends State<AnalysisHubScreen> {
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  bool _isLoading = true;
  String? _error;
  int _months = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        context.read<ConnectionProvider>().fetchConnections(),
        context.read<TransactionProvider>().fetchAllFinancialData(),
        context.read<WholesalerOrderProvider>().fetchWholesalerOrders(),
        context.read<ProductProvider>().fetchProducts(),
      ]);
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<FinancialTransaction> get _transactions {
    final all = context.watch<TransactionProvider>().transactions;
    if (widget.userId == null) return all;
    return all.where((tx) => tx.partnerId == widget.userId).toList();
  }

  List<Cart> get _orders {
    final all = context.watch<WholesalerOrderProvider>().orders;
    if (widget.userId == null) return all;
    return all
        .where(
          (order) =>
              order.customerId == widget.userId ||
              order.wholesalerId == widget.userId,
        )
        .toList();
  }

  String get _title {
    if (widget.userDisplayName != null) {
      return 'Analiz+ | ${widget.userDisplayName}';
    }
    return 'Analiz+';
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final relevantTransactions = _transactions;
    final relevantOrders = _orders;
    final variantIndex = buildVariantMetricsIndex(products);
    final monthly = buildMonthlyFinanceMetrics(
      relevantTransactions,
      months: _months,
    );
    final ledger = buildPartnerLedgerMetrics(relevantTransactions);
    final demand = buildDemandMetrics(relevantOrders, variantIndex);

    final sales = relevantTransactions
        .where((tx) => tx.displayType == DisplayTransactionType.satis)
        .fold<double>(
            0, (sum, tx) => sum + (isApprovedTransaction(tx) ? tx.amount : 0));
    final collections = relevantTransactions
        .where((tx) => tx.displayType == DisplayTransactionType.tahsilat)
        .fold<double>(
            0, (sum, tx) => sum + (isApprovedTransaction(tx) ? tx.amount : 0));
    final purchases = relevantTransactions
        .where((tx) => tx.displayType == DisplayTransactionType.alis)
        .fold<double>(
            0, (sum, tx) => sum + (isApprovedTransaction(tx) ? tx.amount : 0));
    final payments = relevantTransactions
        .where((tx) => tx.displayType == DisplayTransactionType.odeme)
        .fold<double>(
            0, (sum, tx) => sum + (isApprovedTransaction(tx) ? tx.amount : 0));
    final otherIncome = relevantTransactions
        .where((tx) => tx.displayType == DisplayTransactionType.gelir)
        .fold<double>(
            0, (sum, tx) => sum + (isApprovedTransaction(tx) ? tx.amount : 0));
    final otherExpense = relevantTransactions
        .where((tx) => tx.displayType == DisplayTransactionType.gider)
        .fold<double>(
            0, (sum, tx) => sum + (isApprovedTransaction(tx) ? tx.amount : 0));
    final grossProfit = relevantOrders.fold<double>(
      0,
      (sum, order) => sum + estimateCartProfit(order, variantIndex),
    );
    final openReceivable =
        (sales - collections).clamp(0, double.infinity).toDouble();
    final averageOrder = relevantOrders.isEmpty
        ? 0
        : relevantOrders.fold<double>(
                0, (sum, order) => sum + order.totalAmount) /
            relevantOrders.length;
    final collectionRate = sales == 0 ? 0.0 : collections / sales;
    final netCash = collections + otherIncome - payments - otherExpense;
    final ageing = _buildAgeingRows(ledger);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _HeaderCard(
                        title: 'Profesyonel finans okuması',
                        subtitle: widget.userId == null
                            ? 'Satış, tahsilat, sipariş ve ürün verilerini muhasebe bakışıyla özetler.'
                            : 'Bu görünüm sadece seçili kişiyle olan ticari ilişkinizi analiz eder.',
                        trailing: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AnalysisPlusScreen(
                                  userId: widget.userId,
                                  userDisplayName: widget.userDisplayName,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.smart_toy_outlined),
                          label: const Text('AI asistanı aç'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [3, 6, 12]
                            .map(
                              (value) => ChoiceChip(
                                label: Text('$value ay'),
                                selected: _months == value,
                                onSelected: (_) =>
                                    setState(() => _months = value),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _KpiCard('Toplam satış', _currency.format(sales),
                              Colors.blue),
                          _KpiCard('Toplam tahsilat',
                              _currency.format(collections), Colors.green),
                          _KpiCard('Açık alacak',
                              _currency.format(openReceivable), Colors.orange),
                          _KpiCard('Net nakit akışı', _currency.format(netCash),
                              Colors.deepPurple),
                          _KpiCard('Brüt kâr tahmini',
                              _currency.format(grossProfit), Colors.teal),
                          _KpiCard('Ortalama sipariş',
                              _currency.format(averageOrder), Colors.brown),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Panel(
                        title: 'Aylık finans grafiği',
                        subtitle:
                            'Satış, tahsilat ve net nakit akışını yan yana izleyin.',
                        child: SizedBox(
                          height: 300,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _maxMonthly(monthly),
                              gridData: const FlGridData(show: true),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 52,
                                    getTitlesWidget: (value, _) => Text(
                                      _currency.format(value),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, _) {
                                      final index = value.toInt();
                                      if (index < 0 ||
                                          index >= monthly.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(DateFormat('MMM', 'tr_TR')
                                            .format(monthly[index].month)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: monthly
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => BarChartGroupData(
                                      x: entry.key,
                                      barsSpace: 4,
                                      barRods: [
                                        BarChartRodData(
                                            toY: entry.value.sales,
                                            color: Colors.blue,
                                            width: 10),
                                        BarChartRodData(
                                            toY: entry.value.collections,
                                            color: Colors.green,
                                            width: 10),
                                        BarChartRodData(
                                            toY: entry.value.netCashFlow,
                                            color: Colors.deepPurple,
                                            width: 10),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width > 960
                                ? (MediaQuery.of(context).size.width - 44) / 2
                                : double.infinity,
                            child: _Panel(
                              title: 'Sipariş akış özeti',
                              subtitle: 'Hangi aşamada ne kadar sipariş var?',
                              child: _PipelineSummary(
                                  orders: relevantOrders, currency: _currency),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width > 960
                                ? (MediaQuery.of(context).size.width - 44) / 2
                                : double.infinity,
                            child: _Panel(
                              title: 'Muhasebe yorumu',
                              subtitle: 'Veriye dayalı kısa profesyonel okuma.',
                              child: _Commentary(
                                items: _buildCommentary(
                                  sales: sales,
                                  collections: collections,
                                  collectionRate: collectionRate,
                                  openReceivable: openReceivable,
                                  grossProfit: grossProfit,
                                  purchases: purchases,
                                  payments: payments,
                                  ageing: ageing,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Panel(
                        title: 'Cari risk ve tahsilat tablosu',
                        subtitle:
                            'Açık alacakları yaşlandırılmış görünümle izleyin.',
                        child: ageing.isEmpty
                            ? const Text('Açık alacak bulunmuyor.')
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Cari')),
                                    DataColumn(label: Text('Açık Alacak')),
                                    DataColumn(label: Text('Son Hareket')),
                                    DataColumn(label: Text('Yaş')),
                                  ],
                                  rows: ageing
                                      .map(
                                        (row) => DataRow(
                                          cells: [
                                            DataCell(Text(row.partnerName)),
                                            DataCell(Text(_currency
                                                .format(row.receivable))),
                                            DataCell(
                                                Text(row.lastMovementLabel)),
                                            DataCell(Text(row.bucket)),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      _Panel(
                        title: 'Talep ve ürün performansı',
                        subtitle:
                            'Siparişlerde öne çıkan ürünler ve raf hazırlığı.',
                        child: demand.isEmpty
                            ? const Text(
                                'Sipariş bazlı ürün hareketi bulunmuyor.')
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Ürün')),
                                    DataColumn(label: Text('Varyant')),
                                    DataColumn(label: Text('Planlanan Adet')),
                                    DataColumn(label: Text('Beklenen Ciro')),
                                    DataColumn(label: Text('Beklenen Kâr')),
                                    DataColumn(label: Text('Raf')),
                                  ],
                                  rows: demand.take(8).map((item) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(item.productName)),
                                        DataCell(Text(item.variantName)),
                                        DataCell(
                                            Text(item.quantity.toString())),
                                        DataCell(Text(_currency
                                            .format(item.expectedRevenue))),
                                        DataCell(Text(_currency
                                            .format(item.expectedProfit))),
                                        DataCell(Text(item.shelfLocation)),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  double _maxMonthly(List<MonthlyFinanceMetrics> monthly) {
    final maxValue = monthly.fold<double>(
      0,
      (max, item) => [
        max,
        item.sales,
        item.collections,
        item.netCashFlow,
      ].reduce((a, b) => a > b ? a : b),
    );
    return maxValue == 0 ? 1 : maxValue * 1.2;
  }

  List<_AgeingRow> _buildAgeingRows(List<PartnerLedgerMetrics> ledger) {
    final rows = ledger.where((item) => item.receivable > 0).map((item) {
      final days = item.lastMovementAt == null
          ? 0
          : DateTime.now().difference(item.lastMovementAt!).inDays;
      final bucket = days <= 7
          ? '0-7 gün'
          : days <= 30
              ? '8-30 gün'
              : '31+ gün';
      return _AgeingRow(
        partnerName: item.partnerName,
        receivable: item.receivable,
        bucket: bucket,
        lastMovementLabel: item.lastMovementAt == null
            ? '-'
            : DateFormat('d MMM', 'tr_TR').format(item.lastMovementAt!),
      );
    }).toList();
    rows.sort((a, b) => b.receivable.compareTo(a.receivable));
    return rows;
  }

  List<String> _buildCommentary({
    required double sales,
    required double collections,
    required double collectionRate,
    required double openReceivable,
    required double grossProfit,
    required double purchases,
    required double payments,
    required List<_AgeingRow> ageing,
  }) {
    final comments = <String>[
      'Tahsilat oranı %${(collectionRate * 100).toStringAsFixed(1)} seviyesinde. ${collectionRate >= 0.85 ? "Nakit dönüşü güçlü." : "Tahsilat disiplinini sıkılaştırmak faydalı olur."}',
      'Açık alacak stoku ${_currency.format(openReceivable)}. ${openReceivable > sales * 0.35 ? "Risk seviyesi dikkat gerektiriyor." : "Cari denge kontrol altında."}',
      'Siparişlerden hesaplanan brüt kâr ${_currency.format(grossProfit)}. ${sales > 0 && grossProfit / sales < 0.2 ? "Marj baskısı var, fiyat ve maliyet gözden geçirilmeli." : "Marj seviyesi kabul edilebilir."}',
    ];
    if (ageing.any((row) => row.bucket == '31+ gün')) {
      comments.add(
          '31 gün üzeri bekleyen alacaklar var. Yaşlı carilere tahsilat önceliği verilmesi önerilir.');
    }
    if (payments > purchases) {
      comments.add(
          'Nakit çıkışı alış hacmini aşıyor; ödeme takvimi ve operasyonel giderler ayrıca incelenmeli.');
    }
    return comments;
  }
}

class _AgeingRow {
  final String partnerName;
  final double receivable;
  final String bucket;
  final String lastMovementLabel;

  const _AgeingRow({
    required this.partnerName,
    required this.receivable,
    required this.bucket,
    required this.lastMovementLabel,
  });
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white.withValues(alpha: 0.92)),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width > 960
          ? (MediaQuery.of(context).size.width - 60) / 3
          : MediaQuery.of(context).size.width > 640
              ? (MediaQuery.of(context).size.width - 48) / 2
              : double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PipelineSummary extends StatelessWidget {
  final List<Cart> orders;
  final NumberFormat currency;

  const _PipelineSummary({
    required this.orders,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = ['active', 'ordered', 'preparing', 'shipped', 'delivered'];
    return Column(
      children: statuses.map((status) {
        final related =
            orders.where((order) => order.status == status).toList();
        final total =
            related.fold<double>(0, (sum, order) => sum + order.totalAmount);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${related.length} adet'),
              const SizedBox(width: 12),
              Text(currency.format(total)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Commentary extends StatelessWidget {
  final List<String> items;

  const _Commentary({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.brightness_1, size: 8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
