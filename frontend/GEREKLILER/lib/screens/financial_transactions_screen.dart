import 'package:flutter/material.dart';
import 'package:frontend/models/financial_summary.dart';
import 'package:frontend/providers/transaction_provider.dart';
import 'package:frontend/widgets/financial_transaction_card.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/financial_transaction.dart';
import 'add_financial_transaction_screen.dart';

class FinancialTransactionsScreen extends StatefulWidget {
  const FinancialTransactionsScreen({super.key});
  @override
  State<FinancialTransactionsScreen> createState() =>
      _FinancialTransactionsScreenState();
}

class _FinancialTransactionsScreenState
    extends State<FinancialTransactionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false)
          .fetchAllFinancialData();
    });
  }

  Future<void> _refreshData() async {
    await Provider.of<TransactionProvider>(context, listen: false)
        .fetchAllFinancialData();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finansal Durum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Yenile',
          )
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (ctx, provider, _) {
          if (provider.isLoading && provider.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Veriler yüklenemedi: ${provider.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildSummaryCard(provider.summary),
                ),
                if (provider.transactions.isEmpty)
                  const SliverToBoxAdapter(
                    child: Center(
                      heightFactor: 5,
                      child: Text('Henüz mali işlem bulunmuyor.'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final transaction = provider.transactions[index];
                        return FinancialTransactionCard(
                          transaction: transaction,
                          onLongPress: () =>
                              _showDeleteConfirmationDialog(context, transaction),
                        );
                      },
                      childCount: provider.transactions.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFinancialTransactionScreen(),
            ),
          );
          if (result == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('İşlem listesi güncellendi.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        tooltip: 'Yeni İşlem Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, FinancialTransaction transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İşlemi Sil'),
        content: Text(
            '\'${transaction.partnerName}\' ile olan ${transaction.amount.toStringAsFixed(2)} ₺ tutarındaki bu işlemi silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await Provider.of<TransactionProvider>(context, listen: false)
                    .deleteTransaction(transaction.id);
              } catch (e) {
                _showErrorSnackBar(e.toString());
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  IconData _getSummaryIcon(String title) {
    switch (title) {
      case 'Toplam Alacak':
        return Icons.arrow_downward_rounded;
      case 'Toplam Borç':
        return Icons.arrow_upward_rounded;
      case 'Cari Durum':
        return Icons.account_balance_rounded;
      case 'Toplam Gelir':
        return Icons.trending_up_rounded;
      case 'Toplam Gider':
        return Icons.trending_down_rounded;
      case 'Net Nakit':
        return Icons.paid_rounded;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildSummaryCard(FinancialSummary summary) {
    final formatCurrency =
        NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(12.0),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildSummaryItem('Toplam Alacak', summary.totalReceivable,
                formatCurrency, theme.colorScheme.primary),
            _buildSummaryItem(
                'Toplam Borç', summary.totalDebt, formatCurrency, theme.colorScheme.error),
            _buildSummaryItem('Cari Durum', summary.currentBalance,
                formatCurrency, theme.colorScheme.secondary),
            _buildSummaryItem('Toplam Gelir', summary.totalRevenue,
                formatCurrency, Colors.green.shade600),
            _buildSummaryItem('Toplam Gider', summary.totalExpense,
                formatCurrency, Colors.red.shade800),
            _buildSummaryItem(
                'Net Nakit', summary.netCash, formatCurrency, theme.colorScheme.tertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, double value, NumberFormat formatter, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getSummaryIcon(title), color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            formatter.format(value),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}